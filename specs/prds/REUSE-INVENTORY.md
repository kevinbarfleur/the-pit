# REUSE-INVENTORY — Composants existants à réutiliser, pas réinventer

> **Règle dure** : avant d'introduire un nouveau composant/atom/engine, vérifier ici. Si un existant peut être étendu (props, variant, config), l'étendre. Si vraiment impossible, justifier dans la PR.
>
> Cible : un futur dev (ou agent) ne doit **jamais** se retrouver avec un composant pit nouveau qui doublonne un existant. Le repo a déjà ~110+ fichiers de feature/ui/engine/hook avec beaucoup de polish accumulé. Le travail Sprint 1 = câbler ces lego, pas en sculpter de nouveaux.

---

## 1. UI atoms (`src/components/ui/`) — utiliser tels quels

| Fichier | Usage | Notes |
|---|---|---|
| `Button.tsx` | CTAs partout. **Variants juicy** : `primary` (herbe), `danger` (sang `drip-pool`), `default` (embers fumants), `ghost` (muet) | `juicy` prop active hover effect + click burst. Couleurs : primary `0x9ae66e`, danger `0xd45a5a`, default `0xd4a147`. **Voir §1.1 — variant = mood, pas rôle UX** |

### 1.1 Choix du variant Button — mood narratif, **pas** rôle UX

> Le naming `primary / danger / default / ghost` dans le code est trompeur. Ces noms désignent des **moods visuels**, pas une hiérarchie UX (action principale / destructive / secondaire).
>
> Le mood est choisi par rapport à **ce que l'action raconte** dans la fiction du jeu, pas par rapport à son rang d'importance dans l'écran.

**Règles de choix** :

| Mood (variant) | Effet | À utiliser quand l'action évoque… |
|---|---|---|
| `danger` (drip-pool sanglant) | Sang qui s'accumule + globules | Engagement avec la violence / le danger / la mort. **Même si c'est l'action principale de l'écran**. Ex : *Descendre dans le pit*, *Engage boss*, *Retreat (forced wipe)*, *Sacrifice card*. |
| `primary` (grass herbe) | Lames d'herbe + vent | Vie, calme, croissance, soin, restauration. Ex : *Rest at camp*, *Heal*, *Plant a beacon*, *Keep card*. |
| `default` (embers fumants) | Charbons ascendants chaleur | Ambient, mystique, neutre, contemplatif, ressource. Ex : *Open settings*, *Inspect card*, *Continue (ambient)*, *Forge*. |
| `ghost` (muet) | Aucun effet hover | Action discrète, secondaire, infos, navigation neutre. Ex : *Cancel*, *Close*, *Skip*, *Lien settings*. |

**Exemple concret** (descente dans le pit) :
- L'écran a un grand CTA "Engage" qui lance le combat boss D10. **Architecturalement**, c'est l'action primaire de l'écran. **Narrativement**, c'est un saut dans la violence — donc on utilise `variant="danger"` (sang), **pas** `variant="primary"`.
- À l'inverse, "Rest" sur un node `rest` → `variant="primary"` (herbe), parce que mood = vie/calme, même si c'est l'action principale du popover.

**Anti-règle** : ne jamais raisonner "c'est l'action principale, donc primary". Toujours raisonner "que raconte l'action ?".

**Si aucun mood ne colle** (ex : action mystique pure → `sparkle` ; trésor → `godray` ; commerce → `coins`) :
1. Vérifier que l'`AttachKind` cible existe dans `EffectsEngine` (cf. §5.1).
2. Si oui → ajouter un nouveau `variant` dans `Button.tsx` qui mappe vers ce kind (ex : `mystic` → `sparkle`, `loot` → `godray`, `shop` → `coins`).
3. Documenter dans cette table.
4. **Ne jamais bypasser** `Button` en réimplémentant un effet au cas par cas.
| `Card.tsx` | Conteneur générique avec bordure | À utiliser pour panels gameplay |
| `Panel.tsx` + `PanelTitle.tsx` | Boîte sectionnée | Drawer / modal-less containers |
| `Pill.tsx` | Badges / tags / ressources | Topbar pills (scrap, shards, torch) |
| `Bar.tsx` / `SegBar.tsx` | Barres ressources fluides ou segmentées | HP, Focus, action meters |
| `Tier.tsx` | Affichage rareté T0/T1/T2/T3/T4 | Cartes draft + détails |
| `Topbar.tsx` / `Menubar.tsx` / `Footer.tsx` | Chrome layout app | PRD-02 |
| `PixelFrame.tsx` | Bordure pixel-art autour content | Modals, panels gameplay |
| `Node.tsx` | Petit indicateur visuel d'état | Sub-affichages état |
| `Input.tsx` | Champ texte | Settings, search |
| `Kbd.tsx` | Touche clavier inline | Help docs, tooltips onboarding |
| `Divider.tsx` / `Row.tsx` / `Heraldry.tsx` / `Ribbon.tsx` | Layout helpers | Décor + structure |

