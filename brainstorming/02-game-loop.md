# 02 — Game Loop (First Draft)

> A starting point to iterate on. Every number is placeholder. Every structure is up for debate.

## 30-second pitch

> **Descend into the Pit.** Crawl deeper with each run, loot cards from what you kill, spend scrap on permanent passives between runs. The deeper you go, the better the loot — and the more dangerous the climb back. Fight the Pit Boss at fixed depths to prove you can. All in a terminal.

---

## Macro loop (meta-progression)

```
        ┌──────────────────────────────────────┐
        │  CAMP (hub)                          │
        │  — shop, passives, deck, codex       │
        └──────────────┬───────────────────────┘
                       │  descend
                       ▼
        ┌──────────────────────────────────────┐
        │  DELVE (active session)              │
        │  — node map, combats, events, loot   │
        └──────────┬────────────────┬──────────┘
                   │ survive        │ die / retreat
                   ▼                ▼
        ┌──────────────────────────────────────┐
        │  RESOLUTION                          │
        │  — keep loot / convert to scrap      │
        │  — persist max depth                 │
        └──────────────┬───────────────────────┘
                       │
                       ▼  (back to Camp)
```

### Two phases

| Phase | Duration | Pace | Player activity |
|---|---|---|---|
| **Camp** | 1–5 min per visit | Slow, deliberate | Buy passives, manage deck, read logs, plan next descent |
| **Delve** | 5–15 min per session | Active, tense | Choose path, watch auto-combats, use abilities, grab loot |

---

## Micro loop (during a Delve)

```
  ┌─ DESCEND to node ─┐
  │                   │
  │   ┌─ Combat ─┐    │  auto-battler, player uses card actives
  │   │          │    │
  │   └──────────┘    │
  │                   │
  │   Loot / Event    │  drops go to run inventory
  │                   │
  │   Choice          │  2–4 next-node options shown
  │                   │
  └───────────────────┘
       repeat until death, boss, or voluntary retreat
```

**Per-session resources earned**: scrap (spendable at camp), cards (loot), depth record (persists).
**Lost on death**: everything *except* scrap (which auto-banks) and max-depth.

---

## Node types (V1)

| Node | Frequency | What it does |
|---|---|---|
| **Combat** | 60% | Fight a wave. Drop: cards, scrap |
| **Elite** | 10% | Harder combat, better drops, +1 passive choice |
| **Shop** | 8% | Trade scrap for in-run items, card rerolls |
| **Event** | 10% | Narrative choice with stat risk/reward |
| **Rest** | 5% | Heal / upgrade 1 card / smith |
| **Mystery** | 5% | Random (loot / trap / event) |
| **Boss** | fixed at D10, D25, D50, D100 | Defeat = huge scrap + unique card |

Branching factor: **2–3 paths** per node (Slay-the-Spire style).

---

## Combat (auto-battler MVP)

Mostly inherited from V1 Pit, refit to the new context:

- **8 card slots** (mainhand, offhand, body, 2 charms, focus, tactical, minor)
- **Action meter** per card + per enemy, ticks at speed determined by SPD stat
- **Keywords** (same 11 as V1) trigger on events
- **Player can't directly control** but can **burn "Focus"** (a depletable resource) to manually trigger a card's active early

New twist: **positional / lane system?** — maybe 3 lanes (front/mid/back), cards assigned to lanes at deck-building. Not sure yet, depends on how much complexity we want at MVP.

---

## Resources

| Resource | Source | Sink | Persists |
|---|---|---|---|
| **Scrap** (soft currency) | Combats, boss, converting unwanted cards | Camp passives, shop rerolls | Yes (auto-bank) |
| **Cards** (loot) | Drops from enemies | Deck, fuse into existing | Yes |
| **Focus** (in-run) | Combat crits, events | Manual card activations | No (resets each descent) |
| **Depth** (leaderboard) | Going deeper | — | Yes (max ever) |
| **Torches?** (descent resource) | Camp | Consumed per depth | TBD — see B5 research |

---

## Camp (between-runs hub)

