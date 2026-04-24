# G4. Deterministic PRNG - P0

## Sources
- seedrandom npm: https://www.npmjs.com/package/seedrandom
- pure-rand npm: https://www.npmjs.com/package/pure-rand
- pure-rand GitHub: https://github.com/dubzzz/pure-rand
- xoshiro / xoroshiro reference site: https://prng.di.unimi.it/
- Rune, Making JS deterministic: https://developers.rune.ai/blog/making-js-deterministic-for-fun-and-glory

## Findings
- `Math.random()` is not suitable because it cannot be seeded or reproduced reliably across client and server. A deterministic game needs the same seed plus the same ordered inputs to generate the same outputs.
- `seedrandom` is simple and widely used, but it is old and state handling is less attractive for a server-authoritative game where replay and stream separation matter.
- `pure-rand` is a better default for this project because it is TypeScript-oriented and supports pure/immutable generator usage. Pure RNG state makes it harder to accidentally consume hidden rolls and desync client/server prediction.
- xoshiro/xoroshiro generators are strong candidates for performance and statistical quality, but hand-rolling them in JavaScript/TypeScript introduces risk around 64-bit arithmetic, BigInt performance, and cross-runtime consistency. Use a library first unless tests prove a need.
- Determinism is not only about the PRNG. It also requires stable sort order, integer math for weighted choices, explicit RNG stream ownership, and tests that replay the same action sequence across server/client packages.

## Recommendation for The Pit
- Use `pure-rand` for MVP.
- Create a small wrapper and ban direct RNG calls outside it:
  - `nextUint32(stream)`
  - `nextInt(stream, min, max)`
  - `rollChanceBps(stream, basisPoints)`
  - `weightedChoice(stream, entries)`
  - `shuffle(stream, array)`
- Use integer probabilities:
  - Basis points for percentages: 10000 = 100%.
  - Weighted tables use integer weights.
  - Avoid floating random thresholds for durable results.
- Split RNG streams:
  - `mapRng`
  - `combatRng`
  - `lootRng`
  - `eventRng`
  - `cosmeticRng` optional and non-authoritative
- Store per run:
  - root seed
  - current stream states
  - action count
  - map generation version
  - loot table version
- Use derived seeds per stream:
  - `hash(rootSeed + ':loot:' + runId)`
  - `hash(rootSeed + ':combat:' + nodeId)`
- Testing requirements:
  - Same seed + same actions -> same final snapshot.
  - Weighted table tests are stable across Node and browser build.
  - Reordering presentation effects cannot consume authoritative RNG.
  - Adding a new cosmetic roll cannot alter loot/combat outcomes.
- Do not expose server seeds to the client before outcomes if future competitive integrity matters. For prediction, send enough pre-resolved combat script or use client-only temporary rolls that are discarded on reconcile.
