# PvE Bossrush And Scoring Loop

Date: 2026-06-27

Status: active product/design spec. This document promotes the bossrush lab
prototype into a future gameplay loop. The historical balance details remain in
`intensive-simulation-balance-program-HANDOFF.md`.

## Purpose

The Pit should not end the moment a build finally becomes satisfying.

The core async PvP loop remains the backbone, but PvE abominations add two
important surfaces:

- **run texture**: occasional thematic PvE events during the normal run;
- **post-win payoff**: after a successful run, the player can push the build
  into boss scoring instead of immediately stopping.

The target feeling is: "my build is online, now let me see how deep it bites."

## Current Prototype

Implemented lab pieces:

- visual source: `docs/generation/generateur-abominations.html`;
- boss data: `src/data/abominations.lua`;
- deterministic runner: `src/lab/bossrush.lua`;
- scenario mode: `tools/sim.lua bossrush`;
- run-connected scenario mode: `tools/sim.lua bossrush_run`;
- report: `report-bossrush.json` with `by_comp`, `by_boss`, `matrix`,
  samples, and `recommendations`.

Fight shape:

1. The abomination side has one huge boss and three generals.
2. Generals occupy the front and block normal deterministic targeting.
3. Summoned adds also block scoring.
4. When every non-boss right-side unit is dead, the scoring window starts.
5. During the scoring window, the lab counts damage to the boss.

This uses the normal arena and normal effects. No render/audio/wall-clock state
participates in the lab.

There are now two complementary lab views:

- `bossrush`: forces curated catalogue/band compositions against abominations.
  Use it to test boss family readability and raw scoring identity.
- `bossrush_run`: first simulates actual policy/economy runs, then sends
  eligible final boards into abominations with the acquired relics and placed
  commander. Use it to answer whether a scoring build is actually reachable.

The second view is the safer source for product tuning because it keeps failed
or ineligible runs as zero-score outcomes through `score_damage_per_run`.

## Product Loop

### Mid-Run PvE Events

Use abominations as scheduled run texture, not constant interruptions.

Recommended first cadence:

- one minor PvE event after the player has a real board shape, around the early
  middle of the run;
- one stronger PvE event near the late transition;
- no PvE event before the player understands shop, merge, and positioning.

Event outcome should not be "win or lose the run" at first. It should be a
reward fork:

- clear cleanly: choose a strong reward;
- clear barely: choose a modest reward;
- fail: take chip damage or lose reward quality, but do not instantly end the
  run unless this is a deliberate boss gate.

Good reward candidates:

- one-of-three relic offer;
- one-of-three temporary boon for the next PvP round;
- heal one life or protect one future life loss;
- gold burst;
- shop manipulation: freeze, discounted rerolls, targeted shop family.

Avoid making PvE rewards mandatory for all winning runs. They should add route
texture and build identity, not become the only optimal economy line.

### Post-Win Boss Chain

After the player wins the normal run, offer a descent choice:

- **Claim Victory**: end the run and record the win.
- **Descend Further**: enter bossrush with the same build.

Bossrush can then loop:

1. Choose or reveal the next abomination.
2. Fight generals.
3. Score damage on the boss for a fixed window.
4. Record score and award depth.
5. Offer to continue to the next boss/depth or retire.

The boss itself does not need to die in v1. The scoring fantasy is stronger if
the boss is a huge target that measures the build. Later bosses can become
killable thresholds if the chain needs clearer milestones.

## Scoring

Initial score should be easy to understand:

```text
score = boss damage during scoring window
```

Secondary metrics should be shown but not dominate:

- time to clear generals;
- survival through full scoring window;
- damage by cause;
- MVP unit;
- afflictions applied;
- boss family reached;
- chain depth.

Do not start with a complicated score formula. Players need to understand that
"bigger number = my build hit harder". If we add bonuses later, they should be
visible as separate additive lines after the core count-up:

- `+ Clear Bonus`
- `+ Full Window Bonus`
- `+ Depth Bonus`

## Boss Families

Each boss should test one or two dimensions clearly.

Current catalogue direction:

- `leviathan`: poison/rot attrition and lifesteal body.
- `regard`: vulnerability and shock marks.
- `ossuaire`: thorns, shield, defensive attrition.
- `kraken`: slow, shock arcs, control pressure.
- `idole`: shield/invulnerability opening.
- `ruche`: summons, swarm, poison pressure.
- `brasier`: burn and propagation pressure.
- `floraison`: poison/rot hybrid.
- `devoreur`: execute and percent-HP threat.
- `vermine`: anti-tank max-HP pressure.

Guardrail: bossrush must not collapse into "play the one best affliction".
Reports should keep warning when one archetype scores far above the rest.

Needed future counters:

- poison ramp / anti-stack / cleanse boss;
- shield stripping boss;
- burst-window boss;
- cleave/spread boss;
- sustain-check boss;
- anti-tank boss;
- anti-summon or anti-wide-board boss.

## Feel And Presentation

The scoring phase should be treated as a product moment, not a plain combat log.

Presentation rule:

- SIM stays pure and deterministic.
- Presentation listens to events and displays score, sound, shake, and boss
  reactions.

Recommended live flow:

1. **General clear**: each general death produces a heavy cue, small freeze,
   and a visible "seal broken" reaction on the boss.
2. **Scoring opens**: boss shifts pose, top score meter appears, sound bed rises.
3. **Damage ladder**: damage-to-boss events feed a count-up meter, with pitch
   rising on grouped bursts.