**Source de vérité** : `src/components/ui/index.ts` exporte tout. **Importer depuis `'@/components/ui'`** (alias Vite défini).

---

## 2. Pit map & scene (`src/features/pit/`) — colonne vertébrale du jeu

> Tout le pit map est déjà construit. PRD-05 = câbler les rooms vides + retreat + replay. **Ne refaire aucun de ces composants.**

| Fichier | Rôle | Réuse PRD |
|---|---|---|
| `PitScene.tsx` + `.module.css` | Orchestrateur scene state machine `pit / zooming-in / in-node` | PRD-02, PRD-05 |
| `map/PitView.tsx` | Viewport vertical, matérialise window de chunks | PRD-05 |
| `map/NodeMap.tsx` | Grid 3 colonnes par depth, rendu IslandNode | PRD-05 |
| `map/IslandNode.tsx` | Bouton îlot par node + hover effect mappé par node type | PRD-05 |
| `map/drawIsland.ts` | Pixel art cap/signpost/décor + projection 3D iso world→screen + jitter déterministe par id | PRD-05 — **algo custom, ne pas refaire** |
| `map/NodePopover.tsx` | Inline popover détails au hover/click node | PRD-05, PRD-06 (threat tier viendra dedans) |
| `map/IslandPreview.tsx` | Tooltip preview détaillé îlot | PRD-05 |
| `map/DepthGauge.tsx` | Barre latérale depth + ticks milestones | PRD-05, PRD-08 (markers boss) |
| `map/ChainLayer.tsx` | Layer Pixi qui sync chains entre nodes | PRD-05 |
| `transition/ZoomTransition.tsx` | Animation zoom-in/zoom-out map↔room | PRD-05 — **à conserver, transition continue, pas un swap de route** |
| `rooms/RoomForType.tsx` | Dispatcher par `PitNodeType` | PRD-04 (combat), PRD-05, PRD-07 (treasure), PRD-08 (boss) |
| `rooms/CombatRoom.tsx` | Stub combat — **à remplir PRD-04** | PRD-04 |
| `rooms/EliteRoom.tsx` / `BossRoom.tsx` | Stubs boss/elite — **à remplir PRD-04 + PRD-08** | PRD-04, PRD-08 |
| `rooms/EventRoom.tsx` / `ShopRoom.tsx` / `RestRoom.tsx` / `CacheRoom.tsx` / `TreasureRoom.tsx` | Stubs — V1 = stubs minimaux ok | PRD-05 |
| `rooms/RoomStub.tsx` + `.module.css` | Layout générique room vide | PRD-05 |

**Mapping `TYPE_HOVER`** (déjà câblé dans `IslandNode.tsx` — ne pas redéfinir ailleurs) :
```
combat   → 'pulse'
elite    → 'embers'
boss     → 'embers'
event    → 'sparkle'
shop     → 'coins'
rest     → 'grass'
cache    → 'sparkle'
treasure → 'godray'
```

---

## 3. Hub & title (`src/features/hub/`, `src/routes/title.tsx`)

| Fichier | Rôle |
|---|---|
| `HubPage.tsx` + `.module.css` | Landing hub (post-login V1) — réutiliser comme base si Hub conservé après auth obligatoire |
| `HubChains.tsx` | Chaînes décor sur landing |
| `InfoCluster.tsx` + `.module.css` | Widgets stats joueur |
| `routes/title.tsx` + `.module.css` | Écran titre ASCII + menu | À transformer en `/auth` via PRD-01 — réutiliser layout/style |

---

## 4. Personnages (`src/game/characters/`, `src/features/characters/`, `src/pixi/CharacterEngine.ts`)

> 12 personnages riggés + engine d'animation data-driven. Bestiaire complet déjà là.

**12 defs prêts** (`src/game/characters/defs/*.ts`) :
`archer`, `bandit`, `crab`, `demon`, `dummy`, `marauder`, `merchant`, `skeleton`, `spectre`, `templar`, `witch`, `zombie`

**Structure** (`src/game/characters/types.ts`) :
```ts
CharacterDef { name, parts: Record<string, PartSpec>, rig: RigNode[], idlePose?, animations?, flipped? }
```

