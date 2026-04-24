# G3. Anti-Cheat - P0

## Sources
- Unity Netcode for Entities, prediction and server authority: https://docs.unity3d.com/Packages/com.unity.netcode%401.3/manual/intro-to-prediction.html
- Gabriel Gambetta, Client-side prediction and server reconciliation: https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html
- Daniel Jimenez Morales, Client-side prediction and reconciliation: https://danieljimenezmorales.github.io/2025-06-20-client-side-prediction-and-server-reconciliation/
- Twitch/Convex auth sources in F2 for identity implications.

## Findings
- The anti-cheat principle is simple: the client can predict, animate, and request; the server decides. Client authority is vulnerable because edited browser state can invent resources, drops, time, and outcomes.
- The Pit's main cheat vectors are not aimbots; they are time manipulation, save editing, reward injection, RNG manipulation, duplicate command replay, and leaderboard pollution.
- Deterministic simulation plus server-owned RNG is enough for MVP anti-cheat if all durable state is server-calculated. The client should never send `I got card X` or `I earned 500 gold`; it sends `I chose node N`.
- Rate limits and idempotency matter. Without them, a user can replay a valid command, double-submit reward claims, or spam actions until a race condition appears.
- Leaderboards should be computed from server-owned event logs/snapshots only. Imported saves, debug sessions, or offline-only states should not be leaderboard eligible.

## Recommendation for The Pit
- Server-authoritative commands only:
  - `startRun`
  - `chooseNode`
  - `resolveCombat` or `finishNode`
  - `chooseReward`
  - `equipCard`
  - `buyUpgrade`
  - `retreat`
  - `processOfflineGains`
- Never accept these from the client as facts:
  - earned gold amount
  - card drop ID
  - enemy killed
  - boss time
  - max depth
  - RNG roll result
  - offline duration
- Server validation checklist per command:
  - authenticated user owns save/run
  - `stateVersion` matches or can be safely reconciled
  - `actionId` has not already been processed
  - requested node is adjacent/reachable
  - torch/gold/card resources are sufficient
  - run is in the correct phase
  - command cadence is plausible
- RNG policy:
  - Server stores seed/state.
  - Server resolves every loot/combat/map roll.
  - Client may mirror RNG only for prediction, never authority.
- Leaderboard eligibility:
  - Server-generated runs only.
  - No debug flags.
  - No imported saves.
  - No unresolved desyncs.
  - Metrics derived from action log and canonical snapshots.
- Rate limits:
  - Per-user command rate, e.g. max N gameplay mutations per minute.
  - Per-run phase constraints to prevent impossible command ordering.
  - Cooldown on offline processing to prevent spam.
- Store an audit trail compactly: `actionId`, `type`, `argsHash`, `preVersion`, `postVersion`, `serverTime`, `resultHash`. This is enough to debug suspicious runs without storing huge tick logs.
