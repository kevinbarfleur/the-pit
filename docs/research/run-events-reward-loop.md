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
policy can call `pickRunEvent(index)`. Core lab policies now score event choices
instead of blindly taking the first option:

- plan policies value focused relic support through the same coherence graph as
  ordinary relic picks;
- plan policies value concrete target units, especially missing level coverage;
- generic policies use a simple deterministic tempo/power value for relics,
  level-2 units, gold, shop XP, and shop tier bumps;
- the random baseline still chooses a seeded random option.

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

Latest panel after relic-lane density tuning (`N=128`, `rot_bleed_rat_core`,
`pair_completion_light`, `PIT_RUN_EVENTS=1`):

- completion stayed mildly positive vs relic merchant baseline:
  `33.2%` with events vs `32.0%` baseline;
- event choices averaged `2.86` picks/run;
- event rewards shifted toward explicit plan/power rewards:
  `2.11` relics/run, `0.70` units/run, `0.41` gold/run;
- focused relic access improved:
  `70.3%` focused offer run-rate, `69.5%` focused pick run-rate;
- exact target-board completion is still worse than the classic relic merchant
  path: `0.4%` board complete / `0.8%` held complete with events vs `1.2%` /
  `2.0%` baseline.

Bossrush-run check (`N=32`, same policies/economy, completed runs only) shows
that the denser event relic lanes can now beat the baseline in postgame scoring:

- baseline score damage per run: `7261`;
- events score damage per run: `7846`;
- baseline score per entry: `24458`;
- events score per entry: `25107`.

Interpretation: every event should keep at least one relic lane and one
non-relic lane. That preserves the user-facing event fantasy while keeping
enough build-definer density for optimized plans. The remaining cost is exact
reroll-board completion: events are now healthy for run completion and PvE
scoring, but still slightly worse when the metric is "assemble this exact
target board."

Instrumentation added after that panel shows event units are not being lost to
hard inventory overflow in the tested rot/bleed policies: `event_unit_failure_rate`
is `0.0%` at `N=64`. The softer pressure is churn: about `2.0` board swaps/run,
`4.0` bench sells/run, and `20.5%` desired-offer slot limitation. Next tuning
should therefore focus less on "the reward cannot fit" and more on whether
event units should be core/target-filtered, auto-stowed with better priority,
or offered less often to exact reroll plans before implementing the live UI.

Cross-economy check (`N=64`, same rot/bleed policies, events vs classic
merchant) adds two cautions:

- completion is neutral or slightly positive with events across the tested
  profiles: `baseline 31.2% -> 31.2%`, `pair_completion_light 31.2% -> 32.8%`,
  `sap_cost 7.0% -> 7.0%`, `early_curve 13.3% -> 14.1%`;
- focused relic pick-rate is still lower with events because the classic
  merchant is a pure best-of-3 relic surface: baseline profile `82.0% -> 68.8%`,
  pair-completion `80.5% -> 67.2%`, sap-cost `82.0% -> 67.2%`,
  early-curve `84.4% -> 63.3%`.

Cross-economy bossrush-run (`N=16`, noisy but useful smoke) keeps
`pair_completion_light` as the strongest economy. Events are near-neutral on
deep-reroll postgame score for baseline/pair-completion, worse for
early-curve deep-reroll, but better for early-curve gated. Treat this as:
events are healthy enough to keep iterating, but they should be tuned per
economy/policy before becoming the only acquisition surface.

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
2. Tune event reward EV now that policy choice is no longer option-1 biased.
3. Build the live UI only after the reward EV is acceptable in the lab.
4. If the lab shows unit rewards are healthy, design the first-class mutation
   instance model and run it behind an opt-in profile.