**Palette** : `src/game/characters/palette.ts` — mapping char→hex.

**Engine** (`src/pixi/CharacterEngine.ts`) :
- `createCharacter(def, palette)` → instance Pixi
- `updateCharacter(char, t, dt)` → tick
- `triggerState(char, 'idle' | 'attack' | 'hurt')` → switch state
- `disposeCharacter(char)` → cleanup
- Defaults : `defaultIdle` (breathing/sway), `defaultAttack` (windup/strike/recovery), `defaultHurt` (flash/knockback). Chaque def peut override.
- Constantes : `ATTACK_DURATION=35`, `HURT_DURATION=30` (frames)

**Wrapper React** : `src/features/characters/CharacterSprite.tsx` — mount instance + RAF update.

**Showcase** : `src/features/characters/Bestiary.tsx` (route `/kit/characters`).

**PRD usage** :
- PRD-03 Hero → utiliser CharacterSprite + un def dédié hero (à créer dans `defs/hero.ts` selon même pattern)
- PRD-04 Combat → `triggerState` au tick combat 4Hz pour idle/attack/hurt
- PRD-08 Boss → réutiliser un def existant (templar/demon/skeleton…) + scaling, **pas de nouveau rig from scratch**

---

## 5. Pixi engines (`src/pixi/`) — physique custom, **ne pas refaire**

### 5.1 EffectsEngine (`src/pixi/EffectsEngine.ts`)

Singleton fullscreen Pixi app. APIs :
- `emitBurst({ x, y, variant })` → particle burst (juicy click)
- `shockwave({ x, y, color, size })` → expanding ring
- `drip({ x, y, color, count })` → gouttes one-shot
- `attach(el, kind, config)` → effet continu attaché à un DOM element ; renvoie cleanup fn

**11 `AttachKind` disponibles** :

| Kind | Description | Usage existant |
|---|---|---|
| `aura` | Orbite particules autour élément | hover générique |
| `ripple` | Onde concentrique | attention pings |
| `pulse` | Aura pulsée | combat nodes (`TYPE_HOVER.combat`) |
| `sparkle` | Éclats aléatoires | event/cache nodes |
| `drips` | Gouttes simples tombent | misc |
| **`drip-pool`** | **Sang qui s'accumule + globules détachés** | **Button `danger`** |
| **`grass`** | **Lames d'herbe qui poussent + vent** | **Button `primary`, rest nodes** |
| `embers` | Charbons ascendants | Button `default`, elite/boss nodes |
| `godray` | Rayons rotatifs | treasure nodes |
| `coins` | Pièces lofted en arc | shop nodes |
| `spring` | Cascade Verlet | event-spring nodes (eau) |

**Physique custom dedans** (à ne pas réécrire) : particle pool 320 caps, ring pool 48, orbit pool 48, grass per-blade wind sway + detach-on-cut, drip 1D fluid (diffusion + gravity + pinch-off), embers trail smearing, godray rotating beams, coins lofting+gravity, spring Verlet rope cascade.

### 5.2 ChainsEngine (`src/pixi/ChainsEngine.ts`)

Verlet rope pour chaînes inter-nodes :
- `ChainSpec { id, fromX, fromY, toX, toY, state, slack, gravityScale }`
- `ChainState : 'traversed' | 'active' | 'latent' | 'bypassed'`
- Constantes : `GRAVITY=600 px/s²`, `DAMPING=0.985`, `ITERATIONS=12`, `MIN_NODES=4`
- Pointer interaction : `POINTER_RADIUS=60`, `POINTER_GAIN=0.15` (gust velocity-based, pas répulsion statique)
- Maillon spacing 5px (interlock visuel)
- Variants visuels : cap-hugging cascade, spring/event-spring (intégré avec EffectsEngine)

**Usage** : `src/features/pit/map/ChainLayer.tsx` ; provider `ChainsProvider`.

### 5.3 CharacterEngine — voir §4.

---

## 6. Hooks (`src/hooks/`)

