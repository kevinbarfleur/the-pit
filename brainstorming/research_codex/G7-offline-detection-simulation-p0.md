# G7. Offline Detection and Simulation - P0

## Sources
- MDN, visibilitychange event: https://developer.mozilla.org/en-US/docs/Web/API/Document/visibilitychange_event
- MDN, Navigator.onLine: https://developer.mozilla.org/en-US/docs/Web/API/Navigator/onLine
- Chrome for Developers, Page Lifecycle API: https://developer.chrome.com/docs/web-platform/page-lifecycle-api
- Chrome for Developers, Timer throttling: https://developer.chrome.com/blog/timer-throttling-in-chrome-88/
- Convex Developer Hub, Actions: https://docs.convex.dev/functions/actions
- Convex Developer Hub, Scheduled Functions: https://docs.convex.dev/scheduling/scheduled-functions

## Findings
- `visibilitychange` is the most important browser event for persistence because the transition to hidden is often the last reliably observable lifecycle change. It fires when users switch tabs, navigate away, minimize, close, or switch apps on mobile.
- `navigator.onLine` is useful as a hint but not as proof. Browsers can report online while the actual service is unreachable, and network state can change between the check and the request. The authoritative signal is whether Convex calls succeed.
- Page lifecycle behavior means a tab may be frozen or discarded after it becomes hidden. Any design that expects JavaScript to keep ticking in the background will fail for some users.
- Offline simulation should be a server-side catch-up operation from the last canonical timestamp. It should not trust client clocks, client-reported elapsed time, or accumulated local ticks.
- Long offline gaps should be computed with closed-form formulas where possible. Simulating 8 hours at 4Hz is 115,200 ticks, which is manageable in optimized code but unnecessary for basic resource trickle. Combat/depth should not progress offline, so the offline model can stay simple.

## Recommendation for The Pit
- Client lifecycle behavior:
  - On `visibilitychange` -> hidden: flush any dirty local UI preferences and attempt a best-effort `savePresence` or lightweight snapshot marker.
  - On app mount, reconnect, and `visibilitychange` -> visible: call `processOfflineGains`.
  - On failed Convex call: mark UI as reconnecting and avoid issuing multiple offline claims.
- Server offline behavior:
  - Store `lastProcessedAt` on the save.
  - On `processOfflineGains`, compute `elapsed = serverNow - lastProcessedAt`.
  - Apply `effectiveElapsed = min(elapsed, offlineCap)`.
  - Apply rewards from server-owned formulas.
  - Set `lastProcessedAt = serverNow` in the same durable operation.
- Do not pass client elapsed time as reward authority. The client may pass a local timestamp only for analytics/debug display.
- Offline reward model:
  - Gold/scrap: closed-form `ratePerSecond * effectiveElapsed * offlineRate`.
  - Common shards: probabilistic or expected-value formula, capped and rounded server-side.
  - Events/logs: generated from elapsed buckets, not every tick.
  - No combat, no depth, no boss, no rare/T0 first drops.
- UI summary object:
  - `elapsedSeconds`
  - `cappedSeconds`
  - `capHit`
  - `goldGained`
  - `scrapGained`
  - `shardsGained`
  - `logLines`
  - `nextRecommendedAction`
- Add idempotency: if two tabs call `processOfflineGains`, only one should apply rewards. Use current `lastProcessedAt` and a save/version check.
