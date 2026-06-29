# Playtest V1 Finalization Roadmap

Date: 2026-06-28
Last updated: 2026-06-29
Latest checkpoint: 2026-06-29 17:41 CEST
Status: pivoting from micro-balance to playable vertical-slice completion; aura/influence sidecar now implemented across build and combat inspection, Proving Ground now includes murmur showcase cases, and live economy, contextual run-event unit rewards, run-event docs resynced with live/lab behavior, readable bossrush score surface, reward/event card art, export coverage, bossrush i18n/general-state fixes, pacing/economy diagnostics, early-short-fight attribution, plan-position diagnostics, plan-aware policy placement, Ossuaire boss tuning, broad visual export, post-combat event routing, and level-aware ability scaling are validated headless.

This note is the continuity document for the current large balance/simulation
workstream. Keep it updated whenever a meaningful decision, implementation, or
validation result lands, so another agent can resume without reloading the whole
conversation history.

## Target

Ship a small playable V1 that can be tested by a few friends:

- normal async autobattler run remains the backbone;
- economy has real early pressure;
- fights have readable duration and do not collapse into 2-second bursts;
- monster abilities and level-ups are diverse enough to create readable plans;
- run events replace the flat recurring relic merchant when possible;
- PvE abominations/bossrush are exploitable enough to test post-win scoring;
- mutations stay out of live unless a later pass proves a clean reward contract.

## Current Decisions

### Economy

Live economy should move away from the old baseline
`10 gold + shop size 5 + cost=rank + reroll=1`.

Final V1 candidate:

- profile: `sap_cost_pair_completion_tiered_reroll`;
- unit costs by rank: `{2, 3, 4, 5, 6}`;
- reroll cost by shop tier: `1/1/2/2/3`;
- pair-completion support: max 1 injected third copy per round, from round 2.

Why:

- baseline leaves too much leftover gold and too much full-shop affordability;
- SAP-like costs create pressure but need pair-completion support so merges
  remain satisfying;
- tiered reroll mostly reduces reroll spam/leftover without killing broad plans.

Latest finalization panel:

- command:
  `PIT_SCEN_OUT=runs/final-live-v1-2026-06-28/economy-n96 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion,sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 96`
- baseline: completion `21.7%`, avg wins `7.24`, full-shop afford `89.7%`,
  merge-per-pair `70.0%`, leftover `8.33`;
- `sap_cost_pair_completion`: completion `28.3%`, avg wins `7.34`,
  full-shop afford `59.9%`, merge-per-pair `91.2%`, leftover `5.36`;
- `sap_cost_pair_completion_tiered_reroll`: completion `27.4%`, avg wins
  `7.25`, full-shop afford `60.2%`, merge-per-pair `91.1%`, leftover `4.75`.

Latest autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/economy-targeted-n24 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 24`
- baseline on those useful policies: completion `61.1%`, avg wins `9.51`,
  full-shop afford `98.0%`, merge-per-pair `76.9%`, leftover `7.55`;
- live candidate on those useful policies: completion `79.2%`, avg wins `9.78`,
  full-shop afford `80.9%`, merge-per-pair `95.0%`, leftover `3.68`;
- interpretation: live economy is still the V1 candidate. It creates much more
  pressure than baseline while making merges more reliable through the explicit
  pair-completion support. No parameter change from this checkpoint.

Latest larger autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/economy-targeted-n96 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 96`
- baseline: completion `57.6%`, avg wins `9.47`, full-shop afford `97.5%`,
  merge-per-pair `76.4%`, leftover `8.63`, gold pressure `0.42`;
- live candidate: completion `76.4%`, avg wins `9.73`, full-shop afford
  `80.9%`, merge-per-pair `93.5%`, leftover `4.30`, gold pressure `0.72`;
- interpretation: the N=96 panel confirms the live candidate. It is less
  permissive than baseline, but pair-completion makes level-up pursuit much
  more reliable. No further economy parameter change for V1.

Important watchpoint:

- the useful-policy economy panel proves the live economy is better than
  baseline on pressure and merges, not that every intended archetype plan is
  actually realized. Some target-row/coherence rows still complete poorly in
  the lab. Do not claim "all builds are reachable"; use this as a manual
  playtest focus for the next balance pass.
- early full-shop affordability is reduced, but not eliminated. Treat
  `early_full_shop_afford_rate` as a tracked metric rather than a solved
  problem.
- the latest rat-core policy pass confirmed a distinction between "wins the run"
  and "realizes the exact target plan":
  - `committed_rot_bleed_rat_core_no_xp_plan` is the stronger run policy in the
    N=32 comparison (`40.6%` completion, `8.78` avg wins), but it is worse as a
    strict plan-access probe;
  - `committed_rot_bleed_rat_core_deep_reroll_plan` remains the better
    diagnostic policy for target accessibility, but still does not hit the
    strict 100% `rot_bleed_rat_core` target in N=32;
  - the bottleneck is not gold affordability. It is a mix of rank-3 access
    (`clot_mender`), low-rank duplicate saturation, and weak combat output once
    the partial plan reaches the 75-99% coverage band.
- do not loosen `target_rows` to make the reports look better. It is correctly
  strict. Use `avg_peak_held_level_coverage`, `first_held_level_round`, and
  acquisition funnels to interpret near-misses.
- latest strict post-scaling plan-realization panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/plan-realization-rot-bleed-rat-post-scaling-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan,committed_rot_bleed_rat_core_no_xp_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 32`
  - selected policies overall: completion `53.9%`, avg wins `9.14`,
    desired-buy-all `60.9%`, merge-per-pair `94.7%`, leftover `3.45`;
  - target `rot_bleed_rat_core`: strict held-complete `0%`, ever-held-complete
    `0%`, average peak held level coverage `45.6%`, final held level coverage
    `44.9%`;
  - key funnel read: low-rank pieces are available and bought often, but
    `clot_mender` is seen in only `34.4%` of runs and averages first seen
    around round `8.75`; several rank-2/3 support pieces sit around
    `54-59%` seen rate. Misses are mostly access/space/timing, not gold;
  - policy split: `greedy_plan` and `econ_plan` win more (`81.2%`/`78.1%`)
    but are not strict plan probes. The committed probes chase the target more
    aggressively and lose more (`37.5%` and `18.8%` completion), which is
    useful diagnostic pressure.
  - decision: keep this as a target-design/accessibility watchpoint. Do not
    retune global economy from this alone; either the target needs a less
    six-piece-complete definition, or the roster/reward system needs clearer
    mid-rank support access in a later pass.
- compact economy `target_rows` now expose realization thresholds so the report
  can show "how close" a plan got without weakening strict completion:
  `held_level_50/75/100_hit_rate`, average round for those thresholds, and
  board winrate in the `50-74`, `75-99`, and `100%` coverage bands.
- threshold rerun for the same `rot_bleed_rat_core` panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/plan-realization-rot-bleed-rat-thresholds-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan,committed_rot_bleed_rat_core_no_xp_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 32`
  - 50% held-level threshold hit rate `48.4%`, avg round `7.82`;
  - 75% held-level threshold hit rate `15.6%`, avg round `11.95`;
  - 100% held-level threshold hit rate `0%`;
  - board combat winrate at 50-74% coverage `48.3%`, at 75-99% coverage
    `7.9%`, at 100% coverage `0%`;
  - interpretation: the target does not merely fail because the final copy
    never appears. When the policy forces the partial 75-99% board, that board
    currently fights poorly. This points to target composition design/support
    quality, not only shop access.
- position-aware target diagnostics were added after that threshold pass:
  `plan_access` and compact `target_rows` now expose `position_complete_rate`,
  `ever_board_position_complete_rate`, final board slot coverage, and peak
  board slot-level coverage. `position_complete` requires the right unit and
  the required level in the target slot, so it is a real placement/level check,
  not only an ownership check.
