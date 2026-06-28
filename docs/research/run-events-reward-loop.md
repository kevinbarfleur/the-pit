# Run Events Reward Loop

Date: 2026-06-28

Status: active gameplay increment. The deterministic run/lab layer exists, and
the live every-3-combats merchant window now routes through a run-event surface
with explicit rewards. Mutation lanes remain lab-only.

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
- `src/run/event_rewards.lua`
- `src/scenes/relicpick.lua`
- `main.lua`
- `src/lab/rundriver.lua`
- `src/core/export_scenes.lua`
- `tests/run.lua`
- `tests/lab.lua`

Current active events: 8 max.

Current reward kinds:

- `relic`: materialized through the normal gated relic pool, optionally with a
  `minTier` floor for stronger ceremonies.
- `unit`: a concrete monster id and level. Event units can be level 1 or rare
  level 2, never level 3.
- `mutation`: lab opt-in only. Materialized only when the driver can attach the
  mutation to an exact existing copy target.
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

Live routing now differs from the lab default: the normal post-combat
every-3-combats acquisition window first tries to materialize a run event. If no
event can expose at least one clean choice, it falls back to the old relic
offer. Victory milestones at wins 3 and 6 and level-up rewards remain pure
relic ceremonies for now.

Live reward application rules:

- relics are granted and learned by the Grimoire as before;
- units are only offered when the current board or bench can receive them
  cleanly, then they are stowed and normal merge logic runs;
- gold is deferred through `_pendingGold` so the SAP-style next-round gold reset
  does not erase the event reward;
- shop XP and shop tier are applied before the next shop roll;
- mutation choices are not materialized live because no `mutationTarget` is
  passed to `RunState:rollRunEvent`.

Simulation alignment:

- `PIT_EVENT_UNIT_TARGETING=space` applies the same board/bench capacity filter
  used by the live event surface.
- `policy_space` combines policy scoring with the live capacity filter.
- `policy_space_missing_copy` combines policy scoring, live capacity, and the
  copy-chain filter used to test missing-copy unit rewards.
- The default lab event path remains unchanged for historical comparisons; use
  one of the `space` modes when a panel is meant to mirror live product rules.

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

Unit reward diagnostics added after the first pressure read:

- `event_unit_single_rate`
- `event_unit_pair_rate`
- `event_unit_merge_rate`
- `event_unit_progress_rate`
- `event_unit_bench_rate`
- `event_unit_board_rate`

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

More precise event-unit diagnostics (`N=64`, `pair_completion_light`,
`rot_bleed_rat_core`, gated + deep-reroll policies, `PIT_RUN_EVENTS=1`) confirm
that the pressure is not hard overflow:

- completion `32.8%`, average wins `8.94`;
- event picks `2.88/run`;
- event unit rewards `0.71/run`;
- event unit failure rate `0.0%`;
- only `12.1%` of granted event units immediately complete a pair or merge
  (`6.6%` pair, `5.5%` merge);
- `87.9%` are singles, `94.5%` land on the bench, and `5.5%` go directly to the
  board.

Interpretation: current unit lanes are safe but often read as loose extra
inventory rather than sharp build progression. Do not simply raise unit-lane
frequency. The next healthier levers are target-filtered unit rewards,
event-specific level-2 rarity, or later mutation rewards once unit instances are
first-class.

Target-filter experiment (`PIT_EVENT_UNIT_TARGETING=policy`, same `N=64` panel)
raises unit reward quality but also exposes a relic-cannibalization risk:

- generic unit materialization: completion `32.8%`, wins `8.94`, event relics
  `2.10/run`, event units `0.71/run`, event unit progress `12.1%`;
- policy-targeted unit materialization: completion `31.3%`, wins `8.95`, event
  relics `1.57/run`, event units `1.20/run`, event unit progress `57.5%`;
- held target level coverage improved `73.1% -> 75.7%`, and held-complete rose
  from `0.0%` to `1.6%`, but run completion did not improve in this slice.

Interpretation: target-filtering is the right direction for unit lanes, but it
cannot be a naive "make units more tempting" switch. The next test should keep
the relic-lane density floor while targeting only the unit reward itself, or
cap how often a policy can prefer a unit over a relic.

Capped unit-pick experiment adds `PIT_EVENT_UNIT_PICK_CAP` as a lab-only policy
guard:

- cap 1 preserved relic density (`2.05` relics/run vs `2.10` generic) and kept
  unit quality high (`50.0%` pair-or-merge progress), but completion stayed at
  `31.3%`;
