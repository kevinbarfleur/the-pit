# The Pit — Plan d'implémentation des Murmures (DESIGN, zéro code)

> **Statut** : PLAN D'IMPLÉMENTATION — la 3e couche cachée (secondaire / easter-egg). Du **spice**,
> jamais build-defining. Décision créateur : **implémentation LIVE + log** (pas un simple flavor mort).
> **Sources** : `effects-overhaul-spec.md` §7 (mécanique/architecture finale) ·
> `murmures-hidden-affinities-brainstorm.md` (genèse + contrat) · **`docs/base-game/creature-identity-map.md`
> + `creature-renames.md` (CANON visuel — autoritaire sur le lore)** · `effects-content-plan.md` (rôles/effets).
> **Vérifié dans le code (2026-06-25)** : `engine.lua`, `ops.lua`, `arena.lua`, `bus.lua`, `snapshot.lua`,
> `units.lua`, `check.sh`.
>
> **Découverte clé de la lecture du code** : **tout le moteur est déjà posé et gated.** Les triggers
> `on_kill` / `on_ally_death` / `on_low_hp` existent avec ctx dédiés (`killCtx`/`allyDeathCtx`/`checkLowHp`),
> `neighborsOf` existe, l'edge-trigger de seuil (`_thresholdFired`) est câblé, `condition.kind="chance"`
> est seedé (`engine.lua:29`), et **les ops nécessaires existent déjà** (`grant_vuln`, `heal_on_kill`,
> `crit`, `purge`, `cleave`, `convert_dot`…), tous **gated → golden inchangé**. **Les Murmures ne
> demandent presque aucun moteur neuf** : c'est de la **data + 1-2 ops de résolution + l'event 2 canaux + i18n**.

---

## 0. Le contrat, en une ligne

Une 3e capacité **cachée** par unité, ancrée au **lore visuel canon**, **plafonnée à ~10% de stat
(`increased`) OU 1 effet ponctuel one-shot**, **cryptique jusque dans le log** (nomme les UNITÉS, JAMAIS
la valeur), **découverte par observation**, **seedée/snapshotée**. L'esquive (seul murmure RNG) reste
**OFF en v1** jusqu'au contrat snapshot 2-camps. *Seul le créateur connaît les vraies valeurs.*

---

## 1. Schéma `src/data/whispers.lua` (déclaratif PUR)

### 1.1 Forme

Un registre `id_unité → { liste de murmures }`. Chaque murmure = un descripteur **de données** au
format **identique** à un effet du roster (`{trigger, op, params, condition?}`) + 4 champs propres au
système : `kind`, `key`, `partner?`, `verb`. **Aucune fonction, aucun `math.random`, aucun `love.*`** : ce
ne sont que des tables littérales. Toute la logique (résolution présence/adjacence, lecture de seuil, roll
seedé, pose de l'effet borné, émission de l'event) vit dans **l'op** (`src/effects/`, sous firewall).

```lua
-- src/data/whispers.lua  (DÉCLARATIF PUR — zéro fonction/RNG/love)
return {
  -- DUO (lignée) : LANTERN-GULLET renforcé par la présence du SAC qui couve (le leurre attire la couvée).
  demon = {
    { kind = "lineage", key = "the_lure_and_the_brood", partner = "witch",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "witch", reach = "presence",  -- "presence" (terrain) | "adjacency"
                 effect = { kind = "stat_inc", stat = "atkInc", value = 0.10 } }, -- borné K2 : +10% dmg sortant
      verb = "frappe plus fort" },
  },

  -- SOLO conditionnel (seuil PV) : la chair damnée se repaît à l'agonie.
  hollow_gut = {
    { kind = "solo", key = "the_gorging", partner = nil,
      trigger = "on_low_hp", op = "whisper_solo",
      condition = nil,                                   -- pas de chance : 100% au franchissement
      params = { threshold = 0.30,                       -- lu par checkLowHp (params.threshold existant)
                 effect = { kind = "stat_inc", stat = "lifestealBonus", value = 0.10 } },
      verb = "se repaît" },
  },

  -- SOLO conditionnel one-shot (mort d'allié) : la coquille creuse absorbe le défunt.
  husk = {
    { kind = "solo", key = "the_hollow_vessel", partner = nil,
      trigger = "on_ally_death", op = "whisper_solo",
      params = { effect = { kind = "stat_inc", stat = "dmgInc", value = 0.05, capStacks = 4 } }, -- cumul borné
      verb = "endure" },
  },
}
```