- position-aware rerun for the same `rot_bleed_rat_core` panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/plan-realization-rot-bleed-rat-position-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan,committed_rot_bleed_rat_core_no_xp_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 32`
  - target `rot_bleed_rat_core`: strict complete `0%`, position-complete `0%`,
    ever-position-complete `0%`;
  - held-level coverage remains the same as the threshold pass
    (`48.4%` hit 50%, `15.6%` hit 75%, `0%` hit 100%), but final board slot
    coverage is only `7.0%` and peak slot-level coverage only `5.4%`;
  - oracle for the exact comp is still excellent (`100%` forced winrate,
    `12.0s` average fight, coherence `0.754`), so the complete comp itself
    should not be buffed;
  - decision: the next useful implementation pass is placement-aware plan
    deployment/driver behavior, not a global economy/pacing change and not a
    buff to the complete comp. The simulator currently proves that run policies
    can own parts of a plan without actually placing the intended aura graph.
- placement-aware policy deployment was then added for exact target comps:
  `committed_unit_set_plan` can now load slots from a `targetComp`, and the
  rat-core committed policies point at `rot_bleed_rat_core`. After buying,
  merging, and generic bench deployment, the policy deterministically rearranges
  owned target units into their catalogue slots when those slots are unlocked.
- placement-aware rerun for the same `rot_bleed_rat_core` panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/plan-realization-rot-bleed-rat-position-aware-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan,committed_rot_bleed_rat_core_no_xp_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 32`
  - global selected policies: completion `54.7%`, avg wins `9.17`, desired
    buy-all `60.8%`, merge-per-pair `95.1%`, leftover `3.46`;
  - target `rot_bleed_rat_core`: strict complete `0%`, position-complete `0%`,
    held 50% threshold `48.4%`, held 75% threshold `16.4%`;
  - final board slot coverage improved from `7.0%` to `40.8%`; final board
    slot-level coverage improved from `5.5%` to `29.7%`;
  - board winrate at 50-74% coverage moved only slightly (`48.3%` -> `49.7%`)
    and at 75-99% stayed bad (`7.9%` -> `7.3%`);
  - interpretation: the simulator now proves that placement was a real missing
    layer, but not the last blocker. The remaining issue is still access and
    level realization for mid-rank/support pieces, especially `clot_mender`
    (`35.2%` seen rate, first seen around round `8.78`).
  - decision: do not buff the final comp and do not retune global economy from
    this. Next work should either reduce the strict target shape for V1, improve
    mid-rank support access, or add plan-specific reward/event support if the
    design goal is that exact aura comps become realistic during a normal run.
- live run-event unit rewards are now context-aware: unit lanes still obey the
  explicit reward contract and placement filter, but their materialized unit is
  biased toward copies already owned and toward the build's current
  archetype/type/family. The lab driver was aligned to this default so scenario
  reports match live behavior.
- `docs/research/run-events-reward-loop.md` has been resynced with that new
  default. Older `PIT_EVENT_UNIT_TARGETING=space` wording is now documented as
  legacy/safety terminology rather than the only live-aligned mode.
- context-event rerun for the same `rot_bleed_rat_core` panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/plan-realization-rot-bleed-rat-live-context-events-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan,committed_rot_bleed_rat_core_no_xp_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 32`
  - global completion moved to `58.6%`, avg wins `9.27`;
  - event unit rewards became much higher quality: `event_units_per_run`
    `0.71`, `event_unit_progress_rate` `89.0%`, failure `0%`
    (previous live-like panel: `0.44` units/run and `19.6%` progress);
  - target `rot_bleed_rat_core`: held 50% threshold `46.9%`, held 75%
    threshold `16.4%`, held 100% threshold `0.8%`, strict complete `0%`;
  - board slot-level coverage stayed around `30.7%`;
  - interpretation: contextual events make chosen unit rewards meaningfully
    useful for the current build, but they mainly help copies already in motion.
    They do not solve rare mid-rank support access by themselves. For rat-core,
    `clot_mender` remains the practical bottleneck.
- broader economy/context checkpoint:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/economy-live-context-targeted-n48 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_POLICIES=greedy_plan,econ_plan,committed_rot_bleed_rat_core_deep_reroll_plan PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 48`
  - baseline: completion `41.0%`, avg wins `9.15`, full-shop afford `94.7%`,
    merge-per-pair `72.2%`, leftover `8.39`;
  - live candidate: completion `61.8%`, avg wins `9.34`, full-shop afford
    `62.2%`, merge-per-pair `94.3%`, leftover `3.49`;
  - live event unit rewards in this broader panel: `0.48` units/run, progress
    rate `78.3%`, failure `0%`;
  - interpretation: contextual events did not break the economy conclusion.
    The SAP-like live profile remains the V1 candidate.

Implementation status:

- `src/run/economy.lua` now resolves nil economy to the live candidate profile;
- `baseline` remains explicit legacy comparison;
- live `Build` now computes held level-1 pairs and asks `RunState` to inject a
  supported third copy after reroll/round roll;
- reroll button display uses `run:currentRerollCost()` instead of the old
  constant.
- `src.lab.policies` can now derive plan target slots from catalogue comps for
  exact committed policies and can rearrange owned target units into those
  slots deterministically after purchase/deployment. This is lab-driver behavior
  only; it does not alter combat rules.
- `src.run.event_rewards` now provides deterministic contextual unit priority
  for live run events. `src.lab.rundriver` uses the same default roll options
  so lab reports measure the same contextual event behavior as the playable
  route.

Validation status:

- targeted tests passed:
  `luajit tests/run.lua`,
  `luajit tests/coherence.lua`,
  `luajit tests/lab.lua`,
  `luajit tests/headless.lua`;
- smoke passed:
  `PIT_SCEN_OUT=runs/final-live-v1-2026-06-28/live-economy-smoke PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 16`;
- full check passed:
  `sh tools/check.sh`.
- latest targeted checks passed after adding position-aware plan diagnostics:
  - `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/position-smoke-n1 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=committed_rot_bleed_rat_core_deep_reroll_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 1`;
  - `luajit tests/scenarios.lua`;
  - `sh tools/check.sh` at `2026-06-29 11:32 CEST`.
- latest targeted checks passed after plan-aware policy placement:
  - `luajit tests/lab.lua`;
  - `luajit tests/scenarios.lua`;
  - `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/position-aware-policy-smoke-n4 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_POLICIES=committed_rot_bleed_rat_core_deep_reroll_plan PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua economy 4`;
  - `sh tools/check.sh` at `2026-06-29 11:58 CEST`.
- latest targeted checks passed after contextual run-event rewards:
  - `luajit tests/run.lua`;
  - `luajit tests/headless.lua`;
  - `luajit tests/lab.lua`;
  - `luajit tests/scenarios.lua`;
  - `sh tools/check.sh` at `2026-06-29 12:19 CEST`.
- latest visual/context checks:
  - `love . --shoot=runevent_unit_glossary --shoot-size=1280x720` generated
    `/Users/kevinbarfleur/Library/Application Support/LOVE/the-pit/shots/runevent_unit_glossary.png`;
  - the capture was inspected locally. It is readable and no event reward/glossary
    surface crashed.
- latest documentation checkpoint:
  - `docs/research/run-events-reward-loop.md` now records the contextual event
    reward default, latest N=32/N=48 panels, and the remaining mid-rank support
    access question.

### Combat Pacing

Current live pacing remains acceptable:

- `hp x2`;
- cooldown `x1.5`;
- fatigue starts at `26s`.

Latest finalization panel:

- command:
  `PIT_SCEN_OUT=runs/final-live-v1-2026-06-28/pacing-n40 PIT_PACE_IDS=live_hp2_cd15_f26,hp2_cd165_f26 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua pacing 40`
- `live_hp2_cd15_f26`: completion `13.9%`, early avg `13.15s`,
  under-5s `7.0%`, p50 `11.27s`, p90 `18.62s`, fatigue touch `1.3%`,
  fit `0.993`;
- `hp2_cd165_f26`: completion `15.8%`, early avg `14.27s`, under-5s `5.8%`,
  p50 `12.07s`, p90 `19.97s`, fatigue touch `2.2%`, fit `1.000`.