| Hook | Signature | Usage |
|---|---|---|
| `useEffects()` | `→ EffectsEngine \| null` | Accès burst/shockwave/attach (consumer EffectsProvider) |
| `useChains()` | `→ ChainsEngine \| null` | Sync chain specs |
| `useHoverEffect(ref, kind, config, enabled)` | `→ void` | Attach effect au hover, détache au blur |
| `useHoverAura(ref, color?, intensity?)` | `→ void` | Sucre syntaxique pour `attach('aura')` |
| `useAttachedEffect(ref, kind, config)` | `→ () => void` | Manuel : attach + cleanup explicite |
| `usePitRun()` | `→ { window, currentDepth, start(), commit(node), registerClear() }` | State local de la run pit |
| `usePlayerIdentity()` | `→ { playerId, displayName }` | À refactorer PRD-01 (Twitch obligatoire) |
| `usePlayerProfile(playerId)` | `→ Profile \| null` | Live query Convex |
| `useRunLifecycle()` / `useDepthSync` | `→ void` | Throttled push depth → Convex |
| `useAnonId()` | `→ string` | **À supprimer PRD-01** — auth Twitch obligatoire override anon |

---

## 7. Game logic pure (`src/game/`)

### 7.1 Pit generation (`src/game/pit/generate.ts`) — **algo critique**

Chunk-based déterministe (Slay-the-Spire-like) :
- `CHUNK_HEIGHT = 20`, `MAX_COLUMNS = 3`, `STARTING_DEPTH = 50`, `BOSS_EVERY = 20`
- **Anti-crossing strict** : edge `(p_col → c_col)` rejetée si edge concurrent `(p2_col → c2_col)` même depths avec `(p_col − p2_col) × (c_col − c2_col) < 0`
- Path walking : `[col-1, col, col+1]` biaisé vers col du boss
- Convergence vers boss à depth 19 du chunk (col=1)
- RNG seeded `xoroshiro128plus(hashSeed(runSeed, salt))` via `pure-rand`
- Type distribution pondérée par depth (combat 50%, event 20%, etc.)
- Cross-linking entre chunks pour continuité

**API** :
- `generateChunk(runSeed, chunkIndex)` → `PitChunk`
- `materializeWindow(runSeed, fromDepth, toDepth)` → fenêtre visible

**Tests fuzz** : `generate.fuzz.test.ts` — ne pas casser.

### 7.2 Types (`src/game/pit/types.ts`)

- `PitNodeType` (8) : `combat | elite | boss | event | shop | rest | cache | treasure`
- `PitNodeState` (6) : `fresh | current | cleared-replayable | locked | bypassed | …`
- `PitNode`, `PitChunk`, `PitRunState`, `PitGraph`

### 7.3 Reward scale (`src/game/pit/rewardScale.ts`)

- `rewardScaleBp(depth)` — base scaling
- `farmRewardScaleBp(currentDepth, nodeDepth)` — replay : `10000 − 600 × Δ`, clamp ≥ 0 (cap ~17 niveaux backtrack)
- Tests fuzz : `rewardScale.fuzz.test.ts`

---

## 8. Routes (`src/routes/`) — TanStack Router

| Route | Fichier | État |
|---|---|---|
| `/` | `index.tsx` | Landing redirect |
| `/title` | `title.tsx` | Écran titre — base pour `/auth` PRD-01 |
| `/pit` | `pit.tsx` | Monte `PitScene` |
| `/ilots` | `ilots.tsx` | Map overview (probablement debug) |
| `/kit` | `kit/index.tsx` | Index design kit |
| `/kit/characters` | `kit/characters.tsx` | Bestiary |
| `/kit/camp` / `/kit/combat` / `/kit/wireframe` | `kit/*.tsx` | Pages debug |
| `__root.tsx` | App shell | Provider wrappers (Effects, Chains, Convex) |

**À créer (Sprint 1)** : `/auth` (PRD-01), `<AuthGuard>` wrapper appliqué dans `__root.tsx` ou layouts.

---

## 9. Convex (`convex/`)

| Fichier | Contenu | État |
|---|---|---|
| `schema.ts` | `players` + `profiles` tables | À étendre PRD-01 (Twitch fields, sessions) + PRD-04 (combat) + PRD-05 (depth) |
| `players.ts` | `getOrCreateByAnonId` mutation | **À remplacer** par flow Twitch OAuth (PRD-01) |
| `profiles.ts` | `getByPlayer`, `updateDepth` (monotone) | À étendre — base solide |
| `_generated/*` | Types auto Convex | Ne pas toucher |

---

## 10. Patterns à respecter

