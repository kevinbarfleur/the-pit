# G1. Game Loop Architecture - P0

## Sources
- Gaffer On Games, Fix Your Timestep: https://www.gafferongames.com/post/fix_your_timestep/
- Chrome for Developers, Timer throttling in Chrome 88: https://developer.chrome.com/blog/timer-throttling-in-chrome-88/
- MDN, Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- Chrome for Developers, Page Lifecycle API: https://developer.chrome.com/docs/web-platform/page-lifecycle-api
- Unity Netcode for Entities, client prediction: https://docs.unity3d.com/Packages/com.unity.netcode%401.3/manual/intro-to-prediction.html

## Findings
- Fixed timestep is the correct simulation model. Variable timestep is easier initially but makes combat, cooldowns, damage-over-time, and deterministic replay harder. The Gaffer principle applies even though The Pit is not physics-heavy: simulations are only reliable within expected delta bounds.
- Rendering and simulation should be decoupled. React/Pixi can render at requestAnimationFrame, while combat/economy state advances at a fixed tick. Visual interpolation can be smooth without changing authoritative state.
- Browser background execution cannot be trusted. Chrome throttles timers in hidden tabs, and lifecycle APIs make it clear that pages can be frozen or discarded. Therefore, the live game loop is for visible play only; offline progress is a separate timestamp-based server calculation.
- For an auto-battler/idle hybrid, 10Hz is likely unnecessary for the authoritative simulation. It increases CPU, replay log size, and reconciliation cost. A 4Hz or 5Hz tick is enough for cooldowns, attacks, poison, shields, and enemy intents if animations fill the gaps.
- Determinism should be designed around integer ticks and integer/fixed-point values. Avoid relying on floating-point accumulation for durable outcomes. Use millisecond timestamps only at boundaries, not as the core state delta.

## Recommendation for The Pit
- Use a 4Hz deterministic simulation tick: one tick every 250ms.
- Render at requestAnimationFrame with interpolation and queued visual events.
- Define loop layers:
  - `simulation`: deterministic, pure, shared by server/client where possible.
  - `prediction`: client-side local projection between server snapshots.
  - `presentation`: Pixi/React animation, damage numbers, sound, screen shake.
  - `persistence`: Convex snapshot and action log.
- Do not run Convex mutations every tick. Run mutations on durable actions:
  - start node
  - choose reward
  - equip/swap card
  - retreat
  - finish combat
  - process offline gains
- Combat can be resolved as a deterministic chunk server-side. The client may animate the same result progressively.
- Use `maxCatchupTicksPerFrame` on client, e.g. 8, to prevent spiral-of-death behavior after frame stalls.
- Store in snapshot:
  - `tick`
  - `stateVersion`
  - `rngState`
  - player stats
  - enemy stats
  - cooldowns/status durations in ticks
  - active node/run identifiers
- Avoid Web Worker as an offline guarantee. It can be used for visible-client simulation performance later, but the authoritative answer after absence comes from server simulation.
