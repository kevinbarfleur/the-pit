# 01 — Research Needs

> What we must study before committing to a design. Each item = open question we cannot answer from intuition.

## Priorities

- **P0** — blocks design decisions we need now
- **P1** — shapes V1 feel, study before MVP lock
- **P2** — polish, study during iteration

---

## A. Idle game design (core loop)

### A1. Progression math — P0
- OGame / Melvor / NGU Idle / Cookie Clicker economy curves.
- Exponential cost scaling: `cost(n) = base * ratio^n`. Standard ratios: 1.07 (Cookie), 1.15 (OGame), 1.30+ (NGU).
- "Soft wall" vs "hard wall" — how long between gates?
- **What to extract**: typical time-to-next-upgrade at each stage (early / mid / late), resource-sink ratios.

### A2. Prestige / reset loops — P1
- Do we want a prestige system? (NGU: yes, Melvor: no, OGame: no, HoGame: ?)
- If yes: what carries over (permanent bonuses, cosmetics, skill points), what resets.
- **Decision needed**: V1 without prestige (simpler) or bake hooks in early?

### A3. Active vs passive balance — P0
- We decided Delve = active = 80%+ of progression, offline = flavor.
- But *what* makes active engaging? Decisions per minute? Tension moments? Loot dopamine?
- Reference: Melvor "combat" (passive) vs "thieving" (active choice per action). Loop Hero = fully active. Hades = per-run.
- **What to extract**: decision density target — e.g., "a meaningful choice every 45s on average".

### A4. Offline progression caps & rates — P0
- Cap: 4h / 8h / 12h / 24h?
- Rate: 50% / 70% / 100% of online?
- How to display "welcome back" screen (modal? diegetic log? both?)
- Reference: Melvor (offline cap 12h, 100% rate), NGU (no cap, reduced rate), Idle Miner (cap scales with upgrades).

### A5. Loot table theory — P0
- **Drop rate curves**: linear, quadratic, log-based?
- **Pity systems** (Genshin, Hades): after N drops without rare, guaranteed next.
- **Magic find / IIQ / IIR** stats?
- **Smart loot** (Diablo 3 post-patch): drops bias toward player class.
- How do we keep rares *rare* without frustrating? Melvor's approach vs Idle Slayer's.
- **What to extract**: initial drop table schema, pity counter mechanic.

---

## B. Roguelite / delve design

### B1. Node-based map design — P0
- Reference: PoE Delve (infinite darkness, sulphite currency), Slay the Spire (branching act map), Hades (room choices).
- Branching factor: 2? 3? 4?
- Node types: combat, elite, boss, shop, event, rest, loot-only, trap.
- Distribution per "floor" or "section".
- **What to extract**: node archetypes for V1, ratios per depth bracket.

### B2. Procedural generation — P1
- Seed-based (daily seed? per-player seed?).
- How much variance? (Slay the Spire = lots, Monster Train = less, PoE Delve = mostly random).
- Should the same player see the same map on reload (deterministic) or reroll?
- **Decision needed**: determinism + anti-savescum strategy (server-generated from seed + depth).

### B3. Depth scaling curves — P1
- Enemy HP / DMG / rewards per depth. Reference: PoE Delve depth 500+ content.
- Difficulty spikes at boss floors? Or smooth?
- Player power curve vs enemy power curve (target: player must upgrade to keep up).

### B4. Boss design (single boss MVP) — P1
- Phases? Mechanics beyond stat-check?
- How does a boss in an auto-battler stay interesting? (answer: telegraphed attacks, positional choices, pre-fight decisions).
- References: Loop Hero bosses, Backpack Hero bosses, Melvor "Dungeon" bosses.

### B5. Risk/reward at each node — P1
- Should descending *consume* a resource (torches, sulphite, food)?
- Retreating: costless or punished?
- **Decision needed**: "descent resource" yes/no. PoE's sulphite is great design.

---

## C. Cards as items

