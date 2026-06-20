# The Pit — Architecture moteur : effets composables, déterminisme, test & perf

> Synthèse de 6 recherches parallèles (2026-06), chacune sous la Règle d'or (sources
> primaires + Exa, citées). Couvre les deux piliers demandés : **(1)** système modulaire
> d'effets/modifiers extensible sans casser l'existant ; **(2)** harnais de test e2e +
> simulation de masse + analyse d'équilibrage. Plus deux axes transverses : **archi
> anti-spaghetti** et **performance**. Document de référence — le plan d'exécution est en §12.

---

## 1. Contexte & objectif

La valeur du jeu = la **diversité et la richesse des interactions** entre effets (synergies,
ordre de placement, effet→effet→effet). On veut un moteur où :

- ajouter une relique / un effet / un modifier = **ajouter de la donnée** (idéalement 1 fichier),
  **jamais éditer la boucle de combat** (principe ouvert/fermé) ;
- les choses sont **interconnectées mais découplées** (pas de dépendance mutuelle) ;
- conditions et incompatibilités sont **gérées proprement** (skip gracieux, pas de crash) ;
- modèle « entité + modifiers » façon survivor-like (un projectile → fork/chain/bounce, chaque
  sous-entité re-modifiable) transposé à nos **placements 3×3** (une unité reçoit des modifiers
  selon ses voisins, sa position, son passif, ses reliques, son niveau) ;
- **déterministe et rejouable** : même seed → combat identique (équilibrage, golden-logs,
  snapshots async, **replays/leaderboard**).

---

## 2. Diagnostic du code actuel (audit)

Bonne nouvelle : structure déjà **de qualité « bibliothèque »** (zéro global accidentel, graphe
`require` acyclique, modules `local X = {}; return X`). Mais 3 problèmes ciblés :

1. **🔴 Bug de déterminisme live** — `src/combat/arena.lua:63` tire `love.math.random()` (RNG
   **global**, non seedé) pour décaler les `atkTimer`. Le combat n'est **pas** reproductible
   aujourd'hui ; en headless ça « marche » seulement parce que le mock renvoie `0.5` constant.
   C'est la priorité n°1 : ça casse silencieusement le pilier snapshot/replay/équilibrage.
2. **Sim et rendu fusionnés** — `arena.lua` fait ~34 appels `love.*` (graphics L233–279 + RNG
   L63). La « sim » n'est pas pure ; elle ne tourne headless que grâce au mock.
3. **Effets couplés et éclatés** — `aura_shield` est résolu dans `build.lua:181–188`, les autres
   passifs sont une échelle de `if a.passive.kind == …` dans `arena.lua:122+`. Un passif = **un
   seul `kind`**, impossible d'empiler plusieurs modifiers. C'est exactement le piège « dans 3
   mois on ne peut plus rien ajouter ».
4. Dette mineure de direction : `src/data/creatures.lua:7` require `rig.lua` → **data dépend de
   la logique** (mauvais sens). `arena.lua` require aussi `rig` (la sim connaît le visuel).

---

## 3. Principe directeur (ce sur quoi les 6 recherches convergent)

**Un effet est de la DONNÉE décomposée en axes indépendants + un petit interpréteur générique.**
Personne ne code en dur « le chat buffe le chien ». On stocke une ligne
`{trigger, condition, action, target, magnitude}` et **une seule boucle** la parcourt. Nouveau
contenu = nouvelle ligne, pas nouveau code.

