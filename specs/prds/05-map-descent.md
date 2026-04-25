# PRD-05 — Map & Descent

## Goal

Réutiliser le map gen existant pour exposer une map verticale infinie où le joueur navigue par click sur nodes, avec navigation bidirectionnelle (descend / remonte pour replay), et états de node persistés en Convex.

## Non-goals

- Re-design du map gen (existe et fonctionne — `src/game/pit/generate.ts`)
- Visuel pixi des chains (existe — `ChainsEngine.ts` réutilisé tel quel)
- Multi-path branching complexe au-delà de Slay-style (V1 = chunks 20 floors, fan-out limité, comme actuel)
- Animation de zoom continue map↔node (existe déjà, à valider non-régression)
- Mini-map / overview compressed (V1.5)
- Re-roll d'un node (V2)
- Path locked behind boss kill (V1 = boss bloque convergence, classic)

## User stories

- En tant que **joueur**, j'arrive sur `/pit` et je vois la map verticale centrée sur `currentDepth`.
- En tant que **joueur**, je clique un node accessible en dessous (descend) → zoom-in → combat ou event.
- En tant que **joueur**, je scroll up dans la map et je vois mes floors clear, avec icône distinctive `cleared-replayable`.
- En tant que **joueur**, je re-clique un node clear → confirmation popup "loot dégradé ×0.4, engager ?" → re-engage.
- En tant que **joueur**, je vois les boss floors télégraphés différemment (sprite plus gros, glow, label "Pit Warden ahead").

## Functional spec

### Map render

- Vertical scroll. `currentDepth` au centre par défaut. Le joueur peut scroll up/down librement.
- Nodes affichés selon visibilité depth (V1 : tous floors visités + 5 prochains floors visibles).
- Nodes invisibles au-delà = "fog of war" (silhouette dimmée).

### Node states (réuse `src/game/pit/types.ts`)

- `fresh` : pas encore engagé (next floors visibles)
- `current` : node actif où le joueur se trouve (highlight prominent)
- `cleared-replayable` : engagé et clear, replayable
- `locked` : verrou (boss en amont pas battu)
- `bypassed` : skipped via path alternatif (V1 = pas utilisé, V1.5)

### Node types (réuse types existants)

| Type | Contenu V1 |
|---|---|
| `combat` | combat standard (PRD-04) |
| `elite` | combat +difficile, drop T1+ |
| `boss` | boss (D10, D25, V1 — PRD-08) |
| `event` | choix narratif simple (PRD-XX V1.5 stub V1) |
| `shop` | trade scrap → item (V1 stub) |
| `rest` | heal / upgrade card (V1 stub) |
| `treasure` | loot direct sans combat (V1 actif simple) |

V1 nodes interactifs full : `combat`, `elite`, `boss`, `treasure`. Autres = stub (engage = "Coming soon" then mark cleared).

### Navigation

- Click sur node accessible (next from `currentDepth` selon edges) → engage (zoom-in animation existante).
- Click sur node `cleared-replayable` (au-dessus de `currentDepth`) :
  - Confirm popup : "ce floor est déjà clear. loot dégradé ×0.4. engager ?"
  - Si confirm : engage normalement, mais `currentDepth` se met à jour vers ce floor (je remonte)
- Click sur node `locked` : disabled, tooltip "boss D10 to unlock"

### Replay modifiers (R7 mitigation)

Quand un node `cleared-replayable` est ré-engagé, applique un **modifier random** (depth-seeded pour reproductibilité).

V1 ship 3 modifiers :
- `swift` : enemy SPD ×1.2, damage ×0.9 ("a swift strike")
- `armored` : enemy HP ×1.3, damage ×1 ("hardened")
- `hollow` : enemy HP ×0.8, damage ×1.1 ("desperate")

Modifier visible avant engagement (icone + label).

### Boss telegraph

Boss floors (D10, D25 V1) sont visuellement différents même de loin :
- Sprite plus gros sur la map
- Glow effect (réuse `EffectsEngine`)
- Label "the warden waits" ou similaire
- Path converge sur ce node (existe déjà dans `generate.ts`)

### Map gen lazy