1. **Aliases imports** : `@/components/ui`, `@/hooks/...`, `@/features/...`, `@/game/...`, `@/pixi/...` — ne pas mixer relatif/absolu sans raison.
2. **CSS Modules** : co-location `Component.tsx` + `Component.module.css`. Pas de Tailwind utilities mixées sauf déjà présent.
3. **Pixi providers** : monter via `EffectsProvider` + `ChainsProvider` dans `__root.tsx`. Ne pas instancier d'Apps Pixi parallèles.
4. **Random** : toujours `pure-rand` + seed, jamais `Math.random()` sur de la logique gameplay.
5. **Convex authoritative** : tout state critique (depth, scrap, combat result) passe par mutation, pas par localStorage. localStorage = settings UI uniquement.
6. **Tests fuzz** : `*.fuzz.test.ts` doivent passer. Si tu touches `generate.ts` ou `rewardScale.ts`, valider.

---

## 11. Hard rule : avant de créer un nouveau composant

**Checklist obligatoire** :
1. Existe-t-il déjà dans `src/components/ui/` ? Si oui → utiliser ou ajouter une `variant`/`size`.
2. Est-ce un atom de pit map ? Existe-t-il dans `src/features/pit/map/` ?
3. Est-ce un effet visuel ? Existe-t-il un `AttachKind` dans `EffectsEngine.ts` qui couvre ? Si non, ajouter le kind à l'engine **avant** de créer un composant React qui le contourne.
4. Est-ce une logique gameplay ? Existe-t-il déjà dans `src/game/pit/` (generate, rewardScale, types) ?
5. Est-ce un state Convex ? Existe-t-il déjà dans `convex/players.ts` / `profiles.ts` ?

Si la réponse à toutes ces questions est non → tu peux créer. Documente la justification dans le commit message.

---

## 12. Anti-patterns spécifiques (déjà identifiés)

- ❌ Refaire un nouveau composant "Pit" qui n'utilise pas `PitScene` / `PitView` / `IslandNode`
- ❌ Réimplémenter une animation idle/attack/hurt sans passer par `CharacterEngine`
- ❌ Réécrire la génération de map (déjà chunk-based + anti-crossing tested)
- ❌ Câbler une chaîne visuelle sans `ChainsEngine`
- ❌ Créer un bouton CTA sans réutiliser `Button` + variant
- ❌ **Choisir le `variant` Button selon le rôle UX** (« c'est l'action principale donc primary ») — toujours selon le **mood narratif** de l'action (cf. §1.1). Descendre dans le pit = `danger` même si c'est le CTA principal.
- ❌ Faire un `aura` / `embers` / `grass` "à la main" plutôt qu'`attach(el, kind, config)`
- ❌ Stocker le depth en localStorage (Convex authoritative)

---

## Index inverse — quel PRD utilise quoi

**PRD-01 Identity & Persistence** :
- `convex/schema.ts`, `players.ts`, `profiles.ts` (étendre)
- `src/hooks/usePlayerIdentity.ts`, `usePlayerProfile.ts` (refactor pour Twitch)
- `src/hooks/useAnonId.ts` (supprimer)
- `src/routes/title.tsx` (transformer en `/auth`)

**PRD-02 App Shell & Routes** :
- `src/routes/__root.tsx` (ajouter `<AuthGuard>`)
- `src/components/ui/{Topbar,Menubar,PixelFrame,Footer,Pill,Button}.tsx`
- `src/features/hub/{HubPage,HubChains,InfoCluster}.tsx`
- `EffectsProvider`, `ChainsProvider`

**PRD-03 Hero & Equipment** :
- `src/game/characters/types.ts` + créer `defs/hero.ts`
- `src/pixi/CharacterEngine.ts`
- `src/features/characters/CharacterSprite.tsx`
- `src/components/ui/{Button,Bar,SegBar,Tier,Pill}.tsx`

**PRD-04 Combat Engine** :
- `src/pixi/CharacterEngine.ts` (`triggerState` au tick)
- 12 character defs (`src/game/characters/defs/*.ts`) comme bestiaire
- `src/pixi/EffectsEngine.ts` (`emitBurst`, `shockwave`, `drips` pour hits/crits)
- `src/components/ui/{Bar,SegBar,Button,Pill}.tsx`
- `src/features/pit/rooms/{CombatRoom,EliteRoom,BossRoom}.tsx` (remplir stubs)

**PRD-05 Map & Descent** :
- `src/game/pit/{generate,types,rewardScale}.ts`
- `src/features/pit/PitScene.tsx`
- `src/features/pit/map/*` (PitView, NodeMap, IslandNode, drawIsland, NodePopover, IslandPreview, DepthGauge, ChainLayer)
- `src/features/pit/transition/ZoomTransition.tsx`
- `src/features/pit/rooms/RoomForType.tsx`
- `src/pixi/ChainsEngine.ts`
- `src/hooks/{usePitRun,useRunLifecycle}.ts`