One screen, terminal UI, divided in regions:

```
┌─────────────────────────────────────────────────────────────┐
│  [D] DELVE          [P] PASSIVES        [C] CARDS           │
│  [S] SHOP           [L] CODEX           [T] TWITCH BOARD    │
│                                                             │
│  MAX DEPTH: 34      SCRAP: 1,247        RUNS: 12            │
│                                                             │
│  > You stand at the edge of the pit. The darkness hums.     │
└─────────────────────────────────────────────────────────────┘
```

### Passives (permanent upgrades)
Categories:
- **Body** — HP, HP regen, damage reduction
- **Edge** — ATK%, crit chance, crit damage
- **Pact** — luck, scrap% gain, drop rate
- **Depth** — offline rate, descent speed, node reveal

Each category has 10+ tiers, exponential cost in scrap. Think OGame research tree structured as a node graph rather than a flat list.

### Shop
Consumables for next descent: extra torch, reroll charge, starting-card upgrade, scouting potion. Prices in scrap.

### Cards (deck)
- Sort, filter, fuse, disenchant.
- Choose 8 for the next descent.
- Locked slots until passive unlocks them (start with 3 slots, grow to 8).

---

## Offline progression (flavor)

On reconnect after `Δt` away:

```
┌─ WELCOME BACK ──────────────────────────────────────────────┐
│                                                             │
│  You were gone for 4h 12m.                                  │
│                                                             │
│  Something happened in the pit:                             │
│    + 847 scrap (passive mining)                             │
│    + 2 cards dropped (Rusted Dagger, Moth Cowl)             │
│    + 1 event occurred (Whisper in the deep)                 │
│                                                             │
│  [Claim and descend]                                        │
└─────────────────────────────────────────────────────────────┘
```

### Rules
- **Cap**: 4h at V1, expandable via Depth passives up to 12h.
- **Rate**: 50% of online scrap rate.
- **Delve does NOT progress offline** — only passive mining + ambient loot rolls.
- **Boss and nodes** don't auto-resolve. Player must return to play them.
- **Server-authoritative**: Convex action computes gains from `(now - lastSeenAt)` with server clock.

---

## Death & retreat

- **Die**: lose in-run inventory (except scrap, which auto-banks), max depth saved if new record.
- **Voluntary retreat**: at any node. Lose 50% of in-run inventory (keep scrap). Faster than dying on purpose.
- **Boss fail**: counts as death.
- **No permadeath of account**. You always have Camp.

---

## Session shape (target)

- **3–4 minute Camp** → shop, plan
- **8–12 minute Delve** → 1 descent attempt
- **1 minute Resolution** → look at loot, upgrade 1 card

Total **~15 minute session**. Can stretch to 30 min with deep passive shopping, or compress to 5 min "just a quick delve".

---

## What does NOT exist in V1

- Prestige / ascension
- Multiple bosses (one, period)
- Lanes / tactical positioning (maybe V1.1)
- PvP
- Guilds / groups
- Trading
- Crafting recipes (just fuse)
- Cosmetics shop

---

## What V1 *must* ship

1. Camp hub with 3+ passive trees
2. Delve node map (min 10 depths before first boss)
3. Auto-battler combat reusing V1 Pit engine
4. 30+ card definitions (mix of existing + new)
5. 8 enemy archetypes + 1 boss
6. Scrap economy + 10+ purchasable passives
7. Offline welcome-back
8. Twitch login + leaderboard (max depth)
9. Terminal UI skin throughout
10. Save/load via Convex

---

## Smell tests

Anything in this doc should answer "yes" to at least one:
- Does it make the player *want* to descend one more time?
- Does it create a meaningful decision in Camp?
- Does it make the Pit feel mysterious / dangerous?

If "no" to all three → cut it.

---

## Open / unresolved (punts to Research doc)

- Descent resource (torches/sulphite) — B5
- Card upgrade path (fuse vs +level) — C2
- Pixel sprites yes/no — D5
- Exact offline cap & rate — A4
- Prestige — A2