- À la connexion, génère `chunk(currentDepth / 20)` et `chunk(currentDepth / 20 + 1)` (current + next).
- Quand `currentDepth` enter next chunk, génère le suivant.
- Chunks gardés en mémoire client + persistés Convex (snapshot par chunk index, pour cohérence multi-onglets).

## Technical approach

### Réuse existant

- `src/game/pit/generate.ts` — map gen chunk-based, déterministe seedé
- `src/game/pit/types.ts` — node types & states
- `src/game/pit/rewardScale.ts` — scaling rewards par depth
- `src/pixi/ChainsEngine.ts` — chains visuelles entre nodes (V1 inchangé)
- `src/components/pixi/ChainsProvider.tsx` — provider engine
- `src/hooks/usePitRun.ts` — déjà câble seed + currentDepth
- `src/hooks/useChains.ts` — utilise chains engine

### À créer

- `src/components/pit/PitMap.tsx` (refait) : container scroll vertical, render NodeMap + ChainLayer
- `src/components/pit/NodeView.tsx` : un node visuel, selon state + type
- `src/components/pit/ReplayConfirmDialog.tsx` : popup confirmation re-engage
- `src/components/pit/ReplayModifierBadge.tsx` : badge modifier sur node replay
- `src/game/pit/replayModifiers.ts` : logique des 3 modifiers
- `convex/nodeStates.ts` :
  - `getNodeStates(playerId, chunkIdx)` query
  - `markNodeCleared(playerId, nodeId, modifier?)` mutation
- Étend schema (`convex/schema.ts`) : table `node_states`

### Pre-conditions

- Le map gen retourne déjà des nodes typés et statiques par seed. PRD-05 ne change pas le gen, juste l'UI + state.

## Data model

Schema additions :

```ts
node_states: {
  playerId: id<'players'>
  nodeId: string  // depth + col, e.g., "D047:c1"
  state: 'cleared-replayable' | 'locked-boss-gate'
  firstClearedAt: number
  timesCleared: number  // pour V1.5 progressive degrade
  lastModifierApplied?: 'swift' | 'armored' | 'hollow'
}
```

Index : `(playerId, nodeId)` unique.

## Acceptance criteria

- [ ] `/pit` charge map en <800ms, centrée sur `currentDepth`
- [ ] Scroll vertical fluide, performance 60fps même avec 50+ nodes visibles
- [ ] Click node accessible engage zoom-in + combat
- [ ] Click node `cleared-replayable` montre popup confirm + modifier preview
- [ ] Replay applique le modifier choisi, drops ×0.4 vs first clear
- [ ] Boss D10 visible distinctement même à `currentDepth = 5`
- [ ] Map state cohérent multi-onglets (Convex live query)
- [ ] Navigation back vers floor précédent : `currentDepth` updaté + persisté
- [ ] Aucun crash sur generation lazy de chunk suivant

## Dependencies

- PRD-01 (profile.currentDepth, deepestDepth, seed)
- PRD-04 (engage node combat)

## Open questions

- **Q5.1** (Q16) Layers narratifs / biomes V1 : 1 biome (D0-D∞) ou 2 (Surface 0-25, Shaft 26+) ? **Reco V1 : 1 biome visuel + tier names dans le UI/leaderboard** (cf. PRD-11). Vraie variation visuelle V1.5.
- **Q5.2** Replay modifier : appliqué automatiquement (random depth-seeded) ou choisi par le joueur ? **Reco : auto random**, simplicité V1.
- **Q5.3** Boss telegraph distance : visible depuis 5, 10 ou 15 floors plus haut ? **Reco : 5 floors** = juste assez pour donner anticipation sans spoil.
- **Q5.4** Lock node = visible ou caché tant que boss pas battu ? **Reco : visible mais grisé** avec tooltip explicatif. Donne sense of progression.
- **Q5.5** Map scroll : free-scroll (souris) ou snap-to-floor (keyboard) ? **Reco : free-scroll souris + keyboard ↑/↓ snap-to-floor**.
- **Q5.6** Modifier `swift` / `armored` / `hollow` impact reward (compense dégradation ×0.4) ? **Reco V1 : non** (modifier = saveur, pas reward bonus). Simple. À tuner par feedback.
