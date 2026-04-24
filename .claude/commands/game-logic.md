---
description: Scaffold a pure game logic module under src/game/
argument-hint: <domain>/<module>
---

Create a pure game logic module at `src/game/$ARGUMENTS.ts` and its test file at `src/game/$ARGUMENTS.test.ts`.

**Strict rules for anything under `src/game/`:**
- **No imports of** `react`, `react-dom`, `pixi.js`, `convex/react`, `motion`, or anything DOM-related.
- **No `Math.random()`.** Use the seeded RNG from `src/game/rng.ts` (create it if missing — xoshiro256 or `pure-rand` wrapper).
- **No `Date.now()` or `performance.now()`.** Pass tick count or timestamps in as arguments.
- **No mutations of inputs.** Return new objects (Immer OK if complexity warrants).
- **Types first** — write function signatures and types before the bodies.

The test file uses Vitest and covers:
- Happy path with a fixed seed
- Determinism: same seed + same inputs = same outputs
- At least 2 edge cases (boundaries, overflow, empty input)

After creating both files, run `npm test -- $ARGUMENTS` to verify the tests execute (they can fail, but must run).

Report back: file paths, the module's public API (exported functions/types), and what it depends on vs what depends on it.