### 1.2 Pourquoi PUR suffit

- Le **trigger** est une chaîne (clé de hook) — pas de logique.
- La **condition** réutilise `condition.kind="chance"` (rollée par `Effects.passCondition` via
  `ctx.arena.rng`, déjà câblé) — la table décrit, l'op ne fait rien de plus.
- L'**effet** est une table `{kind, stat, value, …}` — la **borne** (`value ≤ 0.10`, `capStacks`) est une
  donnée ; l'**application** (`Stats.increased`, clamp) est dans l'op.
- Le `key`/`verb`/`partner` ne servent qu'au **phrasé i18n** (canal joueur) et à l'**event-log** (canal dev).

→ Un `whispers.lua` qui ne contient que des tables littérales **ne peut pas** introduire de RNG global ni
d'appel `love`. Le lint CI (§6) le garantit mécaniquement.

---

## 2. Op(s) `src/effects/` — l'exécution (sous firewall, gated, golden-safe)

> Stratégie : **2 ops généralistes** (`whisper_lineage`, `whisper_solo`) qui couvrent tous les murmures
> NON-RNG de la v1, en **réutilisant** le vocabulaire `increased` existant (`Stats.resolve`) et les caps.
> Un 3e op (`whisper_dodge`) est spécifié mais **gardé OFF** (§3, §5). Aucun n'est porté par une unité du
> scénario golden → **empreinte inchangée**.

### 2.1 `whisper_lineage` (DUO — présence/adjacence au build)

- **Trigger** : `combat_start`. **Résolution** : scanne `ctx.arena.units` (présence) ou
  `ctx.arena:neighborsOf(ctx.source)` (adjacence) pour la présence d'un allié `id == params.needPartner`.
- **Si trouvé** → pose l'effet **borné** sur le porteur :
  - `kind="stat_inc"` → écrit le champ combat-time existant (`source.atkInc += value`, `source.statInc`,
    etc.), lu par `Stats.resolve` dans `hit()`/`damage()` (= la voie K1/K2, **additive, déterministe, cappée**).
  - `kind="oneshot"` → arme un flag consommé une fois (ex. `source._whisperOneShot = {…}`), détoné au 1er
    `on_hit`/`on_death` selon le params (réutilise les hooks existants).
- **Émet** l'event `murmur` 2 canaux (§4) avec `partner` = l'unité trouvée.
- **Mapping moteur** : `neighborsOf` (existe, `arena.lua:240`), scan `self.units` en `ipairs`
  (déterministe), `Stats.increased` (existe). **AUCUN op neuf de combat** — juste un nouveau **resolver**
  enregistré comme op `combat_start`.

### 2.2 `whisper_solo` (SOLO — condition au tick/seuil/mort)

