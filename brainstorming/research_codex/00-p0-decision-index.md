# P0 Research Decision Index

## Sources
- See individual notes for source lists.

## Findings
- The P0 pass resolves the blocking design questions enough to start gameplay implementation. P1/P2 notes still deserve follow-up before MVP lock, but they should not block the first systems pass.
- The main design shape that emerges is: active delve owns meaningful progression; offline play is a capped, flavor-positive income layer; server authority owns every durable reward; the client owns prediction, animation, and local feel.
- Several references corrected assumptions in the prompt: Cookie Clicker building costs are commonly documented as +15% per owned building, and Melvor Idle's current official wiki documents offline progress as working up to 24 hours at online-equivalent progress.

## Recommendations for The Pit
- Prestige: no V1 prestige loop. Add schema hooks only: `seasonStats`, `legacyBonuses`, and `resetCount = 0`. Do not design around ascension yet.
- Descent resource: yes. Add a fuel-like resource for deliberate depth pushes. Working name: `torch`. It should gate deep active runs, not basic checking-in.
- Card upgrade path: store duplicates as `shards` from day one. V1 can ship a simple fuse-to-level path later without save migration.
- Pixel sprites vs pure text: hybrid terminal. Use text-first UI and ASCII containers; allow 32x32 or 48x48 enemy sprites inside combat panels. Do not build pure ASCII combat as the only path.
- Offline cap/rate: start at 8h cap, 25% common economy rate, no depth, no boss progress, no rare/T0 cards. Later upgrades can raise cap to 12h or 16h.
- Tick frequency: 4Hz deterministic simulation for economy/combat state; render at requestAnimationFrame. Avoid 10Hz server writes.
- Boss identity: use an original boss. Working name: `The First Auditor` or `The Pit Warden`. Avoid borrowed PoE names.
- Tagline: `An idle roguelite where every descent writes your economy.`
- 30-second pitch: `The Pit is a terminal-styled idle roguelite. Your base accumulates scraps while you are away, but real progress comes from active descents: pick a route, spend torches, survive auto-battler encounters, and slot the cards you pull from the dark. Every node is a risk/reward decision; every card is loot; every run feeds a server-verified economy that cannot be cheated by idle time alone.`