Latest autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/pacing-sweep-n24 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_PACE_IDS=live_hp2_cd15_f26,hp2_cd165_f26 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 24`
- live pacing: completion `8.3%`, avg wins `6.73`, early avg `12.95s`,
  p50 `10.90s`, fatigue touch `1.3%`, fit `0.962`;
- `cd x1.65`: completion `9.0%`, avg wins `6.91`, early avg `13.87s`,
  p50 `11.95s`, fatigue touch `2.2%`, fit `0.969`.

Latest larger autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/pacing-sweep-n64 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_PACE_IDS=live_hp2_cd15_f26,hp2_cd165_f26 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 64`
- live pacing: completion `8.0%`, avg wins `6.74`, early avg `12.95s`,
  p50 `11.08s`, p90 `18.33s`, fatigue touch `1.1%`, fit `0.964`;
- `cd x1.65`: completion `9.1%`, avg wins `6.86`, early avg `13.98s`,
  p50 `12.07s`, p90 `20.10s`, fatigue touch `2.1%`, fit `0.966`.

Latest context-event checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/pacing-live-context-sweep-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_PACE_IDS=live_hp2_cd15_f26,hp2_cd165_f26 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 32`
- live pacing: completion `22.8%`, avg wins `7.17`, duration fit `0.835`,
  early short-fight rate `5.36%`, desired-buy-all `52.9%`,
  merge-per-pair `91.8%`;
- `cd x1.65`: completion `24.4%`, avg wins `7.09`, duration fit `0.846`,
  early short-fight rate `3.94%`, fatigue touch higher in the printed summary
  (`5.6%` vs `3.6%`), desired-buy-all `53.5%`, merge-per-pair `93.6%`;
- interpretation: the slower cooldown variant still does not create enough
  separation to justify moving live constants. It reduces the short-fight tail
  but adds more fatigue and does not improve average wins.

Decision:

- do not move live pacing yet;
- `cd x1.65` is a safe future candidate if playtests still feel slightly too
  fast, but economy/live PVE should be stabilized first. The latest checkpoint
  keeps this as a watch item, not an automatic change. The N=64 sweep did not
  create enough separation to justify changing the live constants.
- watch `early_under_5s` specifically. The last larger sweep still had a small
  early-combat tail under 5 seconds; the `cd x1.65` variant did not solve it
  cleanly, so this is likely composition/opponent-specific rather than a global
  cooldown multiplier issue.
- diagnostics were upgraded after discovering that `PIT_OPPONENT_MODE=generated`
  was honored by `economy` but not by `pacing`/`sweep`. Both modes now pass
  `opponentMode` and `oppgen_pressure` through to `Rundriver`.
- `pacing` and `sweep` now report early duration buckets by encounter label and
  by exact generated enemy signature. The label explains broad size buckets
  (`fallen_patrol`, `drowned_choir`); the signature exposes exact generated
  units such as `generated:demon:L1+footman:L1+ash_moth:L1`.
- immediate implication: future pacing conclusions from generated opponents
  should be based on the new reports, not on older sweeps that silently used
  static encounters.
- generated-opponent pacing panel, all policies N=24:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/pacing-hp-overlays-generated-all-n24 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_PACE_PROFILES=live_hp2_cd15_f26:2:1.5:1560,hp25_cd15_f30:2.5:1.5:1800 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 24`
  - live: completion `23.9%`, avg wins `7.13`, early avg `10.97s`,
    under-5s `5.2%`, p50 `12.22s`, p90 `21.37s`, fatigue touch `3.5%`,
    fit `0.848`;
  - `hp x2.5 / cd x1.5 / fatigue 30s`: completion `23.3%`, avg wins `7.01`,
    early avg `12.45s`, under-5s `1.9%`, p50 `14.35s`, p90 `25.88s`,
    fatigue touch `4.9%`, fit `0.844`;
  - decision: keep live pacing for now. `hp x2.5` is a real candidate if
    playtest feedback says early fights are still too short, but the lab shows
    it makes the median/end tail slower and slightly lowers run outcomes.
- current generated-opponent confirmation N=48:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/current-confirm-sweep-n48 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_PACE_PROFILES=live_hp2_cd15_f26:2:1.5:1560,hp25_cd15_f30:2.5:1.5:1800 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 48`
  - live: completion `22.5%`, avg wins `7.14`, early avg `10.78s`,
    early under-5s `5.5%`, all p50 `12.28s`, p90 `21.35s`, fatigue touch
    `3.7%`;
  - `hp x2.5 / cd x1.5 / fatigue 30s`: completion `23.1%`, avg wins `7.02`,
    early avg `13.20s`, early under-5s `2.2%`, all p50 `14.78s`,
    p90 `26.18s`, fatigue touch `5.4%`;
  - decision remains unchanged: keep live pacing. The `hp x2.5` overlay is a
    playtest fallback if early fights feel too explosive, but it makes the
    normal fight distribution heavier.
- `early_by_enemy_signature_top` now sorts by raw under-5s incident count before
  rate, so repeated signatures outrank one-sample 100% noise. Current repeated
  generated early signatures to watch include `generated:gnaw_rat:L1+witch:L1`
  and `generated:marauder:L1+gnaw_rat:L1`.
- latest N=48 generated signatures with repeated early under-5s incidents:
  `generated:live_wire:L1+gnaw_rat:L1`,
  `generated:mire_thing:L1+carrion_pecker:L1+gnaw_rat:L1`,
  `generated:bore_worm:L1+marauder:L1`,
  `generated:leech_thorn:L1+byakhee:L1`, and
  `generated:spore_tick:L1+witch:L1`. Treat these as opponent/composition
  watchpoints before changing global HP or cooldown constants.
- `pacing` and `sweep` now also emit `early_short_fight_diagnostics`, which
  classifies under-5s early combats by likely cause using the already resolved
  player/enemy combat specs. This is a lab clue, not a replacement for manual
  playtest: direct DPS/HP stats intentionally stay compact and do not fully
  explain DoT, shields, and target order.
- latest early-short diagnostic panel:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/early-short-diagnostic-sweep-n24 PIT_SWEEP_ECONOMIES=sap_cost_pair_completion_tiered_reroll PIT_SWEEP_PACES=live_hp2_cd15_f26 PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto luajit tools/sim.lua sweep 24`
  - live: completion `23.0%`, avg wins `7.07`, duration fit `0.848`,
    early avg `10.97s`, all p50 `11.97s`, fatigue touch `3.4%`,
    merge-per-pair `90.9%`;
  - early short fights: `101/1944` early fights, `5.2%`, still inside the
    duration-fit target;
  - likely-cause split: `enemy_direct_dps_over_player_hp` `30`,
    `small_enemy_team` `30`, `player_unit_count_gap` `16`, `mixed` `13`,
    `player_burst_or_level_spike` `12`;
  - repeated signatures to keep on the watchlist:
    `generated:leech_thorn:L1+byakhee:L1` (`7/7`, `4.77s` average),
    `generated:gnaw_rat:L1+witch:L1` (`6/7`, `4.93s`),
    `generated:chitin_drone:L1+carrion_pecker:L1+gnaw_rat:L1` (`6/10`,
    `4.98s`), `generated:bandit:L1+ash_moth:L1` (`6/21`, `3.60s`), and
    `generated:marauder:L1+gnaw_rat:L1` (`6/31`, `3.52s`);
  - decision remains unchanged: no global HP/cooldown retune from this panel.
    The tail is small and composition-specific enough that manual playtest
    should look at these signatures before touching live pacing constants.