- **Triggers** : `combat_start` (position front/fond via `source.depth`, déjà calculé) ·
  `on_low_hp` (seuil PV, via `checkLowHp` + `params.threshold`, **existant**) · `on_ally_death`
  (cumul borné, via la 3e boucle du broadcast différé, **existant**) · `combat_start`+re-check
  (présence d'un feu actif, durée de combat `self.t`…).
- **Effet** : identique à §2.1 (stat_inc borné, ou one-shot), `partner=nil`.
- **Cumul borné** (`husk`) : `me._whisperStacks = min(capStacks, +1)` puis ré-applique l'`increased` sur
  la **base mémorisée** (pattern **identique à `frenzy_gain`**, `ops.lua:221` — pas de dérive d'arrondi).
- **Mapping moteur** : tout existe. `on_low_hp` exécute déjà UN op précis par seuil (`arena.lua:645`).

### 2.3 Champ neuf requis ? (justifié)

- `atkInc`, `statInc`, `dmgInc` (via `frenzyBase`), `lifesteal` : **déjà câblés/lus**. Réutilisés tels quels.
- **`lifestealBonus`** (`hollow_gut`, `demon` au seuil) : si l'unité n'a pas déjà de `lifesteal`, on a
  besoin d'un additif lu dans l'op `lifesteal` (`ops.lua:49`). **Nouveau champ inerte** (`nil`),
  initialisé `nil` dans `makeUnit` (§2.6 de la spec), lu en `frac + (s.lifestealBonus or 0)`. **Golden-safe**
  (aucune unité golden ne le porte). Justifié : on ne veut pas qu'un murmure « +10% vol de vie » exige que
  l'unité ait déjà du lifesteal.
- **`source._whisperStacks` / `source._whisperOneShot`** : champs internes du système, `nil` par défaut →
  inertes. Aucun impact golden.

→ **Bilan moteur** : 2 ops resolver (`whisper_lineage`, `whisper_solo`) + 1 champ additif optionnel
(`lifestealBonus`) + 1 champ interne. **Tout gated, tout golden-safe.** Le dodge (§3) ajoute le seul vrai
risque déterministe et reste OFF.

---

## 3. Les 10 Murmures exemplars — **ré-ancrés sur le CANON visuel**

> ⚠️ **Correction du piège thématique signalé** : la spec §7.5 proposait `witch ↔ demon = « Le Pacte »
> (sorcière + démon invoqué)`. **C'est FAUX vu le canon.** `witch` = **THE BROODING SAC** (sac d'œufs
> fibreux qui suinte le poison — *cocon*, pas sorcière). `demon` = **LANTERN-GULLET** (poisson abyssal à
> leurre lumineux — *anglerfish*, pas démon invoqué). Il n'y a ni sorcière ni invocation : refondre
> l'affinité sur ce qu'on **voit**. Toutes les paires ci-dessous sont re-justifiées sur les noms/lore
> canon de `creature-renames.md` + `creature-identity-map.md`.

| # | Murmure (key) | kind | Unité(s) — **nom canon** | Condition | Effet (spice, borné) | Ligne de log (joueur, ZÉRO chiffre) |
|---|---|---|---|---|---|---|
| 1 | `the_lure_and_the_brood` | lignée | **LANTERN-GULLET** (`demon`) + **THE BROODING SAC** (`witch`) | présence | `demon` : `atkInc +10%` | « Le leurre du *Lantern-Gullet* brille plus avide quand *le Sac qui couve* est tout près… » |
| 2 | `the_forge_circle` | lignée | **THE EMBER HIEROPHANT** (`cinder_cur`) + **THE KINDLING-STORK** (`pyre_tender`) | adjacence | **one-shot** : 1re brûlure de la paire plus intense | « Le sermon de cendre du *Hiérophante* attise le bûcher que dresse la *Cigogne d'allumage*. » |
| 3 | `the_brood_below` | lignée | **DEEP KRAKEN** + sa couvée (**INK HORROR**/**CORRUPTOR**/**ACID MAW**) | présence du kraken | la couvée : `statInc +10%` | « Quelque chose lie le *Kraken des fonds* à sa portée ; elle frappe avec une assurance neuve. » |
| 4 | `the_three_skulls` | lignée | **THE THREE-HEADED PYRE** (`soot_acolyte`) + n'importe quel feu allié | présence d'un feu | `burnInc +10%` (ampli DoT existant) | « Trois crânes partagent une fournaise — et toute flamme alentour brûle d'un éclat plus noir. » |
| 5 | `the_kindred_machines` | lignée | **WARDSTONE SENTINEL** (`bulwark_acolyte`) + **THE STOKED HUSK** (`footman`) / golem | adjacence à un construct | `dmgReduce +0.08` (armure plate, K1) | « Les rouages de la *Sentinelle* s'alignent sur ceux du *Fantassin attisé*. » |
| 6 | `the_gorging` | solo | **HOLLOW GUT** (`hollow_gut`) | sous ~30% PV (`on_low_hp`) | `lifestealBonus +10%` | « Le *Glouton creux* s'ouvre une bouche de plus — et se repaît de ce qui saigne. » |
| 7 | `the_hollow_vessel` | solo | **HUSK** (`husk`) | à la mort d'un allié (`on_ally_death`) | `dmgInc +5%` (cumul borné, cap 4) | « La *Coquille creuse* se gorge du défunt et se tient un peu plus droite. » |
| 8 | `the_lone_titan` | solo | **SKULL COLOSSUS** | aucun autre `bone`/`crane` allié | `statInc +10%` | « Le *Colosse de crâne*, seul de son espèce, se sent… plus vaste. » |
| 9 | `the_patient_one` | solo | **THE HOLLOW MARIONETTE** (`patient_worm`) | après ~N s de combat (`self.t`) | `statInc +10%` | « La *Marionnette creuse* a attendu ; les fils se tendent enfin. » |
| 10 | `the_coward` **(OFF v1)** | solo | **SUMP CLEAVER** (`bandit`) | la plus au fond (`depth` max) | **5-10% esquive** (RNG seedé) — **BLOQUÉ §5** | « Le *Fendeur d'égout* s'efface dans l'ombre — un coup l'a manqué. » *(dodge)* |

**Notes d'ancrage canon** :
- #1 réécrit le « Pacte » faussement lu : pas de pacte sorcière/démon, mais **le leurre abyssal et le
  sac qui couve** — deux choses qui *attirent* dans le noir (le leurre lumineux, la lumière du sac qui
  suinte). Le lien est **prédateur/appât**, pas magique. C'est plus grimdark et collé au visuel.
- #2 garde `cinder_cur`↔`pyre_tender` mais avec les noms réels : **Hiérophante de braise** (prêtre cornu
  à 4 yeux-braises) + **Cigogne d'allumage** (échassier qui dépose un feu patient). Le lore tient (culte du
  feu) et matche les sprites.
