# G2. State Sync: Convex to Client - P0

## Sources
- Convex Developer Hub, Mutations: https://docs.convex.dev/functions/mutation-functions
- Convex Developer Hub, Actions: https://docs.convex.dev/functions/actions
- Convex Developer Hub, Optimistic Updates: https://docs.convex.dev/client/react/optimistic-updates
- Convex Developer Hub, Scheduled Functions: https://docs.convex.dev/scheduling/scheduled-functions
- Unity Netcode for Entities, prediction and server snapshots: https://docs.unity3d.com/Packages/com.unity.netcode%401.3/manual/intro-to-prediction.html

## Findings
- Convex mutations are the right place for durable game-state writes and validation. They accept arguments, check auth/business rules, write data, and return a result. Actions are better for external services or longer-running logic that interacts with the database indirectly.
- Convex optimistic updates are useful for responsiveness, but they are explicitly temporary local changes that are rolled back/reconciled after the server result. That maps well to UI feel, not to permanent reward authority.
- A game tick should not be a database mutation. Even 4Hz would create noisy cost and complexity if every player writes continuously. Durable state should update at command boundaries and node boundaries.
- The likely pattern is: server stores canonical snapshot plus action log; client derives an ephemeral predicted state between snapshots. This is compatible with both idle progression and leaderboard verification.
- The client should never report earned gold, drops, or boss results as facts. It reports chosen actions. The server computes outcomes.

## Recommendation for The Pit
- Split state into three buckets:
  - Server canonical: user, save, run, depth, inventory, cards, gold, torch, RNG state, action log, leaderboard stats.
  - Client predicted: current combat projection, temporary cooldowns, pending optimistic purchase/equip state.
  - Client presentation: camera, hover, selected panel, animation queue, damage number pool, sound state.
- Command flow:
  1. Client reads canonical `runSnapshot` from Convex query.
  2. Client simulates locally for feel.
  3. Player sends command, e.g. `chooseNode({runId, stateVersion, nodeId, actionId})`.
  4. Server validates state version, auth, adjacency, resource cost, and run status.
  5. Server advances deterministic simulation/resolution.
  6. Server writes new snapshot and action log.
  7. Client reconciles predicted state to returned canonical state.
- Mutation cadence:
  - Node start/end and reward decisions: mutation.
  - OAuth/Twitch external calls: action or HTTP action.
  - Offline processing: mutation if pure DB logic; action if external work or heavy scheduled workflow is required.
- Use optimistic updates only for reversible UI actions:
  - button disabled state
  - visible resource decrement while pending
  - card equip preview
  - navigation feedback
- Add idempotency now:
  - Every client command includes `actionId`.
  - Server records processed action IDs for the run.
  - Duplicate action returns the existing result.
- Snapshot size should remain small. Store deterministic inputs and summary state, not every animation event.