- follow-up read on the same N=48 report:
  - the worst early-under-5 policies are mostly intentionally weak or very
    narrow probes (`committed_burn`, old late-only committed plans);
  - the main playable policies (`greedy_plan`, `econ_plan`, `econ_prune`,
    `greedy_prune`, `greedy_stats`, `econ_streak`, and the current rat-core
    probes) mostly sit near `3/144` early under-5s incidents, with the wider
    `tall_dense_plan` at `6/144`;
  - playable-policy signatures to keep on the manual watchlist:
    `generated:mire_thing:L1+carrion_pecker:L1+gnaw_rat:L1`,
    `generated:live_wire:L1+gnaw_rat:L1`,
    `generated:chitin_drone:L1+carrion_pecker:L1+gnaw_rat:L1`, and
    `generated:mire_thing:L1+spore_tick:L1+live_wire:L1`;
  - decision: do not change global HP/cooldown or OppGen yet. The generator
    already keeps early size small and places front-like units first. This is a
    manual-playtest watchpoint, not a V1-blocking balance correction.

### Monster Mechanics

The roster no longer needs a broad mechanical rewrite before V1.

Current state from `luajit tools/sim.lua mechanics`:

- `110` units;
- simple affliction L1: `7.3%`, all low-rank;
- low-variety units: `0%`;
- authored level-up units: `64.5%`;
- effective level-up progression on monster effects: `100.0%`;
- level-3 clutch units: `25.5%`.

Decision:

- keep the remaining low-rank simple pieces as onboarding/shop readability
  unless future sims show overpick or underperformance;
- distinguish `authored level-up` from `effect progression`: not every unit
  needs a handcrafted transform, but every unit now has stats and/or skill
  payloads that materially improve at levels 2/3;
- do not add another wide creature refactor before the live V1 pass;
- next creature work should be archetype-specific, not global.

Latest coherence checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/current-coherence-rolefit-strict-n24 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_HP_MULT=2 luajit tools/sim.lua coherence 24`
- candidates `270`, fights `7412`, coherence/winrate correlation `0.237`;
- after making generated candidate placement player-like, bucket trend remains
  directionally healthy: `00_25` coherence wins `52.5%`, `25_50` wins
  `60.6%`, `50_75` wins `65.3%`, `75_100` wins `76.2%`;
- report-only improvement: coherence reports now include `frontline_fit` and
  split `role_thin_high_coherence_weak` from real `high_coherence_weak`
  outliers. This prevents mono-tag/no-frontline teams from looking like pure
  numerical balance failures.
- generated candidates now place frontliners/supports toward the front and
  carries toward the back, matching `OppGen`/player-like placement instead of
  filling slots `1..N` blindly;
- current outlier counts after the stricter split: real high-coherence weak
  `0`, role-thin high-coherence weak `26`, low-coherence strong `6`, cheap
  strong `2`, expensive weak `2`;
- interpretation: no broad creature rewrite is justified. Remaining true weak
  outliers disappeared after correcting the lab interpretation. The watch item
  is now UX/design: mono-family early builds need an obvious frontline/support
  lesson, not a blanket affliction buff.

### Run Events And Mutations

Run events are product-facing; mutations are not.

Current decision:

- live events may offer relics, units, gold, shop XP, and shop tier changes;
- unit lanes are safe but often weak unless targeted or special;
- mutation plumbing is safe in the lab but hurts bossrush outcomes right now.

Mutation status:

- keep lab-only;
- do not enable live until mutations are rarer, more build-defining, or valued
  contextually by the reward policy.

Latest UX pass:

- event reward cards now show the actual reward art for relics and units;
- economy event rewards now also get procedural icons: gold, shop XP, shop tier,
  and future mutation rewards no longer read as visually empty cards;
- capture-only run-event scenes now cover the main reward families:
  `runevent_brood`, `runevent_economy`, and `runevent_shop_tier`;
- `runevent_unit_glossary` validates the Shift glossary on an event unit reward,
  using the reward's resolved level rather than the base monster definition;
- capture-only bossrush scenes now cover every current abomination family:
  `bossrush_leviathan`, `bossrush_regard`, `bossrush_ossuaire`,
  `bossrush_kraken`, `bossrush_idole`, `bossrush_ruche`,
  `bossrush_floraison`, `bossrush_devoreur`, and `bossrush_vermine`;
- relic rewards reuse generated relic icons;
- unit rewards reuse the monster portrait renderer and can open the same Shift
  glossary as normal monster cards.
- reward art micro-labels and mutation reward labels now go through i18n keys
  instead of hard-coded UI strings;
- `tests/export_scenes.lua` now asserts that `runevent_unit_glossary` keeps
  hovering a real level-2 unit reward, so the visual regression breaks if the
  source event order changes.

### Cards, Tags, Levels, And Auras

Current decision:

- type is mechanical now because auras/relics can target `type:flesh`,
  `type:abyss`, etc.;
- monster cards therefore show the unit type next to tier/rarity;
- the Shift glossary keeps afflictions, mechanics, and triggers, but the old
  `READ A TAG LINE` anatomy block is removed because it confused real card
  reading more than it helped;
- board/bench/commander tooltips now pass the resolved unit level into
  `MonsterCard` and `CardGlossary`, so level-up stats/effects are visible when
  hovering actual run entities.

Aura UX implementation:

- `Build:resolveAuraLinks()` now reads generic aura targets instead of only
  `combat_start + neighbors`;
- visible links cover unit auras, commander auras, type/tier/level/role
  targeting, directional targeting, mimic/copy auras, and self-growth auras;
- commander links can originate from the commander pedestal instead of assuming
  every source is a board slot;
- relic effects are shown in the hovered unit inspector when that unit is
  affected, instead of drawing permanent board-wide relic webs;
- the inspector now includes both "gives" and "takes from" rows for unit,
  commander, and relic sources.

Aura UX design checkpoint:

- `docs/generation/aura-influence-ux-spec.html` is the current designer-facing
  brief for the next pass;
- latest iteration adds a hard rule that values must name what they modify
  (`Guard -15% damage taken`, `Bleed +1 dps`, `Haste +12% attack speed`, etc.)
  and six stress cases: center neighbor aura, team-wide relic, directional
  ahead/behind aura, command type/role aura, multi-source same-target stacking,
  and vertical above/below aura;
- problem to solve: chips and aura labels can still collide with creature
  silhouettes, and the current card-attached inspector consumes vertical space;
- proposed direction: keep the board as a lightweight aura network, move exact
  source/effect/target explanations into a collision-aware sidecar placed to
  the left or right of the monster card, and dock the Shift glossary outside
  the card+sidecar group;

Aura/influence implementation checkpoint:

- `src/ui/influence_panel.lua` is now the shared sidecar for build/combat
  influence inspection;
- build hover cards now dock the sidecar next to the monster card and dock the
  Shift glossary outside the card+sidecar group;
- sidecar rows use explicit value labels such as `Guard -12% damage taken`,
  `Haste +12% attack speed`, and `Poison +60% damage`;
- build aura links are quieter at rest and only show value chips for active
  hover/focus relationships;
- combat inspection now supports pause/resume from the bottom-right control
  strip, hover monster cards during combat, live state/modifier/affliction
  rows, and Shift glossary docking;
- combat creature rendering was scaled back toward build-board scale to reduce
  the old zoomed-in combat mismatch;
- `Combat` now captures murmur events emitted during `combat_start` before the
  ordinary scene listeners attach, so hidden affinities can be displayed in
  inspection without leaking to cards/tags/grimoire;
- hidden murmurs appear only as a subtle bottom `MURMUR` section in the
  influence sidecar, with cryptic text and no numeric magnitude.

Proving Ground murmur coverage:

- added four filtered scenarios under the `Murmur` tag:
  `whisper_abyss`, `whisper_forge`, `whisper_echo`, and `whisper_patient`;
- these scenarios exercise presence, adjacency, family, delayed, low-HP, and
  ally-death murmur shapes in realistic poison/burn/shock/rot shells;
- added `--shoot=combat_murmur_inspect` to capture a paused combat with an
  active murmur sidecar.

Commander diversity pass:

- a first scoped data pass reduced repeated team-wide `poisonInc`, `burnInc`,
  `bleedInc`, `rotInc`, `haste`, `regen`, and `dmgReduce` bonuses;
- several command bonuses now target `role:front`, `role:back`, `role:center`,
  `tier:1`, or a specific `type:*`;
- this is intentionally not the final commander rebalance. It is a readability
  pass that makes target shapes more varied before deeper simulation tuning.

### PvE Bossrush

Bossrush is useful as a lab and can become a V1 product surface.

Latest finalization panel:

- command:
  `PIT_SCEN_OUT=runs/final-live-v1-2026-06-28/bossrush-n14 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto PIT_BOSSRUSH_HP_MULT=2 PIT_BOSSRUSH_CD_MULT=0.5 luajit tools/sim.lua bossrush_run 14`
- baseline: entry `22.8%`, score/run `5816`, score/entry `25562`;
- live candidate: entry `27.2%`, score/run `7815`, score/entry `28682`;
- overall clear remains high (`98%+`);
- `ossuaire` is the main survival wall: survival `41.3%`,
  full-window `32.8%`, kill `8.5%`;
- `brasier` and `kraken` are clearer score/kill checks.

Latest autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/bossrush-run-n24 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto PIT_BOSSRUSH_HP_MULT=2 PIT_BOSSRUSH_CD_MULT=0.5 luajit tools/sim.lua bossrush_run 24`
- live economy aggregate: entry `26.5%`, score/run `7412`, score/entry
  `27926`, clear `98.1%`, full-window `54.5%`;