- #5 remplace « rust_sentinel ↔ footman » du brainstorm par les **noms canon** : `bulwark_acolyte` =
  *Wardstone Sentinel* (dalle de pierre runique) + `footman` = *The Stoked Husk* (coquille rivetée à
  fournaise). « Les machines se reconnaissent » reste juste.
- #10 (esquive) : le brainstorm donnait `bandit`. Canon : **SUMP CLEAVER** (squille-mante à pince-marteau).
  « Un voleur ne meurt pas en première ligne » devient « le rôdeur des égouts s'efface dans l'ombre » —
  collé au sprite. **Reste OFF en v1.**

**Tous les effets sont des PLACEHOLDERS** à tuner via `tools/sim.lua` (canal dev). « Seul moi connais les
vraies valeurs. »

---

## 4. Event `murmur` — 2 canaux (RENDER-only, golden-safe)

L'op émet **un** event ; **deux abonnés** le rendent différemment. Aucun abonné SIM n'altère l'issue
au-delà de l'effet déjà posé → `murmur` est **RENDER-only**, comme `affliction_applied`/`amped`.

```
ctx.arena.bus:emit("murmur", {
  -- CANAL JOUEUR (Chronique/Journal — phrasé cryptique i18n, ZÉRO chiffre) :
  key     = "the_gorging",          -- clé i18n : t("whisper."..key..".cryptic", {x=…, y=…})
  source  = <unité>,                -- X (bénéficiaire) -> nom localisé via unit.<id>.name
  partner = <unité|nil>,            -- Y (duo) ou nil (solo)
  verb    = "se repaît",            -- catégorie vague (fallback de phrasé)
  -- CANAL DEV (event-log JSONL — tools/eventlog.lua + sim.lua — la VRAIE magnitude) :
  trueKind  = "stat_inc",           -- "stat_inc" | "oneshot" | "dodge" | "lifesteal"
  trueValue = 0.10,                 -- la vraie valeur (sim/tuning) — JAMAIS affichée au joueur
})
```

