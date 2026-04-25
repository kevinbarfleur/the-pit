# PRD-07 — Cards & Loot

## Goal

Système de cartes (items équipables persistants) avec pool de 30 cartes V1, tirées via draft 3-pick post-combat, gérées dans inventory cap 30, équipées dans 4 slots, fusables par 3.

Les cartes sont **le vecteur principal de progression active**.

## Non-goals

- 60-100 cartes V1 (V1.1 ramp)
- Cartes one-shot type Slay the Spire (V1 = items persistants)
- Stats randomisés / rolls (V1 = items définis statiquement)
- Card sets / synergies cumulatives (V1.1)
- Trading entre joueurs (jamais V1, peut-être V2)
- Card upgrade individuel via scrap (V1 = fuse only — 3 cartes même name+tier → +1 tier)
- Crafting recipes (jamais V1)

## User stories

- En tant que **joueur** post-combat, je vois 3 cartes proposées et je choisis la mieux pour mon build (ou skip pour scrap).
- En tant que **joueur**, j'auto-équipe une carte si slot vide, sinon swap explicite avec preview de diff.
- En tant que **joueur** avec inventory full, le drop force `auto-sell la T0 la plus basse pour scrap` plutôt que blocage.
- En tant que **joueur**, j'ai 3 "Iron Sword T0" et je les fuse en 1 "Iron Sword T1" via UI dédiée.

## Functional spec

### Pool de cartes V1

**30 cartes définies** réparties :
- 10 mainhand (variations damage / SPD / crit)
- 8 body (HP / block)
- 6 head (focus / crit)
- 6 charm (procs : on-hit shield, on-crit dmg, on-kill heal, etc.)

Chaque carte = entité statique avec :
```ts
interface CardDef {
  id: string  // 'iron_sword'
  name: string
  tier: 0 | 1 | 2 | 3 | 4
  slot: 'mainhand' | 'body' | 'head' | 'charm'
  stats: { dmg?: number; spd?: number; hp?: number; crit?: number; block?: number; focusRegen?: number }
  passive?: PassiveProc  // 'on-hit:shield(8)' etc.
  flavor?: string  // tooltip lore
}
```

### Loot draft (post-combat)

Après victoire combat :

```
┌──────────────────────────────────────────────────────┐
│  TAKE ONE                                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │ STONEWARD│ │ HOLLOW   │ │ ASH-ETCHED│            │
│  │  CHARM   │ │  BOW     │ │   BAND    │            │
│  │   T1     │ │   T0     │ │   T1      │            │
│  │ +12% blk │ │ +8 dmg   │ │ +5% scrap │            │
│  └──────────┘ └──────────┘ └──────────┘             │
│  [skip → +12 ◆] [reroll → 1 ✦]                      │
└──────────────────────────────────────────────────────┘
```

- 3 cartes random tirées du pool filtré par depth (cf. plus bas)
- `[skip]` : pas de carte, +12 scrap (récompense alternative)
- `[reroll]` : nouveau draft, coûte 1 shard, max 1 reroll par drop

### Pool filtering par depth

```
D1-D10  : T0 (90%) + T1 (10%)
D11-D25 : T0 (60%) + T1 (35%) + T2 (5%)
D26-D50 : T0 (30%) + T1 (50%) + T2 (18%) + T3 (2%)
D51+    : T0 (10%) + T1 (40%) + T2 (35%) + T3 (13%) + T4 (2%)
```

Replay node `cleared-replayable` : pool descendu d'1 tier max (T2 → T1 max sur replay).

### Auto-equip

Au draft + accept :
- Si slot **vide** → auto-equip + log discret bottom-screen "equipped: Iron Sword (mainhand)"
- Si slot **occupé** → popup swap explicite :
  ```
  ┌────────────────────────────────────┐
  │  KEEP CURRENT                      │
  │   IRON SWORD T0    +8 dmg          │
  │  vs.                               │
  │   STEEL SWORD T1   +12 dmg, SPD 1.1│
  │                                    │
  │  [Keep] [Swap]                     │
  └────────────────────────────────────┘
  ```
- L'ancienne carte va à inventory si Swap, sinon nouvelle reste à inventory

### Inventory cap

V1 : **cap 30 hard**.

À cap atteint, drop forcé :
- Si pas de cartes T0 dans inventory : popup blocage "inventory full, fuse or disenchant first"
- Si T0 présentes : auto-sell la T0 la plus basse contre scrap (ratio cf. ci-dessous), log discret "auto-sold: Wooden Stick → +5 ◆"

### Fuse / disenchant

- **Fuse** : 3 cartes mêmes name + tier → 1 carte tier+1 (max T3 par fuse — T4 inaccessible par fuse, drop only)
- **Disenchant** : 1 carte → scrap selon tier

```
Disenchant scrap value:
T0 → 5
T1 → 12
T2 → 30
T3 → 80
T4 → 250
```