- baseline aggregate: entry `23.0%`, score/run `6169`, score/entry `26828`,
  clear `96.9%`, full-window `52.2%`;
- boss read: `ossuaire` remains the survival wall (`44.9%` survival,
  `38.0%` full-window, `6.9%` kill). `brasier` and `kraken` remain high
  kill/score checks. `vermine` currently yields the highest average score,
  which is fine as an anti-tank/long-DPS boss identity.

Latest larger autonomy checkpoint:

- command:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/bossrush-run-n64 PIT_ECON_PROFILES=baseline,sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto PIT_BOSSRUSH_HP_MULT=2 PIT_BOSSRUSH_CD_MULT=0.5 luajit tools/sim.lua bossrush_run 64`
- live economy aggregate: entry `25.9%`, score/run `6824`,
  score/entry `26321`, clear `98.1%`, full-window `62.9%`,
  survival `87.3%`;
- baseline aggregate: entry `18.4%`, score/run `4706`,
  score/entry `25570`, clear `96.5%`, full-window `56.7%`,
  survival `82.8%`;
- boss read by survival: `ossuaire` is still the wall (`40.7%` survival,
  `34.7%` full-window, `6.0%` kill). `brasier` is the easiest kill check
  (`41.0%` kill, `95.2%` survival). `idole` is the longest blocker
  (`9.09s` clear), but survivability stays high (`96.6%`).
- interpretation: bossrush is playable as a V1 scoring surface. Do not flatten
  the boss identities before playtest; just watch whether `ossuaire` feels
  unfair rather than merely defensive.

Latest Ossuaire tuning:

- old broad bossrush read: `ossuaire` had `44.9%` survival, `42.9%`
  full-window, and `1.95%` boss-kill rate. It cleared blockers reliably but
  killed too many builds during the scoring window.
- first softening overshot: `90.2%` survival and `83.4%` full-window.
- final V1 midpoint, isolated N=32:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/bossrush-ossuaire-mid-n32 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_ABOMINATIONS=ossuaire PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto PIT_BOSSRUSH_HP_MULT=2 PIT_BOSSRUSH_CD_MULT=0.5 luajit tools/sim.lua bossrush_run 32`
- final result: `74.1%` survival, `70.7%` full-window, `3.4%`
  boss-kill rate, `2135` score damage per entry. This keeps the wall identity
  while making the score window realistically playable.
- full bossrush N=24 after the midpoint:
  `runs/autonomy-v1-2026-06-29/bossrush-current-live-post-ossuaire-n24`.
  `ossuaire` now sits at `71.2%` survival, `67.5%` full-window, `3.7%`
  boss-kill rate, and `2184` average score damage. It remains the lowest-kill
  defensive boss without being a survival outlier.
- current generated-opponent bossrush confirmation N=48:
  - command:
    `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/current-confirm-bossrush-n48 PIT_ECON_PROFILES=sap_cost_pair_completion_tiered_reroll PIT_OPPONENT_MODE=generated PIT_OPPGEN_LEVEL_MULT=2.25 PIT_RUN_EVENTS=1 PIT_COMMANDER_MODE=auto PIT_BOSSRUSH_HP_MULT=2 PIT_BOSSRUSH_CD_MULT=0.5 luajit tools/sim.lua bossrush_run 48`
  - aggregate: entry/completion `23.9%`, score/run `6189`, score/entry
    `25874`, clear `97.8%`, survival `89.6%`, full-window `68.4%`,
    boss-kill `21.3%`;
  - `ossuaire`: survival `74.5%`, full-window `66.8%`, boss-kill `7.7%`,
    average score damage `2210`, clear `97.7%`;
  - interpretation: the midpoint holds under a broader confirmation. Ossuaire
    remains the defensive/low-kill boss, but it is no longer a survival outlier.

Implementation status:

- runover victory now offers two routes:
  `DESCEND FURTHER` enters bossrush, `CLAIM VICTORY` starts a fresh run;
- `src/scenes/bossrush.lua` now starts a live PvE bossrush combat by default:
  final build vs abomination boss + three generals, then a score window opens
  once the generals are broken;
- `src/lab/bossrush.lua` remains the deterministic headless runner for tools,
  reports, and optional `instantScore` QA surfaces;
- the final board is converted through `buildLeftComp()` and run relics are
  applied before the bossrush simulation, matching normal combat;
- score records are appended to `run.bossrushResults` only after the live
  bossrush resolves, with seed, boss, score damage, survival, full-window
  result, boss kill flag, and damage causes;
- `--shoot=bossrush` is wired through `src/core/export_scenes.lua` and now
  captures the live bossrush entry state instead of the old instant result
  panel.
- the score surface now presents the selected abomination, its family/threat
  signs, its three generals, and a three-step phase rail:
  generals -> score window -> result;
- the score meter now uses the existing `Juice`/`SFX` stack for milestone
  pulses, count-up emphasis, subtle trauma, and final impact.
- scoring sources are displayed as colored chips, matching the broader tag
  language instead of plain text.
- the abomination cell now draws a lightweight procedural boss avatar inspired
  by `docs/generation/generateur-abominations.html` instead of a generic eye
  seal. This is not a full port of the HTML generator; it carries the readable
  theme signatures for the V1 score surface.
- export scenes can pin each current abomination family for visual QA without
  waiting for a random run result.
- bossrush UI now translates abomination display names through i18n instead of
  leaking French data names from `src/data/abominations.lua`;
- bossrush lab results now include per-general alive/dead state, and the
  encounter panel uses that state instead of applying the aggregate
  `cleared_blockers` flag to every row. This keeps partial failures readable.

Validation status:

- targeted tests passed:
  `luajit tests/ui.lua`,
  `luajit tests/headless.lua`,
  `luajit tests/run.lua`,
  `luajit tests/lab.lua`,
  `luajit tests/scenarios.lua`;
- visual export passed:
  `love . --shoot=bossrush`, inspected at
  `/Users/kevinbarfleur/Library/Application Support/LOVE/the-pit/shots/bossrush.png`;
- latest visual pass re-captured `love . --shoot=bossrush` after the phase/score
  redesign and checked spacing manually;
- latest full check passed after the Bossrush presentation/feel/source-chip pass:
  `sh tools/check.sh`.
- latest full check passed again after the run-event reward art pass:
  `sh tools/check.sh`.
- latest full check passed after adding targeted run-event export scenes:
  `sh tools/check.sh`.
- latest safety captures inspected:
  `love . --shoot=bossrush`, `love . --shoot=runevent`,
  `love . --shoot=build_aura_hover`, `love . --shoot=build`, and
  `love . --shoot=combat_impacts`.
- targeted tests passed after the abomination avatar pass:
  `luajit tests/ui.lua`, `luajit tests/lab.lua`, and
  `luajit tests/scenarios.lua`.
- all current bossrush family exports captured without crash and were inspected
  for non-empty/readable avatar silhouettes.