### C1. Cards as RPG-loot — P0
- They replace "items" (no gear slots, only 8 card slots).
- Drop tables per enemy type: common trash drops common cards, elites drop uncommon+, boss has unique table.
- Rarity tiers (T3..T0 matches existing system).
- **What to extract**: which cards stay usable, which need rework, how drop rates map to existing tier system.

### C2. Card upgrade system — P1
- Duplicate cards → XP / fuse / upgrade?
- References: Darkest Dungeon trinkets, Slay the Spire upgrades (+ version), Marvel Snap card levels.
- **Decision needed**: upgrade path (fuse = simpler, +level = deeper).

### C3. Build archetypes — P2
- How many viable builds at endgame? 3? 5? 10?
- Anti-patterns: obvious "best build" that invalidates others (PoE early-league mega-meta).

---

## D. Terminal UI design

### D1. Terminal aesthetic spectrum — P0
- **Strict**: Caves of Qud, Dwarf Fortress ASCII, Cogmind → full monospace grid
- **Hybrid**: Loop Hero (ASCII assets + modern UI), Cultist Simulator (typed text + cards)
- **Inspired**: Warp terminal, Zed editor, k9s → monospace-first but with real buttons, animations, color
- **What we probably want**: hybrid. Monospace fonts + ASCII box-drawing + some pixel sprites. Study Loop Hero & Cultist Simulator closely.

### D2. Typography — P0
- **Monaspace** (GitHub) — has 5 widths (Neon/Argon/Radon/Krypton/Xenon), ligatures, texture variants. Perfect.
- **JetBrains Mono** fallback.
- Line-height / letter-spacing norms for readability at 14–16px.
- **What to extract**: type scale (12 / 14 / 16 / 20 / 24), when to use which Monaspace variant.

### D3. Color palette — P1
- Pit palette draft: `ink #0a0a0a`, `bone #d8cfb8`, `dim #6b6b6b`, `green #9ae66e`, `amber #d4a147`, `red #d45a5a`, `violet #9a7bd4`.
- Must pass accessibility (WCAG AA 4.5:1 for body text on ink).
- CRT tint option? (subtle green/amber over all content).
- Reference palettes: IBM DOS, Commodore 64 amber, Fallout terminals.

### D4. Layout patterns — P1
- ASCII box-drawing for containers: `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼`.
- Tables: alignment via monospace columns.
- Modals: centered box with doubled borders `═ ║ ╔ ╗ ╚ ╝`.
- Progress bars: `[████████░░] 80%` vs graphical.
- **What to extract**: component kit (Box, Table, ProgressBar, Modal, Toast, Log).

### D5. Pixel art integration — P2
- Characters/enemies as small pixel sprites inside ASCII containers?
- References: Caves of Qud recent pixel mode, Shattered Pixel Dungeon.
- **Decision needed**: static sprites or animated? 16x16 / 32x32 / 48x48?
- Pipeline: Aseprite → export spritesheets → PixiJS sprite-sheet loader.

### D6. Animation philosophy — P1
- Typewriter text reveals for story/events
- Glitch / scanline transitions
- Subtle flicker (CRT phosphor)
- No easing that feels "app-like" (spring bounces = wrong vibe). Prefer linear or step functions.
- Motion (ex-Framer): stagger, enter/exit, layout animations.

---

## E. Game-feel / juice

### E1. Combat auto-battler feel — P1
- We learned from V1 Pit: attack-style diversity (slash/thrust/smash/bolt), floating damage numbers, anticipation frames → all matter.
- PixiJS equivalent of GSAP setup we had.
- References: Backpack Hero, Loop Hero, Luck be a Landlord.

### E2. Loot drop feedback — P1
- Screen shake scaled by rarity
- ASCII glyph rain on legendary?
- Sound cues: each rarity = distinct chord/stinger.