- cap 0, effectively "events choose no unit lanes", produced the best run slice:
  completion `33.6%`, wins `8.97`, event relics `2.74/run`, event units `0`.

Interpretation: for `rot_bleed_rat_core` under `pair_completion_light`, plain
event units are not yet worth the relic opportunity cost. The reward fantasy is
still good, but the unit lane probably needs a special reason to exist:
target-filtering plus a rare level-2 spike, future mutation, or a constrained
"missing copy" rule that does not compete with the main relic lane every time.

Missing-copy unit materialization (`PIT_EVENT_UNIT_TARGETING=policy_missing_copy`,
same `N=64` panel) proves that unit lanes can be made much cleaner, but still
does not solve the opportunity-cost problem:

- completion `31.2%`, wins `8.96`;
- event relics `1.76/run`, event units `1.02/run`;
- event unit progress `100%`: no singles, `65.6%` pair completions and `34.4%`
  merge completions;
- failure stayed `0.0%`, but `96.2%` of event units still landed on the bench.

Interpretation: "only offer units that complete a copy chain" is the right
quality floor, but it is not enough while those unit lanes replace too many
relic choices. Keep it as a lab switch, not a live default. A live unit event
probably needs to be one of: explicitly level-2, explicitly mutation-bearing,
or rare enough that it reads as a special event spike instead of a relic
substitute.

Live-capacity alignment panel (`N=64`, `pair_completion_light`,
`rot_bleed_rat_core`, gated + deep-reroll policies) tested the new
`PIT_EVENT_UNIT_TARGETING=space` family so simulation can mirror the product
rule that event units are only offered when board or bench space exists:

- `policy_space`: completion `31.2%`, wins `8.95`, event relics `1.57/run`,
  event units `1.20/run`, unit progress `57.5%`, failures `0`;
- `policy_space_missing_copy`: completion `31.2%`, wins `8.96`, event relics
  `1.76/run`, event units `1.02/run`, unit progress `100%`, failures `0`;
- the stricter missing-copy profile removed singles entirely (`65.6%` pair
  completions, `34.4%` merge completions), but exact plan completion did not
  improve in this slice.

Interpretation: the live capacity filter is now mechanically aligned and safe.
It prevents impossible rewards, but it does not make units free from an EV
perspective. `policy_space_missing_copy` is the cleanest unit-quality rule so
far, yet it still cannibalizes too much relic density for exact reroll plans.
Default live events should therefore keep unit offers rare and special:
level-2 spike, missing-copy rescue, future mutation-bearing monster, or another
non-relic lane that does not crowd out build-defining relic access every time.

Relic-margin experiment adds a lab-only policy guard,
`PIT_EVENT_UNIT_RELIC_MARGIN`, so a policy can still see unit choices but only
pick one over an offered relic if the unit clears an explicit value margin.
This does not remove non-relic lanes from the event surface; it tests whether
"special unit" should mean "worth skipping a relic."

Latest `N=64` panels on the same `pair_completion_light` / `rot_bleed_rat_core`
slice:

- `policy_space` without margin: `1.57` relics/run, `1.20` units/run, focused
  relic pick `57.0%`;
- `policy_space + margin500`: only a mild shift, `1.60` relics/run and `1.16`
  units/run;
- `policy_space + margin1000`: stronger relic recovery, `1.84` relics/run and
  `0.92` units/run, focused relic pick `67.9%`;
- `policy_space_missing_copy + margin1000`: best current reward contract,
  `2.06` relics/run, `0.71` units/run, `100%` unit progress, focused relic
  offer/pick both `69.5%`.

Completion stayed `31.2%` across those slices, so this is not a full balance
fix. It is still a better event-policy constraint: preserve clean unit spikes
while avoiding the constant "unit over relic" drift that makes exact reroll
plans lose build-defining support.

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

Pacing check (`N=64`, `rot_bleed_rat_core`, gated and deep-reroll policies)
shows the event layer does not materially disturb combat duration:

- classic merchant baseline at live pacing: `27.3%` completion, `8.83` wins,
  fit `0.988`, early average `13.40s`, p50 `10.75s`, p90 `17.05s`, fatigue
  `0.3%`;
- run events at live pacing: `26.6%` completion, `8.78` wins, fit `0.988`,
  early average `13.40s`, p50 `10.77s`, p90 `17.40s`, fatigue `0.5%`;
- the policy split matters more than the event toggle: deep-reroll wins and
  completes much more often, but its early fights sit around `12.27s`, while
  the gated plan is cleaner on duration and much weaker on completion.