- latest full check passed after the abomination avatar and pinned export pass:
  `sh tools/check.sh` at `2026-06-29 04:07 CEST`.
- added persistent export-scene coverage:
  `tests/export_scenes.lua` checks unique `--shoot` names, existing builders,
  run-event regression scenes, and one named export per abomination family;
- latest full check passed with the new export-scene test:
  `sh tools/check.sh` at `2026-06-29 04:19 CEST`.
- broad visual export passed:
  `love . --shoot=all` generated all `55` current scenes without crash;
- fixed the `runover` export seed state so the victory capture now displays a
  coherent completed run (`10 wins`, `2 losses`, `12 rounds`, `level 5`);
- targeted export checks passed after the runover capture fix:
  `luajit -bl src/core/export_scenes.lua` and
  `luajit tests/export_scenes.lua`.
- latest full check passed after the larger autonomy panels and runover capture
  fix: `sh tools/check.sh` at `2026-06-29 04:54 CEST`.
- targeted syntax/tests passed after the bossrush i18n/general-state and event
  i18n cleanup:
  `luajit tests/export_scenes.lua`, `luajit tests/i18n.lua`,
  `luajit tests/lab.lua`, `luajit tests/ui.lua`, and `luajit tests/run.lua`;
- targeted visual captures passed and were inspected:
  `love . --shoot=bossrush_brasier`,
  `love . --shoot=bossrush_ossuaire`, and
  `love . --shoot=runevent_unit_glossary`;
- latest full check passed after those fixes:
  `sh tools/check.sh` at `2026-06-29 05:25 CEST`.
- latest full check remained green after the generated-opponent diagnostics and
  coherence report cleanup:
  `sh tools/check.sh` at `2026-06-29 08:11 CEST`;
- broad visual export passed after that check:
  `love . --shoot=all --shoot-size=1280x720` generated all `55` current scenes
  without crashing;
- representative captures inspected:
  `bossrush_ossuaire.png`, `build_aura_hover.png`,
  `card_wither_bloom_glossary.png`, and `runevent_unit_glossary.png`;
- visual watchpoint: the forced `runevent_unit_glossary` export combines a
  unit reward, Shift glossary, and a wider reward set. At `1280x720`, the
  rightmost non-primary reward can sit very close to the viewport edge. Verify
  whether this is only a QA export composition or a real event layout issue
  before treating it as a live-blocking bug.
- follow-up inspection: the event cards themselves are not clipped. The normal
  `runevent_brood` and `runevent_economy` captures keep four explicit rewards
  readable inside the viewport. The only overlap appears while Shift glossary is
  forced on the second card; that is a deliberate reading overlay and not a live
  card-layout blocker for now. Do not change `TagGlossary.anchor()` until a real
  playtest shows that Shift-reading in event screens needs a different
  placement rule.
- added UI regression coverage for the run-event version of `Relicpick`: a
  four-choice event now asserts explicit cards stay inside the viewport, event
  screens do not expose the relic `REFUSE` button, and `BIND` routes through
  `finishRunEventPick(index)` instead of the legacy relic path;
- targeted checks after that test addition passed:
  `luajit tests/ui.lua`, `luajit tests/export_scenes.lua`, and
  `luajit tests/run.lua`.
- full validation remained green after the run-event UI regression coverage:
  `sh tools/check.sh` at `2026-06-29 08:41 CEST`.

Decision:

- keep bossrush stress profile useful for testing;
- the minimal product flow is now in-game as an instant, readable score-result
  surface;
- do not over-tune boss HP first. Boss cadence/threat identity matters more.
- next bossrush work should only add a spectator/animated combat if playtesters
  still need more clarity. The V1 score screen itself is usable enough to test.

## Work Completed In This Increment

- Ran final economy, pacing, and bossrush panels under generated opponents,
  run events, and commander auto.
- Chose economy live candidate:
  `sap_cost_pair_completion_tiered_reroll`.
- Implemented live economy:
  default profile, live pair-completion shop support after round/reroll rolls,
  dynamic reroll UI cost, and explicit legacy baseline access.
- Updated coherence defaults so `current` means the live economy profile, not
  the old baseline.
- Updated economy/run tests around dynamic cost-by-rank and pair-completion
  support.
- Added a minimal post-win PvE route:
  runover choice, bossrush score scene, deterministic score computation,
  stored score records, i18n labels, system-button/music/export integration.
- Added UI coverage for win-runover routing and the bossrush result scene.
- Captured and inspected the bossrush result screen with `love . --shoot=bossrush`.
- Upgraded the bossrush result screen with an abomination cell, threat tags,
  explicit general blockers, a phase rail, and Juice/SFX score milestones.
- Converted Bossrush scoring sources into colored source chips.
- Replaced the generic boss seal center with theme-specific procedural
  abomination avatars, borrowing the readable visual language from the existing
  abomination generator HTML while keeping the V1 renderer small.
- Added pinned bossrush export scenes for all current abomination families and
  captured/inspected the full set.
- Added the explicit `bossrush_brasier` export alias so the default Brasier
  scene is also addressable through the same family naming convention.
- Added `tests/export_scenes.lua` and wired it into `tools/check.sh` to keep
  visual-regression scene names and builders from drifting apart.
- Captured and inspected `love . --shoot=bossrush_brasier`.
- Ran `love . --shoot=all`; all current export scenes rendered without crash.
- Corrected the capture-only `runover` scene so its displayed run stats match a
  victory route instead of a fresh run.
- Ran larger autonomy panels:
  economy targeted N=96, pacing sweep N=64, and bossrush-run N=64. These confirm
  the current V1 decisions: keep live economy, keep live pacing, keep bossrush
  identities for playtest with `ossuaire` on the watchlist.
- Re-ran the full suite after the abomination avatar and pinned export pass;
  `sh tools/check.sh` remained green at `2026-06-29 04:07 CEST`.
- Re-ran the full suite after adding export-scene coverage; `sh tools/check.sh`
  remained green at `2026-06-29 04:19 CEST`.
- Re-ran the full suite after the larger autonomy panels and capture-only
  runover fix; `sh tools/check.sh` remained green at `2026-06-29 04:54 CEST`.
- Fixed bossrush display-name leakage by routing abomination names through i18n
  keys.
- Added per-general bossrush result state so the encounter panel can show each
  blocker as `BROKEN` or `BLOCKS` independently.
- Moved run-event reward art labels and mutation reward names/descriptions
  behind i18n keys.
- Strengthened `tests/export_scenes.lua` so the unit-glossary event capture
  explicitly depends on a level-2 creature reward.
- Captured and inspected `bossrush_brasier`, `bossrush_ossuaire`, and
  `runevent_unit_glossary` after those UX/i18n fixes.
- Re-ran the full suite after those fixes; `sh tools/check.sh` remained green
  at `2026-06-29 05:25 CEST`.
- Added target-saturation gating to committed unit-set policies so a target id
  stops being over-prioritized only after the plan has enough level coverage and
  board presence. This prevents early policy starvation while still reserving
  late space for missing target ids.
- Tuned `committed_rot_bleed_rat_core_deep_reroll_plan` to keep support pieces
  longer (`supportUntilLevelCoverage = 0.75`) and allow support pairs after the
  gate.
- Added exact generated-opponent signatures to `OppGen` and propagated them
  through `Rundriver` trajectories.
- Fixed `pacing`/`sweep` to actually honor `PIT_OPPONENT_MODE` and
  `PIT_OPPGEN_*` settings.
- Added `early_by_enemy_signature_top` to pacing/sweep reports and scenario
  smokes.
- Validated the diagnostic increment with:
  `luajit tests/lab.lua`, `luajit tests/run.lua`,
  `luajit tests/scenarios.lua`, and targeted N=32/N=16/N=8 panels under
  `runs/autonomy-v1-2026-06-29/`.
- Re-ran the full suite after the policy and pacing/sweep diagnostic fixes;
  `sh tools/check.sh` remained green at `2026-06-29 06:43 CEST`.