### E3. Audio direction — P2
- Synthwave / dungeon-synth / dark-ambient?
- Texture (reverb, distant drips) more than melody.
- References: Caves of Qud OST, Hollow Knight crystal depths.

---

## F. Multiplayer / social

### F1. Leaderboard mechanics — P1
- Metrics: max depth, fastest boss kill, most gold, streaks?
- Anti-exploit: server-calculated, seed-verified.
- Twitch integration: show streamer's depth live? Whisper boss kills?

### F2. Twitch auth & identity — P0
- Convex Auth supports OAuth providers. Twitch is not built-in → need a custom provider (Auth.js Twitch provider adapter or manual OAuth2 flow).
- Research: how other Convex apps integrate Twitch. Recent Convex Auth docs.
- Token scopes: identity only (no broadcasting / chat yet).

### F3. Co-op / async interactions — P2
- "Leave a message in the pit" for other players to find?
- Dark Souls-style bloodstains (see where others died)?
- Likely cut from MVP but hold the hook.

---

## G. Technical research

### G1. Game loop architecture — P0
- Fixed timestep vs variable.
- Web Worker for tick (keeps running when tab blurred up to Chrome's 5min throttle limit).
- Deterministic simulation (for offline replay + leaderboard verification).
- References: GafferOnGames "Fix Your Timestep", NGU's open-source state machine.

### G2. State sync Convex ↔ client — P0
- What lives on server (gold, depth, saves) vs client (UI state, transient animations)?
- Optimistic updates: should clicking "buy upgrade" feel instant?
- How to reconcile tick frequency (10Hz?) with Convex mutation cost.
- **Likely pattern**: server stores snapshot + pending actions, client simulates between snapshots.

### G3. Anti-cheat — P0
- Server-authoritative means server re-simulates. Client sends *actions* ("I opened node X"), server validates + resolves.
- Seed all RNG on server.
- Rate-limit mutations.
- Research: how Melvor web / Cookie Clicker handle this.

### G4. Deterministic PRNG — P0
- Need seedable RNG (not Math.random).
- Candidates: `seedrandom`, `pure-rand`, hand-rolled xoshiro256.
- Same seed + same inputs = same outputs, both client-side (prediction) and server-side (authority).

### G5. PixiJS + React integration — P1
- `@pixi/react` vs imperative Pixi + React portal.
- Performance: avoid re-creating PIXI.Application on React renders.
- Sprite pooling for damage numbers etc.

### G6. Save format & migrations — P1
- Schema versioning in Convex (additive fields are free, renames = migration).
- Export / import savegame?

### G7. Offline detection & simulation — P0
- `visibilitychange` event → save snapshot.
- `onReconnect` → call Convex action `processOfflineGains({since})`.
- Convex action runs deterministic simulation → returns summary.

---

## H. Balancing & data

### H1. Spreadsheet-driven balance — P1
- Everything in CSVs (cards, enemies, upgrades) like V1 Pit.
- Convex seed script reads CSVs, inserts on deploy.
- Content team / iteration loop: edit CSV → commit → auto-re-seed.

### H2. Telemetry — P2
- What players actually do (nodes picked, build choices, death depth).
- Convex can log events cheaply.
- Private analytics, not shipped yet.

---

## Open questions to resolve before coding gameplay

1. **Prestige yes/no** (A2)
2. **Descent resource yes/no** (B5)
3. **Card upgrade path** (C2)
4. **Pixel sprites or pure text** (D5)
5. **Offline cap & rate specific values** (A4)
6. **Tick frequency** (G1) — 10Hz? 4Hz?
7. **Boss identity** — Kitava? Malachai? Sirus? Someone new?
8. **Game tagline / 30-second pitch** — need this to anchor every decision.

---

## Research output format

For each research item (especially P0), produce a ~500-word markdown note in `brainstorming/research/` citing sources, listing 3–5 concrete takeaways, and a recommendation. Format:

```
# <Title>

## Sources
- ...

## Findings
- ...

## Recommendation for The Pit
- ...
```
