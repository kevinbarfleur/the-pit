# A3. Active vs Passive Balance - P0

## Sources
- Melvor Idle Wiki, Offline Progression: https://wiki.melvoridle.com/w/Offline_Progression
- Melvor Idle Wiki, Thieving: https://wiki.melvoridle.com/index.php?title=Thieving
- Hades Wiki, Chambers and Encounters: https://hades.fandom.com/wiki/Chambers_and_Encounters
- Loop Hero Wiki, Cards: https://loophero.fandom.com/wiki/Cards
- Machinations, How to design idle games: https://machinations.io/articles/idle-games-and-how-to-design-them

## Findings
- Active play is not the same as high APM. The relevant design target is meaningful choice density: route choices, reward choices, risk choices, build changes, and retreat timing. Spam-clicking is active physically but shallow strategically.
- Hades makes chamber choice legible before commitment by showing door rewards. Loop Hero keeps combat mostly automatic but gives the player strategic agency through card placement, deck composition, equipment swaps, and retreat. This is the useful template for The Pit: auto-resolve moment-to-moment combat, but keep the player involved through decisions around the fight.
- Melvor demonstrates the opposite end of the spectrum: passive skills can be satisfying when the system is legible and the player returns to a clear outcome. That supports offline flavor, but it does not fit the stated goal that Delve should represent 80%+ of progression.
- A good active delve loop needs a layered cadence. Micro-feedback should happen every 2-5 seconds: hits, blocks, loot ticks, log lines, enemy intent changes. Tactical choices should happen every 30-60 seconds. Strategic choices should happen every 3-8 minutes: change card loadout, spend scarce currency, retreat, boss preparation.
- Tension moments are more valuable than constant input. A player should sometimes wait because a telegraphed attack is about to resolve, a pity counter is close, an elite branch is visible, or retreating now would sacrifice a streak.

## Recommendation for The Pit
- Set the active decision-density target at one meaningful choice every 45 seconds on average during a delve, with a hard maximum of 90 seconds in normal play.
- Active Delve should control 80-90% of durable progression: depth unlocks, rare/T0 cards, boss materials, leaderboard stats, and major upgrade currencies.
- Offline should control 10-20% of durable progression: gold trickle, low-tier materials, ambient logs, common card shards, and catch-up comfort. Offline should not advance depth, clear bosses, or grant first-time rare/T0 cards.
- Each active node should expose at least one of these choices:
  - Route: safe, rich, elite, event, shop, boss path.
  - Build: keep current 8-card loadout or swap a new drop.
  - Risk: spend torch, consume food, trigger cursed reward, retreat.
  - Targeting: pick enemy priority or stance before combat.
- Avoid active busywork. No repeated manual harvesting, no click-to-attack as the core mechanic, and no modal confirmations on every trivial reward.
- MVP loop: choose node -> pre-fight card/consumable decision -> auto-battle with enemy intents and damage numbers -> loot decision -> route decision. This gives agency without requiring a real-time action game.
