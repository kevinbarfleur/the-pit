# A4. Offline Progression Caps and Rates - P0

## Sources
- Melvor Idle Wiki, Offline Progression: https://wiki.melvoridle.com/w/Offline_Progression
- Chrome for Developers, Timer throttling in Chrome 88: https://developer.chrome.com/blog/timer-throttling-in-chrome-88/
- MDN, Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- MDN, visibilitychange event: https://developer.mozilla.org/en-US/docs/Web/API/Document/visibilitychange_event

## Findings
- Melvor Idle's current official wiki states that offline progression runs as if the player had stayed online, up to a maximum of 24 hours. That is a strong benchmark for a mostly-passive idle game, but it conflicts with The Pit's intended structure where Delve is the main progression driver.
- Browser timers are not reliable for background progress. Chrome can aggressively throttle chained timers for hidden pages after enough time hidden, and mobile browsers may freeze or discard pages. Web Workers can help isolate work from rendering, but they should not be treated as a reliable offline simulation engine.
- Offline progression should be computed from timestamps and server state, not from missed client ticks. The authoritative calculation is: `min(serverNow - lastProcessedAt, offlineCap) * offlineRate`, then apply content-specific rules.
- If offline progress gives full card drops, depth, or boss clears, it will erode the active-play premise. The correct offline fantasy is: the pit kept whispering, minions scavenged, furnaces cooled, logs accumulated. It should make returning pleasant, not replace playing.
- The welcome-back screen has two jobs: explain what changed and re-prime the next active action. A modal is useful for totals; a diegetic log is useful for atmosphere and continuity. Use both, but make the modal dismissible fast.

## Recommendation for The Pit
- Ship with:
  - Offline cap: 8 hours.
  - Economy rate: 25% of active baseline gold/scrap.
  - Card progression: common shards only, no first-copy rare/T0 drops.
  - Depth progression: none.
  - Boss progression: none.
  - Death risk: none offline; offline cannot enter combat nodes.
- Add upgrades later:
  - `Bedroll`: cap 8h -> 12h.
  - `Signal Lantern`: cap 12h -> 16h.
  - `Scavenger Contract`: common shard rate +10% relative.
- Welcome-back UI:
  - Modal title: `The Pit settled while you were gone.`
  - Show: time counted, cap hit or not, resources, shards, notable logs.
  - CTA: `Descend` and `Review Log`.
  - Also write the same events into the terminal log so the modal is not the only record.
- Server algorithm:
  - On load/resume, call `processOfflineGains`.
  - Use server `lastProcessedAt`, not client clock, for rewards.
  - Return `OfflineSummary` for UI display.
  - Persist `lastProcessedAt = serverNow` after successful processing.