4. **Milestones**: score thresholds trigger larger boss reactions, screen trauma,
   short hitstop, and a visible tier mark.
5. **Window close**: count-up settles, final score stamps into the run record.

Reuse existing systems first:

- `src/render/arena_draw.lua` already has damage numbers, hit flashes, death
  bursts, throttled combat SFX, and local shake.
- `src/ui/juice.lua` already has trauma shake, hitstop, scale/nudge/tilt.
- `src/audio/sfx.lua` already has success/defeat/thud/drop and ladder sounds.

Do not create a second unrelated feel stack. Add a score director that listens
to boss damage and drives these existing systems.

## Simulation Requirements

Bossrush reports should stay deterministic and machine-readable.

Required report dimensions:

- clear rate;
- survival rate;
- full scoring-window rate;
- post-win entry rate when using run-built boards;
- score damage;
- score damage per run when using run-built boards;
- score damage per bossrush entry when using run-built boards;
- score DPS;
- boss kill rate if killable bosses are added;
- damage by cause;
- recommendations/warnings.

Current warning examples:

- `dominant_scoring_archetype`: one comp is too far ahead in score.
- `dominant_run_bossrush_line`: one policy/economy line dominates score after
  access is included.
- `low_postgame_entry_rate`: too few real runs reach the bossrush gate.
- `hard_wall_boss`: boss blocks too many runs before score.
- `post_clear_attrition_boss`: teams can clear generals but die before a full
  score window.

## Implementation Sequence

1. Keep iterating the lab until boss families are readable and not dominated by
   one archetype.
2. Keep pairing catalogue bossrush with `bossrush_run`, so boss tuning does not
   ignore economy, relic access, commandants, level-ups, and policy reachability.
3. Add a product-facing bossrush spec scene only after the lab metrics are
   stable enough to justify the flow.
4. Add score director in presentation layer:
   event aggregation, count-up, milestone pulses, audio ladder, boss reactions.
5. Add one mid-run PvE event with modest rewards.
6. Add post-win "Descend Further" choice.
7. Add saved score records and seeds.
8. Add leaderboard/daily/weekly variants only after deterministic score records
   are stable.

## Current Open Warnings

- `poison_diamant_perfect` is currently the best bossrush scorer by a large
  margin.
- `cross_venom_pyre` is strong and healthy, but may become the second half of a
  narrow poison/cross endgame meta.
- Tank and shield boards survive more than they score; this can be good if
  bossrush is meant to reward output, but bad if defensive builds need a PvE
  scoring identity.
- Brute bruiser has no bossrush identity yet.
- In the first tiny run-connected panel, `early_curve` broad plans entered
  bossrush more often and therefore dominated `score_damage_per_run`; `sap_cost`
  produced no postgame entries in that sample. Treat this as an access warning,
  not a final economy verdict.
- A later rank-2 level-up smoke
  `runs/long-2026-06-27s/rank2-levelup-bossrush-run-n6` kept the same lesson:
  `early_curve` broad plans topped score/run because they entered more often,
  while overall postgame entry stayed low (`13.9%`). Boss tuning should stay
  paired with economy/policy reachability until entry rates are stable.
- The expanded N=18 panel
  `runs/long-2026-06-27t/bossrush-run-rank2-n18` had `100%` boss clear and
  `99.4%` survival but only `12.5%` postgame entry. `pair_completion_light`
  improved score/run through stronger final boards, while baseline entered
  slightly more often. Current read: the boss side is readable enough for lab
  iteration; the product blocker is still run access and final-board quality.
- The generated-opponent panel
  `runs/long-2026-06-28b/bossrush-run-n10` compared `baseline`,
  `pair_completion_light`, and `sap_cost_pair_completion` after the level-up
  roster pass, with events enabled and `PIT_OPPGEN_LEVEL_MULT=2`. Overall
  postgame entry rose to `59.3%`, boss clear was `100%`, survival was `99.2%`,
  and full score-window survival was `87.1%`. The top score/run line was
  `pair_completion_light + committed_rot_bleed_rat_core_deep_reroll_plan`
  (`24,235.9` score/run, `90%` entry). `sap_cost_pair_completion` had a cleaner
  `100%` entry on the same policy but slightly lower score/run (`22,442.2`).
  Current read: bossrush is now useful as a scoring lab, but current
  abomination generals are not a gating problem once a run enters; the next PVE
  tuning pass should make boss families differentiate score/survival more
  sharply instead of only measuring access to postgame.
- In that same panel, every boss had `100%` general clear. `ossuaire` and
  `vermine` had `0%` boss kill rate while `brasier` and `ruche` reached about
  `20%`. This is a useful split if kill rate becomes a secondary metric, but
  the scoring fantasy should still be damage-count first.
- Quick pressure sweep after that panel:
  `bossrush-run-hp15-n6` and `bossrush-run-hp2-n6` kept `100%` clear, so HP
  alone mostly increases available score instead of making the generals gate
  the run. `bossrush-run-hp2-cd05-n6` is the first useful stress point:
  overall clear `97.6%`, survival `89.1%`, full score-window `62.0%`, boss kill
  `27.0%`. Boss split becomes more interesting: `ossuaire` drops to `64.8%`
  survival and `53.7%` full window, while `brasier`, `kraken`, and `ruche`
  reach about `40%` boss kill. Current read: cadence/threat pressure is a
  better next tuning knob than raw HP if the goal is to make boss families
  distinct without turning the scoring target into a health sponge.