- Re-ran `luajit tests/scenarios.lua` after changing signature sorting; it
  remained green. Latest targeted generated pacing panels are under
  `runs/autonomy-v1-2026-06-29/pacing-generated-n32/`,
  `pacing-hp-overlays-generated-n32/`,
  `pacing-hp-overlays-generated-all-n24/`, and
  `pacing-signatures-sorted-n12/`.
- Tuned the `ossuaire` abomination midpoint: boss thorns/damage reduction stay
  meaningful, but the execute and bone guard are less oppressive than the old
  version. Validated with isolated bossrush N=32 and `luajit tests/scenarios.lua`.
- Re-ran a full bossrush live-only N=24 after the Ossuaire midpoint; the boss
  distribution remains readable, with Ossuaire still lowest in kill/score but no
  longer collapsing survival.
- Re-ran the full suite after the Ossuaire midpoint, generated-opponent
  pacing/sweep diagnostics, and signature sorting changes; `sh tools/check.sh`
  remained green at `2026-06-29 07:24 CEST`.
- Ran current confirmation panels after the generated-opponent diagnostic fix:
  economy N=48, sweep N=48, bossrush-run N=48. These reinforce the current V1
  decisions: keep live economy, keep live pacing, keep the Ossuaire midpoint.
- Ran mechanics and coherence checkpoints after the confirmation panels.
  Mechanics coverage stayed stable (`110` units, `61.8%` authored level-ups,
  `25.5%` L3 clutch). Coherence now reports frontline/role-thin diagnostics,
  generated candidates use player-like placement, and
  `luajit tests/scenarios.lua` remained green.
- Re-ran the full validation suite after the coherence report improvements;
  `sh tools/check.sh` remained green at `2026-06-29 08:11 CEST`.
- Added short "Current V1 Read" blocks to `run-events-reward-loop.md` and
  `pve-bossrush-scoring-loop.md` so older historical panels do not override the
  latest roadmap decisions during handoff.
- Re-ran the V1 safety visual set after the Bossrush pass:
  bossrush, run event rewards, build aura hover, build board, and combat impacts.
- Ran autonomy checkpoint panels for targeted economy, pacing sweep, and
  bossrush-run. Broad all-policy economy N=128/N=48 was intentionally stopped
  because it was too slow for the checkpoint loop; the targeted N=24 panel gives
  the useful V1 signal.
- Added procedural visuals for non-card run event rewards (gold, shop XP, shop
  tier, future mutation lane) and re-captured `love . --shoot=runevent`.
- Re-ran `sh tools/check.sh` after the non-card run event reward visuals; the
  full suite remained green.
- Added targeted run-event export scenes for brood/unit/mutation, economy
  rewards, and shop-tier rewards; captured and inspected each image.
- Added and captured a targeted `runevent_unit_glossary` scene to verify that
  event monster rewards participate in the shared Shift keyword system.
- Re-captured dense monster-card examples and confirmed the current ability
  layout matches the latest UX decision: trigger chip as the section header,
  effect text below on the full card width.
- Re-ran `sh tools/check.sh` after adding those export scenes; the full suite
  remained green.
- Added UI regression coverage for run-event choice screens: four explicit
  rewards fit horizontally, event choices have no relic-refuse action, and
  confirming a selected card calls `finishRunEventPick(index)`.
- Ran targeted checks after the run-event UI coverage:
  `luajit tests/ui.lua`, `luajit tests/export_scenes.lua`, and
  `luajit tests/run.lua`.
- Re-ran the full suite after the run-event UI coverage; `sh tools/check.sh`
  remained green at `2026-06-29 08:41 CEST`.
- Re-read the current generated-opponent sweep for early-under-5 signatures.
  Conclusion: playable policies are acceptable; the remaining short-fight
  problem is a small opponent-signature watchlist, not a reason to raise global
  HP/cooldowns or rewrite OppGen before playtest.
- Added reward art to run event cards for relic and unit rewards.
- Simplified the Shift glossary by removing the confusing `READ A TAG LINE`
  block while keeping tag/mechanic/trigger explanations.
- Made monster cards display their mechanical type for type-targeted auras and
  relics.
- Fixed build tooltips to display resolved unit level data for board, bench,
  and commander entities.
- Expanded build aura visualization to cover generic aura targets, commander
  sources, and relic effects in the hovered-unit inspector.
- Performed an initial commander targeting diversity pass to reduce repeated
  team-wide bonuses.
- Added `--shoot=build_aura_hover` as a visual regression scene for aura links
  and hovered-unit aura inspection.
- Created this roadmap as the transfer document.
- Indexed this roadmap from `docs/README.md`.
- Validated the increment with targeted tests, scenario smokes, and
  `sh tools/check.sh`.
- Latest local validation also captured and inspected:
  `love . --shoot=runevent` and `love . --shoot=build_aura_hover`.
- Manual LÖVE launch was attempted through Orca/computer-use. The app rendered
  the main menu and hover feedback correctly, but synthetic keyboard/click input
  did not reliably reach the LÖVE menu action, so it is not counted as a human
  end-to-end playtest.
- To reduce the remaining route risk, `tests/headless.lua` now covers the live
  post-combat reward route: 3/6-win milestone relics take priority, otherwise
  a materializable run event replaces the old flat merchant on every 3rd combat,
  event unit rewards can be applied to a real `Build`, and reward choice returns
  to the next build round.
- Targeted validation after that route guard:
  `luajit tests/headless.lua` passed at `2026-06-29 09:30 CEST`.
- Fixed level-aware ability scaling for non-authored level-ups. `UnitResolver`
  now scales power-bearing effect payloads generically, `Build`/snapshots always
  materialize level 2/3 effects for combat, and `mechanics` reports both
  authored level-ups and effective effect progression.
- Added authored anti-wall/execution level patches for `siege_breaker`,
  `wallbreaker`, and `reaper_shade` so the remaining no-progression units
  become explicit, bounded effects with real level-up values.
- Latest targeted validation after level scaling:
  `luajit tests/unit_resolver.lua`, `luajit tests/effect_audit.lua`,
  `luajit tests/headless.lua`, `luajit tools/sim.lua mechanics`, and
  `luajit tests/scenarios.lua` passed at `2026-06-29 10:01 CEST`.
- Full validation after the level-scaling increment:
  `sh tools/check.sh` passed at `2026-06-29 10:15 CEST`.
- Post-scaling pacing sanity panel:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/post-level-scaling-sweep-n24 ... luajit tools/sim.lua sweep 24`.
  Live pace stayed acceptable: completion `23.0%`, avg wins `7.07`,
  duration fit `0.848`, early average `10.97s`, median `11.97s`,
  fatigue touch `3.4%`, merge-per-pair `90.9%`.
- Post-scaling bossrush-run sanity panel:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/post-level-scaling-bossrush-run-n24 ... luajit tools/sim.lua bossrush_run 24`.
  Overall entry/completion stayed near the previous confirmation (`23.8%`),
  clear `99.3%`, survival `98.1%`, full score window `94.1%`, boss kill
  `4.0%`, score damage/run `4523`, score damage/entry `19031`.
  Interpretation: no emergency retune. The post-scaling bossrush currently
  looks less lethal and more "full-window scoring" than the prior N48 panel;
  keep score magnitude and boss-kill rate on the next V1 watchlist.
- Added resolved-combat-spec stats to `Rundriver` results and a deterministic
  early-short-fight diagnostic to `pacing`/`sweep`. This directly addresses the
  V1 watchpoint "are early fights under 5s caused by unit pairs, weak enemy
  pools, or burst?" without changing live data.
- Targeted validation for the diagnostic increment:
  `luajit tests/headless.lua` and `luajit tests/scenarios.lua` passed at
  `2026-06-29 10:45 CEST`.
- Full validation after the diagnostic increment:
  `sh tools/check.sh` passed at `2026-06-29 10:52 CEST`.
