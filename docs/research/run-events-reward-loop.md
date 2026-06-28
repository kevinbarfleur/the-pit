# Run Events Reward Loop

Date: 2026-06-28

Status: active experimental spec. The first code increment is in the deterministic
run/lab layer, not yet the final live UI.

## Intent

The recurring post-combat relic shop is useful, but too direct: every third
combat currently reads like a mechanical vending machine. Run events should add
texture to the descent without hiding the outcome from the player.

Target shape:

1. The player reaches a scheduled acquisition window.
2. A grim event is presented: carcass, drowned market, sealed brood, fossil
   gate, wounded creature, etc.
3. The prose is cryptic, but each choice clearly displays the concrete reward.
4. The reward changes the run through relics, units, economy tempo, or later a
   carefully modeled monster mutation.

This is inspired by choose-your-own-adventure events, but with The Pit's
readability rule: atmosphere is allowed in the setup, not in the result line.

## Current Implementation

Implemented files:

- `src/data/run_events.lua`
- `src/run/state.lua`
- `src/lab/rundriver.lua`
- `tests/run.lua`
- `tests/lab.lua`

Current active events: 8 max.

Current reward kinds:

- `relic`: materialized through the normal gated relic pool, optionally with a
  `minTier` floor for stronger ceremonies.
- `unit`: a concrete monster id and level. Event units can be level 1 or rare
  level 2, never level 3.
- `gold`: direct run gold.
- `shop_xp`: direct shop XP.
- `shop_tier_up`: direct shop tier bump.

The lab treats the normal victory milestones at wins 3 and 6 as relic
ceremonies. By default it still keeps the ordinary every-3-combats merchant as a
relic offer so historical balance reports remain comparable. With
`Rundriver.new(seed, { runEvents = true })`, or scenario env
`PIT_RUN_EVENTS=1`, that merchant window becomes a run event. This is
intentional: milestones were already a structured payoff, while the merchant was
the flatter part of the loop.

## Simulation Contract

Run events are deterministic:

- event selection uses the seeded `RunState` RNG;
- materialized relics and units use the same seeded RNG;
- seen events are avoided until the eligible pool is exhausted;
- no render, audio, wall-clock, or global randomness enters the model.

The opt-in lab event path returns `runEvent` from `Rundriver:fight()`, then a
policy can call `pickRunEvent(index)`. If no policy implements event scoring,
default is choice 1.

Metrics added:

- `eventPicks`
- `eventRelics`
- `eventUnits`
- `eventGold`
- `eventShopXp`
- `eventShopTierUps`

These should be correlated with:

- run completion;
- target-board completion;
- TTK / combat duration;
- economy pressure;
- bossrush entry and score.

## Mutation Decision

Do not implement monster mutations as a quick stat table on the side.

A mutation like "this unit has multicast" or "+damage" sounds simple, but it
touches every persistent unit boundary:

- build board and bench instances;
- drag/drop and merge behavior;
- combat spec baking;
- snapshots/replays;
- grimoire/card display;
- tooltip keyword explanations;
- lab copy tracking.

The safe version is a first-class instance modifier:

```text
unit instance = id + level + copyId + mutations[]
```

Merges need a rule before this goes live. Recommended first rule:

- if one of the three consumed copies has a mutation, the promoted copy keeps
  one mutation;
- if several mutations are present, deterministic priority decides which one
  survives;
- level 3 should not stack three event mutations by accident.

Mutation examples worth testing later:

- `echo_touched`: +1 multicast, rare, capped by existing multicast max.
- `blood_fed`: increased damage.
- `iron_buried`: damage reduction or HP.
- `quickened`: haste.

This is promising, but it is phase 2. The current phase deliberately ships
events without active mutations.

## Product Guardrails

- Keep event count small. Eight is enough for the first balancing loop.
- Do not make events mandatory high-roll gates. They should diversify run paths,
  not replace the core shop.
- Do not offer level-3 monsters.
- Do not hide negative outcomes behind cryptic copy.
- Do not add long event chains before the base event reward EV is measured.
- Keep bossrush separate: bossrush is the post-win scoring payoff; events are
  mid-run texture and reward routing.

## Next Steps

1. Run paired economy/bossrush panels with `PIT_RUN_EVENTS=1`, then compare
   against the last relic-merchant baseline.
2. Add policy scoring for event choices instead of defaulting to option 1.
3. Build the live UI only after the reward EV is acceptable in the lab.
4. If the lab shows unit rewards are healthy, design the first-class mutation
   instance model and run it behind an opt-in profile.
