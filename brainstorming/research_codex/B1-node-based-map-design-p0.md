# B1. Node-Based Map Design - P0

## Sources
- Path of Exile, Delve expansion page: https://www.pathofexile.com/delve
- Path of Exile Wiki, Delve: https://www.poewiki.net/wiki/Delve
- Slay the Spire Wiki, Map locations: https://slay-the-spire.fandom.com/wiki/Map_locations
- Hades Wiki, Chambers and Encounters: https://hades.fandom.com/wiki/Chambers_and_Encounters
- Hades 2 door/reward reference: https://hades-2.game-vault.net/wiki/Doors

## Findings
- Slay the Spire's value is pre-commitment planning. The player sees a branching map, evaluates elites/rest/shop/event density, and commits to a path. This makes route choice a strategic layer independent of combat execution.
- Hades' value is immediate reward legibility. The player chooses doors based on visible reward symbols, creating short-cycle decisions. The Pit should borrow this because active idle play needs frequent decisions without overwhelming map planning.
- Path of Exile Delve's value is resource-mediated depth. Voltaxic Sulphite acts as a fuel that prevents infinite free pushing and makes the choice to go deeper feel like a spend. The crawler/darkness setup also gives a clean fiction for node traversal.
- A branching factor of 2-3 is enough for MVP. Four exits increases planning overhead and UI density without adding much early value. Use four only for special hub nodes, major forks, or event rooms.
- Node ratios should change by depth bracket. Early depths need teaching and reliable combat. Mid depths need elite temptation. Late depths need more risk nodes and route specialization.

## Recommendation for The Pit
- V1 node archetypes:
  - `combat`: baseline fight, common materials, small card chance.
  - `elite`: harder fight, higher T2/T1 odds, pity group increments.
  - `boss`: fixed milestone fight every 10 depths or section end.
  - `cache`: loot-only, consumes torch or requires key.
  - `event`: text choice with risk/reward.
  - `shop`: spend gold/shards; no combat.
  - `rest`: heal, repair, remove curse, or swap card safely.
  - `trap`: optional P1 but cheap to implement as an event subtype.
- Map structure:
  - A section is 7 rows: entrance, 5 choice rows, boss/exit.
  - Each row has 2-3 nodes.
  - Avoid path crossings unless visually clear.
  - The same row should rarely offer three identical node types.
- Suggested ratios:
  - Depth 1-10: combat 55%, cache 15%, event 15%, shop/rest 10%, elite 5%, boss fixed.
  - Depth 11-30: combat 45%, elite 15%, event 15%, cache 10%, shop/rest 10%, trap 5%, boss fixed.
  - Depth 31+: combat 38%, elite 20%, event 15%, trap 10%, cache 8%, shop/rest 9%, boss fixed.
- Always show: node type, primary reward, danger rating, torch cost, and whether it advances a pity/quest counter.
- Add `torch` cost to deeper or optional high-value routes. Basic shallow combat can be free or cheap; deep branches should cost fuel.