Interpretation: run events are not a pacing problem. Their current tuning
problem is acquisition texture: relic density, target-unit usefulness, and
whether exact reroll plans lose too much best-of-3 relic access.

## Mutation Decision

Do not implement monster mutations as a quick stat table on the side. The safe
foundation now exists as a first-class instance modifier, but it is not active
as a live event reward yet.

A mutation like "this unit has multicast" or "+damage" sounds simple, but it
touches every persistent unit boundary:

- build board and bench instances;
- drag/drop and merge behavior;
- combat spec baking;
- snapshots/replays;
- grimoire/card display;
- tooltip keyword explanations;
- lab copy tracking.

Implemented foundation:

```text
unit instance = id + level + copyId + mutations[]
```

Current code coverage:

- `src/run/mutations.lua` defines stable mutation ids and combat-spec bake
  rules;
- build board/bench/commander instances preserve `mutations[]` through
  drag/drop, stow, and merge;
- snapshots encode/decode mutations backward-compatibly;
- lab unit rewards can already carry a mutation in copy state.
- `PIT_RUN_EVENT_MUTATIONS=1` enables mutation lanes in economy reports without
  activating them by default.

Current merge rule:

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

This is promising, but live event activation is still phase 2. Before adding a
mutation lane to the 8 active events, the lab must test targeting, reward EV,
card/tooltip display, and policy valuation so it does not become another relic
opportunity-cost trap.

First opt-in panel (`N=64`, `pair_completion_light`, `rot_bleed_rat_core`,
gated + deep-reroll policies) says exactly that:

- uncapped mutation preference: completion `31.2%`, wins `8.91`, event relics
  `1.35/run`, event units `0.52/run`, mutations `1.02/run`;
- `PIT_EVENT_MUTATION_PICK_CAP=1`: completion still `31.2%`, wins `8.91`,
  event relics `1.64/run`, event units `0.58/run`, mutations `0.66/run`;
- no mutation failure occurred, so the system plumbing is safe. The issue is
  reward opportunity cost, not application failure.

Current read: mutation lanes are mechanically viable and flavorful, but too
tempting for exact reroll plans unless they are rarer, lower-valued by policy,
or attached to special events that do not replace the main build-defining relic
lane.

## Event Product Step

The first product pass replaces the flat recurring relic merchant with small
cryptic scenes at the same acquisition cadence. This is a presentation change
and a reward-routing change, not a hidden-choice system:

1. The event setup can be grim and oblique.
2. Each choice must expose the concrete reward before selection.
3. Reward lanes may include relics, level-1 units, rare level-2 units, gold,
   shop XP, or shop tier.
4. Mutated units are a lab opt-in profile, not part of the first live pass.
5. Eight active events remain the cap until the EV and exact-board impact are
   measured at larger sample sizes.

The mutation fantasy is still valuable because it creates memorable rare
offers: a low-rank monster with `echo_touched`, a mid-rank monster with
`blood_fed`, etc. The safe roadmap is:

- first, ship events without mutations; done for the live /3-combats channel;
- second, implement persistent unit instances with `mutations[]`;
- third, add a lab-only event mutation profile;
- fourth, run merge, bench, UI, tooltip, snapshot, bossrush, and economy panels
  before enabling mutated event units in the live run loop.

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

1. Keep `PIT_RUN_EVENTS=1` in paired economy/bossrush panels while tuning the
   main balance loop.
2. Tune event reward EV now that policy choice is no longer option-1 biased.
3. Add policy diagnostics for "event unit was useful" vs "event unit caused
   churn" before changing reward weights.
4. Add target-filtering experiments for unit lanes before increasing their
   frequency.
5. Test a capped target-filter policy that preserves relic density before
   considering stronger live event-unit weighting.
6. Keep `policy_space_missing_copy` as the current quality floor for special
   unit events, but do not make it a broad replacement for relic choices.
7. Re-run the most important reward-EV panels with
   `PIT_OPPONENT_MODE=generated` before treating old late static-oracle losses
   as balance truth. First rot/bleed core comparison: static `31.2%` run
   completion vs generated `89.8%`, while exact target completion remains low;
   tune live EV from generated panels, keep static panels as stress tests.
   Use `PIT_OPPGEN_*` pressure knobs when generated opponents are too soft.
8. Use `--shoot=runevent` after visual changes to the event picker.
9. Continue mutation panels behind the opt-in lab profile before enabling
   mutated event units in the live run loop.