- **Canal joueur** : la Chronique pioche `whisper.<key>.cryptic` (i18n), interpole les **noms** des unités
  (`{x}`/`{y}`), **jamais** `trueValue`. Verbes vagues : `renforcé` · `frappe plus fort` · `se dérobe` ·
  `endure` · `se repaît`. Le joueur **sent** un lien noué, sans lire la fiche.
- **Canal dev** : l'event-log garde `trueKind/trueValue` → attribution + drapeaux d'outliers (métriques P3
  de `sim.lua`). Un duo caché cassé **se voit** en sim.
- **Golden-safe** : émettre un event ne change pas l'event-log golden tant qu'**aucune unité du scénario
  golden** ne porte de murmure (registre vide pour ces unités = zéro émission). Comme `amped`/`spread`,
  c'est un signal RENDER.

---

## 5. Seedé / snapshot — ce qui est sûr en v1, ce qui est différé

### 5.1 Sûr en v1 (tous les murmures NON-RNG)

Les murmures `stat_inc` (≤10%) et `oneshot` passent par **K1/K2** (`increased` **additif**, sans tri →
déterministe par construction) ou un flag consommé une fois. **Zéro RNG** dans le chemin de dégât → **zéro
risque async**. Ils sont **rejouables à l'identique** et suffisent pour la v1.

### 5.2 Le point dur snapshot (et pourquoi il est presque gratuit ici)

