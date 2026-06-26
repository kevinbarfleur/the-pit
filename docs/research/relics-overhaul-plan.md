# Historical relic overhaul plan

Status: superseded / historical.

This file is kept as a short compatibility note because older code comments and
tests reference `relics-overhaul`. The old long rollout plan has been removed.

Current source of truth:

- `relics-design.md`
- `../../CLAUDE.md`
- `../README.md`

Current relic model:

- readable effects;
- 1-of-3 offer;
- Grimoire collection on discovery/grant;
- no lures;
- no hidden identification game;
- no persistent run handicap from a relic.

The existing relic code may still use labels such as `band`, `low`, `mid`,
`high`, `relic_aura_stat`, or comments inherited from the rollout. Those are
implementation details, not a revival of the cryptic relic model.