Modèle canonique **Super Auto Pets** (4 axes) : `trigger → condition → effect(op) → target`.
SAP fait tourner **tout** son jeu avec ~33 triggers, ~35 effets, ~10 conditions, ~45 cibles.
Sources : a327ex « SAP mechanics » (https://a327ex.com/posts/super_auto_pets_mechanics) ;
ref Rust `saptest` (https://docs.rs/saptest/).

Système de **hooks façon Slay the Spire** : chaque effet/relique n'override que les hooks qui
l'intéressent ; le cœur parcourt la liste des powers du porteur et appelle le hook. Ajouter le
power n°500 ne peut pas casser le n°1 car ils ne se référencent jamais — seulement le contrat de
hook. C'est *la* clé du « des centaines de reliques sans toucher au cœur ». Sources : BaseMod
Hooks (https://github.com/daviscook477/BaseMod/wiki/Hooks) ; StSLib Power Hooks
(https://github.com/kiooeht/StSLib/wiki/Power-Hooks).

**À NE PAS faire** : le « layer system » de MTG (résolution des effets continus par 7 couches +
timestamps + système de *dépendances*). C'est la règle la plus complexe du jeu pour un gain
minuscule (le « bogeyman » du jeu). On en garde **2 idées** seulement : (a) couches = buckets
ordonnés ; (b) tie-break par timestamp/insertion. On NE construit PAS de résolveur de
dépendances. Sources : MTG CR 613 (https://ancestral.vision/spells-abilities-and-effects/interaction-of-continuous-effects.html) ;
https://outsidetheasylum.blog/dependency/.

---

## 4. Architecture en couches + firewall SIM/RENDER

5 couches, **dépendance vers le bas uniquement** :

```
L5  ENTRY     main.lua, conf.lua            love.run, canvas, routage input (câblage seul)
L4  SCENES    src/scenes/                   orchestration + INPUT + UI ; lit la sim, pilote le rendu
─────────────────────────────────────────────────────────────────────────────────────────
L3a SIM (PURE) src/combat/ src/board/ src/effects/   ZÉRO love.* — rng + bus INJECTÉS via ctx.
              ┄┄┄┄┄ FIREWALL SIM/RENDER ┄┄┄┄┄          émet des événements, ne dessine jamais.
L3b RENDER    src/render/ (NEW) src/fx/ src/core/rig  lit la sim en lecture seule ; possède tous
                                  src/core/sprite      les love.graphics.*
─────────────────────────────────────────────────────────────────────────────────────────
L2  SERVICES  src/core/bus.lua (NEW) palette           rng, bus d'événements, palette, registre,
              src/core/registry.lua (NEW) classic.lua   base OOP
L1  DATA (PURE) src/data/units relics effects encounters tables pures ; require RIEN de chez nous
                + index.lua par dossier (manifeste)       (même pas rig)
```

**Règle firewall** : `data/` ne require rien de chez nous · `combat/`+`board/`+`effects/` ne
requirent jamais `scenes/`, `render/`, `fx/`, ni `love.*` · seuls `scenes/` et `main.lua` voient
sim **et** rendu. *Le passage du test headless EST la preuve que le firewall tient — on le protège.*

---

## 5. Déterminisme (la fondation — à poser EN PREMIER)

- **Un seul RNG seedé par combat, injecté** : `ctx.rng = love.math.newRandomGenerator(seed)` ;
  toute la sim ne lit que `self.rng:random()` / `:random(a,b)` (plateforme-indépendant, contrairement
  à `math.random` = `rand()` C). `RandomGenerator:getState()/:setState()` sérialisent l'état RNG →
  on stocke `{seed, rngState}` dans le snapshot pour rejouer à l'identique.
  (https://love2d.org/wiki/love.math.newRandomGenerator)
- **Pas-de-temps fixe** déjà en place (`love.run` surchargé, TICK 1/60) — l'autre moitié du déterminisme.
- **Tout ce qui touche l'ordre de sim vit dans un ARRAY**, itéré par `ipairs`/`for i=1,#t`. **Jamais
  `pairs`/`next`** : ordre « non spécifié, même pour des indices numériques » (manuel Lua 5.1, entrée
  `next`). `table.sort` **n'est pas stable** → toujours un tie-break explicite (`prio`, puis `seq`
  d'enregistrement), jamais l'adresse de table.
- **Interdits en code de sim** (chacun sourcé au manuel Lua 5.1) : `pairs/next` pour un ordre,
  `math.random` global, `os.time`/`os.clock` pendant la résolution (ok pour *choisir* un seed une fois),
  dépendre de la stabilité de `table.sort`, ordre par adresse de table, `#t` sur table à trous.

**Réplays = quasi gratuits** : un autobattler n'a aucune entrée joueur pendant le combat → un replay =
`{ snapshot des 2 compos + positions + sigil, seed, rngState }`. **Même structure** que le snapshot
async et que le golden-log de test. Déterminisme + snapshot ⟹ replay *et* multi async *et* tests, une
seule fondation.

---

## 6. Le système d'effets (le cœur)

### 6.1 Effet = donnée pure (sérialisable)

```lua
-- Un effet décrit QUOI faire et QUAND. Donnée pure -> sérialisable (snapshots + reliques
-- cryptiques "3 descripteurs candidats"). Les closures NE sont PAS sérialisables : on n'en stocke pas.
Effects["poison_on_hit"] = {
  trigger   = "on_hit",                          -- quel événement déclenche
  condition = { kind = "chance", value = 0.5 },  -- garde optionnelle (skip gracieux)
  target    = "victim",                          -- self|victim|neighbors|column_front|...
  ops       = { { op = "apply_status", status = "poison", stacks = 2 } },
  meta      = { { op = "scale_by_stat", stat = "spell_power", who = "source" } }, -- transforme AVANT
  post      = { { op = "lifesteal", pct = 0.0 } },                                -- chaîne APRÈS
}
```

### 6.2 Registre d'ops (open/closed)

```lua
local Ops = {}                       -- nom d'op -> handler. Ajouter un effet = +1 op (rarement).
Ops.lifesteal     = function(ctx, p) ... end
Ops.apply_status  = function(ctx, p) ... end
-- dispatch : (Ops[op] or noop)(ctx, params)   -- op manquant ignoré, comme une part de rig absente
```

### 6.3 Bus d'événements déterministe (array, par combat, injecté)

```lua
-- src/core/bus.lua — array + ipairs, AUCUN love.*, sûr pour la sim.
local Bus = {}; Bus.__index = Bus
function Bus.new() return setmetatable({ _h = {} }, Bus) end
function Bus:on(ev, fn) local l=self._h[ev]; if not l then l={}; self._h[ev]=l end; l[#l+1]=fn; return fn end
function Bus:emit(ev, ...) local l=self._h[ev]; if not l then return end
  for i=1,#l do l[i](...) end       -- ordre d'enregistrement = déterministe
end
return Bus
```
**Pourquoi pas `hump.signal`** : son `emit` fait `for f in pairs(self[s])` = ordre de hash =
non déterministe → desync des replays seedés. (https://github.com/vrld/hump/blob/master/signal.lua)
hump.signal reste OK pour la **présentation** (son, screen-shake) où l'ordre est invisible au joueur.

### 6.4 Work-queue, jamais de récursion

Les handlers **enfilent** des ops ; une seule boucle `drain()` les vide, avec un **budget
`MAX_STEPS = 256`** (anti-boucle A→B→A). Snapshot « ce tick » de l'état lu par les handlers. Garde
de réentrance `(source, event)` par passe. Modèle `pending: VecDeque` (tcg_core) + règle LIFO du
blueprint Godot card-game.

### 6.5 Modifiers = buckets typés (déterministe, ordre-indépendant)

```
final = clamp( (base + Σflat) * (1 + Σincreased) * Π(more) )
```
Addition et `Σincreased` sont commutatifs ⇒ l'ordre d'itération ne change **jamais** le résultat ⇒
déterminisme garanti. **Snapshot vs dynamique par stat** : la valeur d'un coup se fige au moment du
coup ; l'attaque courante (issue des auras) se recalcule. (Modèle ModiBuff meta/post + PoE buckets.)

### 6.6 Auras d'adjacence = état DÉRIVÉ (jamais muté en place)

Recalcul `base + auras_actives` sur `on_place / on_remove / on_move / on_level_up / sigil_change`.
**Deux passes** : (1) reset au base, (2) accumuler toutes les contributions dans un bloc frais en
**ne lisant que le base** (deux unités qui se buffent mutuellement ne peuvent pas se court-circuiter),
(3) appliquer. La règle d'aura se stocke sur l'unité **source**, en termes **topologiques**
(`to="neighbors"`), jamais « slot #4 » → changer de sigil re-cible automatiquement via
`board:neighbors(slot)` (notre liste d'arêtes), **zéro code par sigil**. `aura_shield` (Rempart) se
range ici, unifié avec le reste sous `combat_start`/build-time. Anti-abus « 1 voisin = 1 étoile »
(Backpack Battles) : une source contribue au plus une fois par voisin.

### 6.7 L'attaque devient une ENTITÉ modifiable (fondation survivor-like)

```lua
-- construite à partir des stats de l'unité + ses modifiers on_hit/projectile, au moment de frapper.
local atk = { source=u.id, target=t, damage=u.stats.atk,
              pierce=0, chain=0, fork=0, riders={}, budget=… }   -- comportements composables
-- un fork = la MÊME entité avec budget décrémenté -> l'enfant est lui-même re-modifiable.
```
Modèle SNKRX (`shoot(angle, {pierce=…, chain=…})`) / PoE projectiles. **À différer** (YAGNI) jusqu'à
la première relique qui en a besoin — mais le bus + ops + buckets sont conçus pour l'accueillir.

### 6.8 Pièges à éviter (et leur fix)

| Piège | Qui l'a vécu | Fix adopté |
|---|---|---|
| Récursion inline pour les chaînes | — | work-queue + budget 256 |
| Itérer les handlers en ordre de hash | — | tri par timestamp/`seq` monotone |
| Auras mutées en place | tous les jeux d'aura | aura = dérivée, recalcul 2 passes |
| Construire le résolveur de dépendances MTG | MTG | buckets fixes + tie-break timestamp, point |
| `math.random` / float order-dependent | — | RNG seedé + buckets Σ/Π + clamp entier |
| Cœur qui importe les modules d'effets | — | les effets s'enregistrent DANS le cœur (flèche à sens unique) |
| Trigger soudé à la cible | SAP `ally summoned` | cible = axe séparé ; spécifique = `condition` |
| Boucles de triggers infinies | The Bazaar | cooldown interne / garde once-per-event + budget |
| Abus d'empilement (voisins identiques) | Backpack | « 1 voisin = 1 étoile » |

---

## 7. Taxonomie des triggers (liste de départ)

- **Cycle/run** : `combat_start`, `combat_end`, `round_start`, `sigil_change`, `slot_unlock`
- **Tick (cooldown)** : `on_tick`, `on_cooldown_ready`, `on_fatigue`
- **Action** : `on_before_act`, `on_attack`, `on_attacked`, `on_hit`, `on_cast`
- **Dégâts/PV (étages mutateurs)** : pipeline `damage_flat → damage_increased → damage_more →
  mitigation → clamp → post` ; événements `on_damage_dealt`, `on_damaged`, `on_heal`,
  `on_shield_absorb`, `on_overkill`
- **Mort/spawn** : `on_kill`, `on_death`, `on_summon`
- **Plateau (auras — signature The Pit)** : `on_place`, `on_remove`, `on_move`, `on_adjacency_change`,
  `on_level_up` (3 copies→niveau), `on_duplicate_merge`
- **Statuts** : `on_status_applied`, `on_status_removed`, `on_status_expired`

---

## 8. Harnais de test e2e + simulation de masse + analyse

### 8.1 Mock partagé + RNG seedé
Extraire le mock LÖVE de `tests/headless.lua` → `tests/mock_love.lua` (et **ajouter
`newRandomGenerator` seedé** pour que les seeds varient vraiment, le mock actuel renvoie 0.5 constant).

### 8.2 Event-log JSONL structuré (1 ligne / événement, append)
Sink **injecté** (nil dans le jeu live = coût zéro). Instrumenter les **2 chokepoints** : `Arena:damage`
(L99) et `Arena:hit` (L122) couvre ~tous les événements.

```lua
{ run=12, seed=0xA17F, tick=137, ev="damage", src="templar", src_slot=5,
  tgt="marauder", tgt_slot=4, effect="bonus_first",
  amount=17, absorbed=3, overkill=0, hp_after=43, shield_after=0 }
```
`effect`+`amount/absorbed/overkill` ⇒ **dégâts attribués par effet** (l'or de l'équilibrage).
`src_slot/tgt_slot` ⇒ vérifier les effets de **placement**. `seed`+`tick` ⇒ toute ligne est
reproductible. Persistance **JSONL** (pas un gros array JSON : on ne peut pas l'append/streamer).

### 8.3 Deux drivers
- **Logique (sims de masse)** : scénario = `{ shape, unlock, placements={[slot]=id}, encounter }` →
  `buildLeftComp`/`buildRightComp` → `Arena`. Rapide, sans maths d'écran, sans flakiness. Réutilise
  `Build:placeId` (déjà utilisé par les tests).
- **Input synthétique (e2e UI)** : rejoue les vrais événements souris via `self.pos[slot]` /
  `self.bench` (calculés, pas codés en dur) pour tester **le drag-drop et le hit-testing eux-mêmes** :
  `mousepressed(bench)` → `mousemoved(pos[slot])` → `mousereleased(pos[slot])` → `assert host.name=="combat"`.

### 8.4 Tests d'invariants (DST-style, dans la boucle)
- PV ≥ 0, bouclier ≥ 0 ; **terminaison** (cap de ticks = échec d'invariant, dump seed+log) ;
  **déterminisme** (même `(scénario, seed)` ×2 → log hash-égal — la propriété la plus forte, attrape
  les fuites RNG/`pairs` non anticipées) ; conservation ; sanity (exactement un vainqueur).
- **Fuzz** : builds valides aléatoires → ne crashent jamais.

### 8.5 Runner batch + stats (`tools/sim.lua`)
N sims sur une plage de seeds / matrice de matchups. Métriques (façon *Ludus*, AAAI-22, autobattler
déterministe) : **win-rate par unité**, **part de dégâts par effet**, **TTK moyen**, et surtout
**écart-type + entropie** du vecteur de win-rate (faible σ / haute entropie = méta saine ; une unité
outlier = trop forte/faible). Combat déterministe ⇒ chaque matchup = 0/1 ⇒ on couvre des matchups, on
ne moyenne pas. Écrit un `report.json` **diff-able** (CI). **Logs complets seulement pour les
scénarios flaggés/golden** (sinon explosion de volume).

### 8.6 Golden-log de régression
Log canonique (ou son hash) par scénario ; un diff signale toute régression de comportement. Garder
les stats entières (pas de float) évite les diffs flottants instables.

### 8.7 Outillage : runner `luajit` simple (PAS busted)
Fidèle à la contrainte zéro-dépendance ; `tests/headless.lua` prouve déjà le pattern « mock LÖVE,
vraie logique, `os.exit(1)` si échec ». Structure : `tools/sim.lua` (batch+stats),
`tests/headless.lua` (smoke), `tests/golden.lua` (replay+diff), `tests/props.lua` (fuzz+invariants),
mock partagé `tests/mock_love.lua`.

---

## 9. Performance (concevoir maintenant ce qui est coûteux à rétrofiter)

> **🍎 Fait majeur : sur Mac Apple Silicon, le JIT est OFF par défaut en LÖVE 11.5** (mémoire JIT pas
> fiable sur arm64). En dev local on tourne dans l'**interpréteur** → coût alloc/GC encore plus
> dominant, optims « trace-friendly » sans effet. **Profiler sur une machine JIT-on** (Win/Linux/x86)
> avant de croire un chiffre JIT. (https://love2d.org/wiki/11.5)

**Budget 60 Hz = 16,6 ms** : sim ≤ 6 ms · rendu ≤ 6 ms · GC+marge ≤ 4 ms.

- **Aucune allocation dans les boucles chaudes** : pas de `{}`, pas de closure, pas de string
  non-internée par frame. Emit **sans allocation** : bus indexé par trigger (on ne touche que les
  abonnés concernés) + **un seul `ctx` réutilisé** (forme de table stable/monomorphe), jamais de
  `{...}` (VARG NYI), jamais de table d'événement par emit.
- **Pooling** (free-list) des effets transitoires / nombres de dégâts ; `table.new(n,0)` +
  `table.clear` pour les buffers de frame. Swap-remove, jamais `table.remove` au milieu (O(n)).
- **Cheat-sheet LuaJIT** (vérifiée liste NYI) — bannir des boucles chaudes : `string.format`,
  `string.gsub/match`, `table.sort`, `table.insert` au milieu, `table.remove`, `{...}`, `error()`,
  `pcall`-as-control-flow, `os.*`/`io.*`/`coroutine.*`. Garder `love.graphics.*` **hors** de la sim
  (ça casse les traces). OK : `for i=1,#t`, `ipairs`, `pairs` (compilé en 2.1), `math.*`, `bit.*`.
- **O(n) pas O(n²)** : adjacence précalculée au changement de plateau (dirty-flag) en
  `neighbors[slot]={…}` ; front/back par index de colonne maintenu à la mort ; jamais de re-scan par
  tick. Optionnel plus tard : SoA (`hp[i]`, `atk[i]`…) seulement pour les champs chauds prouvés au profiler.
- **Rendu** : 1 atlas + filtre `nearest` ; laisser l'auto-batching 11.x coalescer les draws de même
  état ; `love.graphics.getStats()` pour surveiller `drawcalls`/`drawcallsbatched`. SpriteBatch
  manuel **seulement** si `drawcalls` grimpe.
- **Déterminisme et perf s'alignent** : les arrays ordonnés sont *à la fois* reproductibles ET les
  plus rapides (fast-path JIT + cache-linéaire). Aucun arbitrage.
- **Profilage** : `luajit -jp=v` (états VM : GC/interp/compilé), `-jv` (aborts de trace), `-jdump`,
  `love.graphics.getStats`. **Concevoir maintenant** : bus sans alloc, arrays denses, pooling, 1 atlas.
  **Différer** (jusqu'à preuve profiler) : SoA, SpriteBatch manuel, tuning GC, culling.

---

## 10. Règles anti-spaghetti (à inscrire dans CLAUDE.md)

1. **Un fichier = une table retournée.** Jamais de global.
2. **`require` en dot-path uniquement** (`require("src.core.rig")`), jamais slashes/`.lua`.
3. **Couche SIM sans `love.*`** : aucun `love.graphics/window/mouse/keyboard/timer`, **aucun
   `love.math.random`/`math.random`** dans `src/combat/`, `src/board/`, `src/effects/`. RNG/temps/alea
   arrivent via `ctx` injecté.
4. **RNG seedé, toujours injecté** (`self.rng:random()`), jamais le générateur global.
5. **Jamais `pairs()` pour itérer la sim** : arrays + `ipairs`/`for` numérique ; si clé par nom,
   trier d'abord.
6. **Direction de dépendance à sens unique** : `data ← logique ← scenes ← main` ; le rendu lit la
   sim, jamais l'inverse. `data/` ne require rien de chez nous (corriger l'arête `creatures→rig`).
7. **Effets/reliques/unités/formes = fichiers data qui s'enregistrent dans un registre** — ajouter du
   contenu n'édite jamais la logique cœur.
8. **Pas de god-table `game`/`G`.** Passer un `ctx` par les constructeurs (DI). Globals seulement pour
   constantes read-mostly (palette).
9. **Pas de reach-in inter-scènes** : `host.goto(name, payload)`, jamais require d'une autre scène
   pour toucher son état.
10. **Tell, don't ask** : les entités émettent des événements / posent des flags ; elles ne traversent
    pas le code pour muter les collaborateurs.

**Outillage d'enforcement (peu d'effort, fort rendement)** : `luacheck` avec `.luacheckrc`
(`std="luajit+love"`, `globals={}` → tout nouveau global = erreur) ; **grep-guard CI** (échec si
`love.graphics|window|mouse|keyboard` ou `math.random` sous `src/combat src/board src/effects`) ;
**assertion déterminisme** double-run même seed dans `tests/headless.lua` (option : `love.graphics=nil`
avant require de la sim pour faire planter tout draw égaré).

---

## 11. Décisions techniques (chacune sourcée)

| Décision | Reco | Source |
|---|---|---|
| **OOP** | **rxi/classic** (1 fichier MIT, ~30 lignes, zéro dep) quand la hiérarchie de modifiers arrive (`BaseModifier → ShieldAura/Poison/Thorns`) ; métatables faites main OK pour les singletons existants | https://github.com/rxi/classic |
| **State** | **Garder le `host` fait main** ; ajouter **hump.gamestate** (1 fichier vendu) seulement pour les overlays (pause/tooltip/relic-reveal/results *par-dessus* le plateau). La sim garde son `love.run` pas-fixe ; gamestate n'orchestre que les scènes/UI | hump docs ; LÖVE wiki Tutorial:Gamestates |
| **Registre / contenu** | `require` direct + registre data-par-id ; chaque pièce = 1 fichier listé dans un **`index.lua` manifeste maintenu à la main** (PAS `getDirectoryItems` : ordre « undefined » + `love.filesystem` absent sous `luajit` bare → casse le headless) | LÖVE wiki getDirectoryItems |
| **ECS** | **Pas d'ECS lib** (ni tiny-ecs ni Concord) : ~18 unités, l'abstraction ne rapporte rien et complique snapshot/déterminisme. « ECS-lite » fait main. Échappatoire : `tiny.lua` mono-fichier si un jour milliers d'entités transitoires | https://github.com/bakpakin/tiny-ecs |
| **Cycles require** | late-require dans la fonction, sinon extraire un 3ᵉ module partagé | — |

---

## 12. Plan d'exécution (par étapes, valeur décroissante)

- **Phase 0 — Déterminisme + firewall (fondation, corrige le bug live).** Injecter `ctx={rng,bus}`
  dans `Arena` ; remplacer `love.math.random()` (arena.lua:63) par `self.rng:random()`. Extraire
  `tests/mock_love.lua` + RNG seedé. Ajouter l'assertion déterminisme double-run. (grep-guard +
  `.luacheckrc` en option.)
- **Phase 1 — Bus + registre d'ops + descripteurs.** `src/core/bus.lua` ; `src/effects/` (engine +
  ops/ : lifesteal/dot/thorns/bonus_first ; `aura_shield`→`combat_start`). Migrer `units.lua`
  `passive` → `{trigger, op, params}`. Retirer l'échelle de `if` d'`arena.lua` + le cas spécial de
  `build.lua`. Buckets de modifiers. Work-queue + `MAX_STEPS`.
- **Phase 2 — Split sim/render.** `src/render/arena_draw.lua` possède `love.graphics` ; `arena.lua`
  émet des événements. Corriger les arêtes `creatures→rig` et `arena→rig`.
- **Phase 3 — Event-log + harnais.** Sink JSONL injecté ; instrumenter `:damage`/`:hit`.
  `tests/props.lua` (invariants+fuzz), `tests/golden.lua`. Drivers logique + input synthétique.
- **Phase 4 — Batch sim + stats.** `tools/sim.lua` : N sims, stats par unité/effet, σ/entropie,
  `report.json`.
- **Phase 5 — Attaque-entité (pierce/chain/fork).** Différé (YAGNI) jusqu'à la première relique qui
  l'exige ; le moteur est déjà conçu pour l'accueillir.

---

## 13. Questions ouvertes (à trancher avant de coder)

1. **Séquençage** : démarrer tout de suite Phase 0 (corrige le bug de déterminisme) puis Phase 1, ou
   un POC plus restreint d'abord ?
2. **Migration des 6 passifs existants** vers le modèle descripteur maintenant (refactor net, valide
   le modèle sur 6 cas), ou moteur en parallèle + migration incrémentale ?
3. **luacheck** : l'installer comme outil de dev (≠ dépendance runtime — n'enfreint pas le « zéro
   dep ») ? Sinon grep-guard + test déterminisme seuls.
4. **rxi/classic** vendu (1 fichier) OK quand la hiérarchie de modifiers le justifie ?
5. **Format de stats d'équilibrage** : table imprimée + `report.json` suffisent, ou aussi un CSV pour
   tableur ?

---

## 14. Index des sources (primaires d'abord)

- Lua 5.1 Reference Manual (`next`/`pairs`/`ipairs`/`table.sort`/`math.random`/`os.time`) — https://www.lua.org/manual/5.1/manual.html
- LÖVE wiki : `love.math.newRandomGenerator`, `RandomGenerator`, `getStats`, `newSpriteBatch`, `11.5` — https://love2d.org/wiki/
- LuaJIT : NYI list — https://github.com/tarantool/tarantool/wiki/LuaJIT-Not-Yet-Implemented · Profiler — https://luajit.org/ext_profiler.html · Running — http://luajit.org/running.html
- Super Auto Pets mechanics (4 axes) — https://a327ex.com/posts/super_auto_pets_mechanics · `saptest` — https://docs.rs/saptest/
- SNKRX (Lua, modifiers au spawn) — https://github.com/a327ex/SNKRX
- Slay the Spire : BaseMod Hooks — https://github.com/daviscook477/BaseMod/wiki/Hooks · StSLib Power Hooks — https://github.com/kiooeht/StSLib/wiki/Power-Hooks
- ModiBuff (meta/post/applier) — https://github.com/Chillu1/ModiBuff
- MTG layers/dépendances (à éviter) — https://ancestral.vision/spells-abilities-and-effects/interaction-of-continuous-effects.html · https://outsidetheasylum.blog/dependency/
- The Bazaar (enchantements/adjacence, boucles) — https://thebazaar.wiki.gg/wiki/Enchantment
- Backpack Battles (étoiles/diamants) — https://backpack-battles.fandom.com/wiki/Game_Mechanics
- Liquid Fire CCG action system — https://theliquidfire.com/2017/09/11/make-a-ccg-action-system/
- tcg_core TriggerBus — https://docs.rs/tcg_core/latest/src/tcg_core/triggers.rs.html
- Ludus (équilibrage autobattler déterministe, AAAI-22) — https://ojs.aaai.org/index.php/AAAI/article/view/21550
- hump (bus/gamestate) — https://github.com/vrld/hump · rxi/classic — https://github.com/rxi/classic · tiny-ecs — https://github.com/bakpakin/tiny-ecs
- LÖVE optimisation / batching — https://love2d.org/wiki/11.0 · https://auahdark687291.blogspot.com/2018/06/love-optimization-tips.html
- lua-tablepool — https://github.com/openresty/lua-tablepool