`Snapshot.toComp` (`snapshot.lua:54`) **reconstruit** chaque unité depuis `Units[id]` (+ level-mult) et ne
transporte que `{id, level, col, row}`. **Conséquence cruciale** : la compo rejouée d'un ghost lit
`Units[id].effects`. Donc **si les murmures sont résolus depuis un registre indexé par `id`** (`whispers.lua`)
**chargé par l'arène à `combat_start`** (pas baké dans un spec custom non sérialisé), **le ghost déclenche
ses murmures GRATUITEMENT** — exactement comme `corruptor` déclenche son `grant_vuln` en ghost aujourd'hui
(il vit dans `Units[id].effects`, transporté par l'`id`).

**Deux voies d'injection, équivalentes côté snapshot** (trancher à l'implémentation, Q-inject) :
- **(A)** Le **resolver de combat_start** (dans l'arène/spawn) **fusionne** `whispers[u.id]` dans la liste
  d'effets exécutés au spawn (lecture par `id`). Le plus propre : `whispers.lua` reste séparé de `units.lua`
  (curatable), et l'injection est faite à partir de l'`id` → **transporté par le snapshot sans rien changer
  au schéma**.
- **(B)** Append des descripteurs de murmure dans `Units[id].effects`. Plus simple mais mélange murmure et
  mécanique publique dans le même fichier.

→ **Recommandation : (A)** (curation + séparation), **et le schéma snapshot N'A RIEN À ENCODER de neuf**
pour les murmures NON-RNG : l'`id` suffit, les deux camps les déclenchent au replay. **C'est le sens de
« les easter eggs sont faits confondus » du brainstorm.**

### 5.3 Ce qui reste à encoder / différer

- **Esquive (dodge, #10)** : **seul murmure RNG**, **seul vrai risque async**. Un roll seedé dans `hit()`
  fait **avancer la seed** ; si le ghost ne déroule **pas** le même nombre de rolls (parce qu'un de ses
  murmures-RNG ne s'est pas réinjecté), **tout** le combat diverge — pas juste l'esquive. **OFF tant que
  `tests/snapshot.lua` ne prouve pas que `toComp` réinjecte les murmures-RNG des DEUX camps.** Avec la
  voie (A), c'est déjà le cas par construction — mais **on l'écrit en test avant d'activer le hook**
  (étape 5 de l'ordre §7). Implémentation du hook : roll seedé **dans `hit()` (PAS `damage()`)**,
  **edge-triggered une fois par swing, AVANT le damage** (conforme §2.0.2 de la spec). Rebaseline golden
  **seulement** si une unité du scénario golden l'adopte (les garder hors golden = pas de rebaseline).
- **(Différé, signalé)** : si plus tard un murmure devait baker un `statBonus` non dérivable de l'`id`
  (improbable vu la borne 10%), il faudrait l'encoder comme le `statBonus` de la synergie-famille
  (spec §2.5.1). **Non requis en v1** (tout est dérivable de l'`id`).

---

## 6. Firewall — `whispers.lua` hors SIM_DIRS mais déclaratif pur

- `src/data/` **n'est pas** dans `SIM_DIRS` (`check.sh:12` : `src/combat src/board src/effects src/run`).
  C'est volontaire (`units.lua`/`relics.lua`/`encounters.lua` sont de la data légitime sans RNG ; ajouter
  `src/data` entier rendrait le scan RNG bruyant).
- **Mais** `whispers.lua` étant **purement déclaratif** (zéro fonction/RNG/love), il ne peut pas
  introduire de RNG global. La **logique** vit dans `src/effects/` (ops `whisper_*`), **dans `SIM_DIRS`** →
  couverte par le firewall RNG + le garde golden. C'est la décision §7.2 de la spec.
- **Lint CI ciblé (recommandé, golden-neutre)** — ajouter à `check.sh`, juste après le garde RNG :

  ```sh
  echo "== garde data pure (whispers declaratif : ni function/RNG/love) =="
  if [ -f src/data/whispers.lua ] && \
     grep -nE '\bfunction\b|math\.random|love\.' src/data/whispers.lua 2>/dev/null; then
    echo "FAIL: whispers.lua doit etre DECLARATIF PUR (aucune logique). Mettre l'op dans src/effects."
    exit 1
  fi
  echo "OK (whispers data pure)"
  ```

  Moins fragile que d'élargir `SIM_DIRS` ; cible exactement le risque soulevé (un RNG global qui
  passerait inaperçu dans la data).

---

## 7. Ordre d'implémentation (vagues VERTES, golden-neutres)

> Chaque vague **verte** (`sh tools/check.sh`) + committée. Tout est **gated** : tant qu'aucune unité du
> **scénario golden** ne porte de murmure, l'empreinte est inchangée (placer les exemplars hors du
> scénario golden, comme pour les keystones).

| Vague | Livrable | Fichiers | Golden | Dépend |
|---|---|---|---|---|
| **W1** | `whispers.lua` **vide-mais-valide** + **lint data-pure** dans `check.sh` | `src/data/whispers.lua`, `tools/check.sh` | inchangé (registre vide) | — |
| **W2** | ops `whisper_lineage` + `whisper_solo` (resolver présence/adjacence/seuil/mort/position) + champ `lifestealBonus` (additif, inerte) ; **injection voie (A)** au spawn (lecture par `id`) | `src/effects/ops.lua` (ou `src/effects/whispers_ops.lua`), `src/combat/arena.lua` (merge `whispers[u.id]` au combat_start), `makeUnit` (init `lifestealBonus=nil`, `_whisperStacks=nil`) | inchangé (gated : aucune unité golden ne les porte) | W1 |
| **W3** | event `murmur` 2 canaux : émission dans les ops + abonné Chronique (canal joueur) + event-log (canal dev) | `src/effects/...` (emit), `src/scenes/...`/chronicle (rendu), `tools/eventlog.lua` (trueKind/trueValue) | inchangé (RENDER-only) | W2 |
| **W4** | **i18n** des lignes cryptiques : `whisper.<key>.cryptic` (interpolation `{x}`/`{y}`, jamais de chiffre) + couverture testée | `src/i18n/en.lua`, `tests/i18n.lua` | inchangé | W3 |
| **W5** | **8-9 murmures NON-RNG** (les exemplars #1-#9) câblés dans `whispers.lua` (HORS scénario golden) + **tests** : déterminisme (même seed → même log de murmures), couverture (chaque key a sa cryptic), bornes (stat_inc ≤ cap) | `src/data/whispers.lua`, `tests/whispers.lua` (neuf), `tools/check.sh` (ligne de test) | inchangé si exemplars hors golden ; **sinon rebaseline contrôlée** | W4 |
| **W6** | branchement `tools/sim.lua` sur le canal dev (attribution murmure `trueValue`) → vérifier le plafond « spice » (aucun murmure n'inverse un matchup) | `tools/sim.lua` | n/a | W5 |
| **W7 (différé)** | **dodge (#10)** : `tests/snapshot.lua` prouve la réinjection 2-camps **AVANT** d'activer le hook `whisper_dodge` dans `hit()` ; rebaseline golden seulement si une unité golden l'adopte | `tests/snapshot.lua`, `src/combat/arena.lua` (`hit()` pré-check), `src/data/whispers.lua` (#10) | rebaseline **uniquement** si golden touché | W5 + contrat snapshot vert |

**Garde-fou de vague** : W1→W6 ne touchent **aucune** unité du scénario golden → `golden.lua` reste sur
son empreinte actuelle. La **seule** vague à risque de rebaseline est W7 (dodge), **explicitement
différée** derrière le test snapshot 2-camps.

---

## 8. Récapitulatif des décisions (ce qui est tranché ici)

1. **Canon d'abord** : le « Pacte witch↔demon » de la spec §7.5 est **corrigé** en *the_lure_and_the_brood*
   (Lantern-Gullet + Brooding Sac) — affinité **prédateur/appât**, pas magique. Tous les exemplars sont
   ré-ancrés sur `creature-renames.md`/`creature-identity-map.md`.
2. **Presque zéro moteur neuf** : les triggers, ctx dédiés, `neighborsOf`, edge-trigger de seuil et le
   `condition.kind="chance"` seedé **existent déjà**. Murmures = **data + 2 ops resolver + 1 champ additif
   + event 2 canaux + i18n**.
3. **Snapshot gratuit** pour les murmures NON-RNG : résolution **par `id`** (voie A) → le ghost les
   déclenche sans rien encoder de neuf. Le **seul** point dur (dodge) reste **OFF** derrière un test
   snapshot 2-camps.
4. **Golden-neutre par construction** : registre vide → zéro émission ; exemplars hors scénario golden ;
   `murmur` = RENDER-only. La seule rebaseline possible est le dodge, différé.
5. **Cryptique jusque dans le log** : le canal joueur nomme les unités, jamais la valeur. Le canal dev
   garde la vérité pour la sim. *Seul le créateur connaît les vraies valeurs.*

> **Questions ouvertes** (défaut raisonnable proposé) :
> - **Q-inject** : injection des murmures via merge-au-spawn par `id` (A) **ou** append dans
>   `Units[id].effects` (B). *Défaut : (A)* (curation + séparation).
> - **Q-lifesteal** : ajouter `lifestealBonus` additif **ou** réserver les murmures lifesteal aux unités
>   ayant déjà du lifesteal. *Défaut : champ additif inerte* (plus de liberté de design, golden-safe).
> - **Q-trace-bestiaire** : trace cryptique au Bestiaire (« lien pressenti », sans valeur) **ou**
>   log-only à vie. *Défaut : log-only en v1, trace cryptique en option ultérieure* (M1 du brainstorm).