UI dans `/cards` onglet :
- Liste inventory avec tabs filter (slot, tier)
- Bouton fuse visible si 3+ cartes mêmes
- Bouton disenchant individuel (clic-drag ou bouton)
- Bulk disenchant (V1.5 — cocher plusieurs)

### Pin / favorite

Joueur peut **pin** une carte → immune à auto-sell quand cap atteint.

UI : icône pin sur card, toggle on/off. Pinned cartes affichées avec border distinct.

## Technical approach

### Réuse existant

- `src/components/ui/Card.tsx` — UI card design system existant
- `src/components/ui/Tier.tsx` — tier badge
- `src/game/pit/rewardScale.ts` — scaling rewards par depth

### À créer

- `src/game/pit/cards/data.ts` : registry de 30 CardDef statiques
- `src/game/pit/cards/types.ts` : `CardDef`, `CardId`, `OwnedCard`, `PassiveProc`
- `src/game/pit/cards/draft.ts` : `generateDraft(depth, floorState, count=3) → CardDef[]`
- `src/game/pit/cards/fuse.ts` : `canFuse(cards) → boolean`, `fuse(cards) → CardDef`
- `src/components/loot/LootDraftDialog.tsx` : popup draft post-combat
- `src/components/loot/SwapConfirmDialog.tsx` : popup swap explicite
- `src/components/cards/InventoryGrid.tsx` : grid inventaire dans `/cards`
- `src/components/cards/CardDetailPanel.tsx` : détail carte (stats + flavor + actions)
- `convex/cards.ts` :
  - `acceptDraft(playerId, cardDefId)` mutation (génère nouvelle owned card, place in slot ou inventory)
  - `swapCard(playerId, slot, fromInventoryId)` mutation
  - `fuseCards(playerId, cardIds[3])` mutation
  - `disenchantCard(playerId, cardId)` mutation
  - `pinCard(playerId, cardId, pinned: boolean)` mutation

### Pre-conditions

- PRD-04 combat-end mutation declenche `getDraft` query qui retourne `CardDef[3]`
- `acceptDraft` doit être atomic avec combat win persists

## Data model

```ts
// owned card = instance of a CardDef in player's inventory
interface OwnedCard {
  id: string  // unique, generated at acquisition
  defId: string  // links to CardDef
  acquiredAt: number
  pinned: boolean
}

// in profile (cf. PRD-01)
profiles.cardsInventory: OwnedCard[]  // cap 30
profiles.cardsEquipped: { mainhand?: ownedId, body?: ownedId, head?: ownedId, charm?: ownedId }
```

Les `CardDef` (registry statique) ne sont **pas** stockés en Convex — chargés depuis code.

## Acceptance criteria

- [ ] Post-combat win : 3 cartes apparaissent en <500ms
- [ ] Draft pool respecte distribution par depth (testable via 1000 simulations)
- [ ] Auto-equip slot vide en <100ms après accept
- [ ] Swap popup affiche diff stats clair
- [ ] Inventory cap 30 strictement respecté
- [ ] Auto-sell choisit toujours la T0 la moins valuable + non-pinned
- [ ] Fuse valide : 3 cartes même name + tier → produit cartte tier+1, supprime les 3
- [ ] Pin/unpin persistant via Convex
- [ ] `/cards` onglet : recherche/filter par slot et tier fonctionnent

## Dependencies

- PRD-01 (profile schema cardsInventory + cardsEquipped)
- PRD-03 (slots & equipment)
- PRD-04 (combat-end → loot trigger)

## Open questions

- **Q7.1** Quelles 30 cartes V1 exactement ? Liste de noms + stats à finaliser dans annexe `specs/prds/07a-cardlist.md` (séparé). **Reco** : liste à drafter dans iteration suivante de ce PRD.
- **Q7.2** Skip draft → +12 scrap : montant fixe ou scaling depth ? **Reco V1 : scaling** = `+12 + depth * 0.5`, plus rentable au early game.
- **Q7.3** Reroll coût V1 : 1 shard hard ? Ou option scrap (50 scrap) si plus accessible ? **Reco** : V1 = 1 shard hard. V1.5 = scrap option en backup si shards trop rares.
- **Q7.4** Auto-sell quand cap : choisit T0 moins valuable, mais quel critère "moins" ? **Reco : tier asc, puis acquisition oldest** (FIFO).
- **Q7.5** Cartes pinned : limite (max 5 pins) pour éviter "tout pin = inventory illimité" ? **Reco V1 : max 10 pins**.
- **Q7.6** Fuse : nécessite **exact même name + tier**, ou cartes du même slot peuvent-elles fuser entre elles (ex 3 mainhand T0 différents → 1 mainhand T1 random) ? **Reco V1 : exact match only**, simplicité. V1.5 = "compose" version (3 same-slot → tier+1 random).
