# Playtest V1 Finalization Roadmap

Date: 2026-06-28
Status: live economy, minimal bossrush score surface, reward/event card art, and build aura UX validated headless.

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

Implementation status:

- `src/run/economy.lua` now resolves nil economy to the live candidate profile;
- `baseline` remains explicit legacy comparison;
- live `Build` now computes held level-1 pairs and asks `RunState` to inject a
  supported third copy after reroll/round roll;
- reroll button display uses `run:currentRerollCost()` instead of the old
  constant.

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

Decision:

- do not move live pacing yet;
- `cd x1.65` is a safe future candidate if playtests still feel slightly too
  fast, but economy/live PVE should be stabilized first.

### Monster Mechanics

The roster no longer needs a broad mechanical rewrite before V1.

Current state from `luajit tools/sim.lua mechanics`:

- `110` units;
- simple affliction L1: `7.3%`, all low-rank;
- low-variety units: `0%`;
- authored level-up units: `61.8%`;
- level-3 clutch units: `25.5%`.

Decision:

- keep the remaining low-rank simple pieces as onboarding/shop readability
  unless future sims show overpick or underperformance;
- do not add another wide creature refactor before the live V1 pass;
- next creature work should be archetype-specific, not global.

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
- relic rewards reuse generated relic icons;
- unit rewards reuse the monster portrait renderer and can open the same Shift
  glossary as normal monster cards.

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

Implementation status:

- runover victory now offers two routes:
  `DESCEND FURTHER` enters bossrush, `CLAIM VICTORY` starts a fresh run;
- `src/scenes/bossrush.lua` computes a deterministic PvE score through
  `src/lab/bossrush.lua` and displays a score result screen;
- the final board is converted through `buildLeftComp()` and run relics are
  applied before the bossrush simulation, matching normal combat;
- score records are appended to `run.bossrushResults` with seed, boss, score
  damage, survival, full-window result, boss kill flag, and damage causes;
- `--shoot=bossrush` is wired through `src/core/export_scenes.lua`.

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
- full check passed:
  `sh tools/check.sh`.

Decision:

- keep bossrush stress profile useful for testing;
- the minimal product flow is now in-game as an instant score-result surface;
- do not over-tune boss HP first. Boss cadence/threat identity matters more.
- next bossrush work should improve presentation/feel rather than changing the
  score formula first.

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

## Strict Remaining Work For Playtest V1

### 1. Upgrade Bossrush Presentation

Needed:

- show the selected abomination and its three generals more explicitly;
- decide whether V1 needs an animated bossrush combat spectator or whether the
  instant score-result surface is enough for first friends playtest;
- if animated, reuse `Combat`/`ArenaDraw` patterns instead of building a second
  combat renderer;
- expose clear phases: generals alive, scoring window open, score window closed.

Acceptance:

- the player understands why scoring starts only after blockers are cleared;
- the player can identify the boss family and threat identity;
- no leaderboard/daily system required for V1.

### 2. Add Score Feel Pass

Needed:

- strengthen the current count-up score meter;
- milestone pulses;
- reuse existing `Juice`, `SFX`, damage numbers, and arena events;
- avoid a second feel stack.

Acceptance:

- boss scoring feels visibly different from ordinary combat;
- large bursts create stronger feedback;
- reduced-motion/accessibility remains possible through existing systems.

### 3. Playtest Safety Pass

Needed:

- start local app and play at least one normal run path;
- enter bossrush at least once through a forced/dev path if a full win is too
  slow during validation;
- capture screenshots with `--shoot=bossrush` and inspect the image;
- capture an event reward screen and a build hover with aura links/relic rows;
- document known limitations in this file.

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