- Latest diagnostic panel:
  `PIT_SCEN_OUT=runs/autonomy-v1-2026-06-29/early-short-diagnostic-sweep-n24 ... luajit tools/sim.lua sweep 24`.
  Live pace stayed numerically identical to the post-scaling panel because this
  is a reporting-only increment: completion `23.0%`, avg wins `7.07`,
  duration fit `0.848`, early under-5s `5.2%`. The new cause split says the
  short tail is mostly enemy burst into weak player starts, small generated
  enemy teams, or player unit-count gaps. Interpretation: keep live pacing;
  use signatures as manual-play watchpoints.
- Re-ran a strict plan-realization panel for `rot_bleed_rat_core` after the
  scaling/reporting work. It confirmed the current known limitation: run
  outcomes can be good while exact plan completion stays at `0%` for an
  ambitious six-piece target. This is now documented under Economy as a design
  watchpoint, not treated as a reason to undo the live economy.
- Exposed partial realization thresholds in compact economy `target_rows` and
  validated them with `luajit tests/scenarios.lua`. The rat-core rerun shows
  `48.4%` of runs touch 50% held-level coverage, `15.6%` touch 75%, and 75-99%
  board coverage only wins `7.9%` of combats. This converts the old binary
  "0% complete" read into a more actionable design signal.
- Full validation after the partial-realization summary fields:
  `sh tools/check.sh` passed at `2026-06-29 11:10 CEST`.
- Aura/influence + murmur inspection implementation validated with:
  `luajit tests/i18n.lua`, `luajit tests/ui.lua`,
  `luajit tests/headless.lua`, `luajit tests/export_scenes.lua`,
  `luajit tests/murmures.lua`, and `luajit tests/lab.lua`.
- Visual captures generated and inspected:
  `love . --shoot=build_aura_hover --shoot-size=1280x720`,
  `love . --shoot=combat_hover_inspect --shoot-size=1280x720`, and
  `love . --shoot=combat_murmur_inspect --shoot-size=1280x720`.
- Full validation after the aura/influence + Proving Ground murmur increment:
  `sh tools/check.sh` passed at `2026-06-29 16:57 CEST`.

## Strict Remaining Work For Playtest V1

### 1. Upgrade Bossrush Presentation

Status: done for V1 score-screen scope.

Implemented:

- show the selected abomination and its three generals more explicitly;
- expose clear phases: generals alive, scoring window open, score window closed.

Deferred:

- decide after playtest whether an animated bossrush combat spectator is needed;
- if animated, reuse `Combat`/`ArenaDraw` patterns instead of building a second
  combat renderer.

Acceptance:

- the player understands why scoring starts only after blockers are cleared;
- the player can identify the boss family and threat identity;
- no leaderboard/daily system required for V1.

### 2. Add Score Feel Pass

Status: done for V1 score-screen scope.

Implemented:

- strengthen the current count-up score meter;
- milestone pulses;
- reuse existing `Juice`, `SFX`, damage numbers, and arena events;
- avoid a second feel stack.

Deferred:

- damage-number style effects can be reused later only if a real spectator mode
  is added. The instant score surface now uses Juice/SFX without adding a second
  feedback stack.

Acceptance:

- boss scoring feels visibly different from ordinary combat;
- large bursts create stronger feedback;
- reduced-motion/accessibility remains possible through existing systems.

### 3. Playtest Safety Pass

Status: mostly done by automated/headless/capture validation; one manual
end-to-end playtest remains recommended before giving the build to friends.

Done:

- `sh tools/check.sh` passed after the latest Bossrush work;
- `love . --shoot=all` generated all current export scenes without crash;
- entered bossrush through `--shoot=bossrush` and inspected the capture;
- capture screenshots with `--shoot=bossrush` and inspect the image;
- capture an event reward screen and a build hover with aura links/relic rows;
- captured and inspected build and combat-impact screens.
- attempted a real app launch/manual input pass. Visual menu launch was OK, but
  synthetic input did not trigger `ENTER THE PIT`, so the manual pass remains a
  real-user TODO rather than a completed validation.
- added headless route coverage for normal post-combat rewards/events:
  milestone relicpick, run-event replacement of the old merchant, event reward
  application to `Build`, and return to build.

Still needed:

- start the local app and play at least one normal run path manually;
- document any human-play feel regressions found in that pass.

Acceptance:

- no obvious hard crash in menu -> build -> combat -> reward/event -> build;
- no false/missing reroll cost;
- no empty reward screen;
- bossrush route has a clear exit.

### 4. Economy Playtest Watchlist

Needed:

- play several manual runs with the new SAP-like economy;
- verify that pair-completion support feels helpful but not fake or too obvious;
- watch whether tiered reroll cost makes late shop decisions interesting or just
  frustrating;
- compare against the stored baseline reports only if player feel regresses.

Acceptance:

- the player cannot routinely buy the whole shop early;
- merges still happen often enough to make level-ups desirable;
- reroll cost shown in the UI always matches the actual charged cost.

### 5. Simulation Watchpoints Before Balance Lock

Needed:

- keep tracking real plan realization, not only average wins/completion;
- keep `ossuaire` on the bossrush watchlist. Its identity as a defensive wall is
  useful. It has been softened from the previous outlier state, but should
  remain the lowest-kill defensive scoring boss;
- do not nerf global economy/pacing until these watchpoints are tied to a
  specific player-facing feel problem.

Done:

- early fights under 5 seconds are now classified in `pacing`/`sweep` through
  `early_short_fight_diagnostics`. The latest live panel puts the tail at
  `5.2%`, so this is no longer a global-pacing blocker. It remains a manual
  watchlist for repeated generated signatures and weak-start losses.
- plan realization now separates ownership/level coverage from board slot
  coverage. The first position-aware panel shows that `rot_bleed_rat_core` is
  blocked more by deployment/placement behavior than by its final combat power.
  Next balance work should improve plan-aware placement before changing global
  economy or buffing the target comp.
- plan-aware placement is now implemented for the rat-core committed policies.
  It fixed a large part of the slot-coverage problem (`7.0%` -> `40.8%`), but
  exact completion remains `0%`. The next blocker is access/level realization,
  not the board rearrangement layer.
- contextual run-event unit rewards are implemented and validated. They make
  event unit choices much more relevant (`event_unit_progress_rate` around
  `89%` in the rat-core panel), but exact aura comps still need either less
  strict target definitions or a deliberate mid-rank support-access pass.
- run-event documentation is current as of `2026-06-29 12:45 CEST`; another
  agent should not re-run old `space` alignment experiments unless it is doing
  a deliberate regression comparison.
- aura/influence inspection was split from normal card hover on
  `2026-06-29 17:41 CEST`: default hover shows the monster/relic information
  without aura rails, while holding `Ctrl` hides cards and switches to network
  reading. `Ctrl + unit` shows links related to that unit; `Ctrl + empty space`
  shows the full aura/combat influence network. Visual regression scenes:
  `build_aura_network_focus`, `build_aura_network_all`, `combat_network_focus`,
  `combat_network_all`.
- Proving Ground boss coverage was added on `2026-06-29`: all ten abominations
  now exist as `kind = "bossrush"` scenarios with varied player teams. WATCH
  launches the real live bossrush scene and returns the result to Proving
  Ground; SIM x200 aggregates average score, general-clear rate, and full-window
  rate. Visual regression scenes: `playground`, `playground_boss`.

## Explicit Non-Goals For This V1 Push

- no live mutations by default;
- no leaderboard;
- no daily/weekly seed UI;
- no full boss family rebalance;
- no new broad creature-design pass beyond the scoped commander-target cleanup
  already done;
- no new economy interest/bank system;
- no complete UI redesign beyond what the new live flow needs.

## Resume Notes For Another Agent

Start from:

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.codex/agent-routing.md`
4. `.codex/agents/autobattler-designer.md`
5. `.claude/agents/autobattler-designer.md`
6. this roadmap
7. `docs/research/pve-bossrush-scoring-loop.md`
8. `docs/research/run-events-reward-loop.md`

Current branch at the time this document was created:
`feat/intensive-balance-sim`.

Important local report folder:
`runs/final-live-v1-2026-06-28/`.

Important autonomy report folder:
`runs/autonomy-v1-2026-06-29/`.
