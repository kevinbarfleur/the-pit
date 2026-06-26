# Monster Level Scaling Design

Date: 2026-06-26

Scope: design and balance report only. No source, test, data, config, or generated
file changes are proposed here as edits in this branch.

## Summary

The current duplicate system is mechanically sound but incomplete from a card
fantasy perspective:

- 3 copies of the same id and level merge into the next level, capped at 3.
- `Build:buildComp` currently scales hp and attack with `LEVEL_MULT = {1.0, 1.8, 3.0}`.
- Some build-resolved auras also scale from the source level, using the same
  `LEVEL_MULT`.
- Most combat abilities themselves are still level-1 descriptors. A level-3
  Witch has larger stats, but its poison descriptor is still the level-1 poison
  unless an adjacency aura or other baked modifier changes it.

Recommendation: keep the existing stat scaling, add a separate explicit
ability-level layer, and make every monster show a readable L1/L2/L3 ability
progression. Most level-ups should be numeric. Exactly 22 of the current 110
roster entries below are proposed as transformative level-3 upgrades, matching
the requested roughly 20 percent target.

## Current Implementation Findings

### Leveling

`tests/duplicates.lua` is the current duplicate test, replacing the stale
`tests/duplicatas.lua` name. It confirms:

- three level-1 copies merge into one level-2 unit;
- nine level-1 copies cascade into one level-3 unit;
- level 1 is identity-safe;
- level 2 uses the current stat multiplier, for example Spore Tick hp 30 -> 54
  and dmg 3 -> 5.

The merge path lives in `src/scenes/build.lua`:

- `Build:checkMerges` groups board and bench units by `id + level`.
- the first copy survives, two copies are consumed, and the survivor is promoted;
- the run can arm one level-up relic offer per round.

### Effects And Stats

Unit mechanics are data descriptors in `src/data/units.lua`:

```lua
{ trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180 } }
```

Runtime ops are registered in `src/effects/ops.lua` and dispatched by
`src/effects/engine.lua`. Most proposed upgrades can be implemented as parameter
overrides, extra descriptors, or a small number of new ops. The strongest
existing guardrails are already in place:

- deterministic effect order through arrays and `ipairs`;
- stat modifier formula in `src/effects/stats.lua`;
- hard caps for attack increase, vulnerability, multicast, haste, damage
  reduction, shock, dot amplification, and percent-hp strike;
- fatigue after roughly 17 seconds to end stalls.

### Build-Resolved Auras

`Build:buildComp` bakes adjacency and role/type/level auras before combat. This
is the right place for level-aware support upgrades because it already knows the
source level, target slots, sigil graph, and target roles.

Important design correction: do not keep using raw stat `LEVEL_MULT` as the
long-term ability scaler. It makes some support abilities jump 1.8x and 3.0x,
which is much steeper than readable card progression. Move ability values to
explicit L1/L2/L3 data when this is implemented.

### Snapshots

`src/net/snapshot.lua` serializes `id`, `level`, `col`, `row`, shape, seed,
version, and tier. It reconstructs stats by level. A future ability-level
resolver can remain snapshot-free if it derives effects from `id + level`.

Current known limitation: snapshot reconstruction does not bake the full board
graph aura layer the way `Build:buildComp` does. That is already a project debt
for "effects aura/relic in snapshot". Level-aware abilities should not deepen
that debt; the resolver should be shared by `Build`, `Snapshot`, encounter
generation, and tests.

## Global Rule

### Rule Text

Keep current stat scaling:

```lua
STAT_LEVEL_MULT = { 1.0, 1.8, 3.0 }
```

Add explicit ability values per level, authored as clean card numbers:

- Level 1: current effect.
- Level 2: primary ability improves by about 50 percent.
- Level 3: primary ability improves by about 100 percent, unless the row is one
  of the marked transformative upgrades.

For readability and balance:

- Scale only the primary knob by default: dps, shield value, thorns, heal,
  aura percent, strike rider, or summon/scavenge stat.
- Keep durations, thresholds, target rules, and binary flags stable unless the
  unit is intentionally marked as a level-3 transform.
- Do not scale integer gates blindly. Multicast, summon count, no-cap, no-decay,
  taunt, and mimic depth should get a small numeric rider or a deliberate
  transform, not automatic multiplication.
- Clamp all scaled values through the existing caps. If a level-3 value hits a
  cap, the UI should show the capped value and the implementation should not
  silently exceed it.

### Data Shape

Implementation should be explicit rather than inferred from op names:

```lua
levelAbility = {
  [2] = {
    effects = "override",
    descKey = "unit.witch.ability_l2",
  },
  [3] = {
    effects = "override",
    transform = false,
    descKey = "unit.witch.ability_l3",
  },
}
```

The exact Lua shape can differ, but the important contract is:

- level-specific effects are data;
- text lives in i18n or is generated by `MechanicsText`;
- the resolver is deterministic and shared;
- level 1 remains the current base behavior unless explicitly migrated.

## Code Seams For Later Implementation

No code changes are made by this report. These are the likely seams:

1. Add a shared resolver, for example `Units.effectsFor(id, level)` or
   `src/data/unit_levels.lua`, so level-aware effects are not rebuilt ad hoc in
   `Build`, `Snapshot`, encounters, and tests.
2. Move `LEVEL_MULT` into one shared source of truth. It is currently duplicated
   in `src/scenes/build.lua` and `src/net/snapshot.lua`.
3. Update `Build:buildComp` to use leveled effects before baking auras, mimic
   copies, shield casters, command bonuses, and relics.
4. Update `Snapshot.toComp` and encounter building to use the same leveled
   effect resolver, at least for self-contained id+level effects.
5. Replace raw aura source scaling through `STAT_LEVEL_MULT` with authored
   level ability values for support units.
6. Add i18n/mechanics output for `ability_l1`, `ability_l2`, `ability_l3`, and
   optional `transform_l3`, or generate those lines from the same data.
7. Extend tests:
   - duplicate tests for stat scaling and ability scaling;
   - aura tests for level-2/3 support values;
   - snapshot tests for id+level effect reconstruction;
   - synergies tests for each new op or transform class;
   - golden update only after intentional behavior changes are accepted.

## Roster Upgrade Table

Legend:

- `T` means the level-3 row is transformative. Count: 22/110, exactly 20.0%.
- Values are first-pass balance targets. They are meant to be implemented as
  explicit data, then tuned through simulation.
- Durations and thresholds are unchanged unless the row says otherwise.

| Unit | L2 ability | L3 ability |
| --- | --- | --- |
| marauder | First strike +12; execute bonus +75%. | First strike +16; execute bonus +90%. |
| templar | Neighbor attack damage reduction 18%. | T: neighbors 24%; also gains 12% self attack damage reduction. |
| skeleton | Thorns 5. | Thorns 7. |
| bandit | Cooldown 33 frames. | T: cooldown 30 frames; first target is marked for +10% damage for 90 frames. |
| witch | Poison 3 dps. | Poison 4 dps. |
| demon | Lifesteal 55%. | Lifesteal 70%. |
| spore_tick | Poison 2 dps. | Poison 3 dps. |
| corruptor | Poison 3 dps, weaken 8%, mark +18%. | Poison 4 dps, weaken 10%, mark +20%. |
| emberling | Burn 8 dps. | Burn 10 dps. |
| razorkin | Bleed 3 dps, slow 25%. | Bleed 4 dps, slow 30%. |
| rot_hound | Rot starts 3, grows +3, cap 12. | Rot starts 4, grows +4, cap 14. |
| stormcaller | Shock cap 7, mark +15%. | Shock cap 8, mark +18%. |
| plague_doctor | Regen 4 hp/s; purge up to 5 poison stacks. | Regen 5 hp/s; purge up to 6 poison stacks. |
| cinder_cur | Burn 6 dps. | Burn 8 dps. |
| pyre_tender | Burn 13 dps. | Burn 16 dps. |
| ash_moth | Burn 9 dps, decay 40%. | Burn 11 dps, decay 35%. |
| gash_fiend | Bleed 4 dps, slow 25%. | Bleed 5 dps, slow 30%. |
| hookjaw | Bleed 2 dps, slow 35%; front multicast remains +1. | T: bleed 3 dps, slow 40%; front ally also gains +10% attack damage. |
| leech_thorn | Bleed 3 dps; thorns 5. | Bleed 4 dps; thorns 7. |
| bile_spitter | Poison 3 dps, weaken 12%. | Poison 4 dps, weaken 14%. |
| rot_grub | Poison 3 dps for 330 frames. | Poison 4 dps for 360 frames. |
| carrion_pecker | Rot starts 3, grows +3, cap 8; heal on kill 6. | Rot starts 4, grows +4, cap 10; heal on kill 8. |
| maggot_king | Rot starts 3, grows +3, cap 14; neighbor attack aura +25%. | T: rot starts 4, grows +4, cap 16; neighbors also apply weak rot, 1 dps for 180 frames. |
| necro_leech | Rot starts 3, grows +3, max-hp gnaw 40%. | Rot starts 4, grows +4, max-hp gnaw 45%. |
| soot_acolyte | Neighbor burn increase +75%. | Neighbor burn increase +100%. |
| clot_mender | Grants neighbor bleed 2 dps, slow 12%. | Grants neighbor bleed 3 dps, slow 15%. |
| miasma_acolyte | Neighbor poison increase +75%. | Neighbor poison increase +100%. |
| decay_tender | Neighbor rot growth +2. | Neighbor rot growth +3. |
| bellows_priest | Burn 8 dps; neighbor haste 16%. | Burn 10 dps; neighbor haste 20%. |
| wildfire_hound | Burn 7 dps; death spread keeps 80% of burn load. | T: burn 9 dps; death spread can hit up to 2 nearby enemies. |
| kiln_warden | Burn 7 dps; weaker burns extend by 210 frames. | Burn 9 dps; weaker burns extend by 240 frames. |
| bloodletter | Bleed 3 dps; aggravate x2.25. | T: bleed 4 dps; aggravate x2.5 and a death burst spreads 1 bleed stack to a neighbor. |
| tendon_render | Bleed 3 dps; base slow 20%. | Bleed 4 dps; base slow 25%. |
| vein_splitter | Bleed 6 dps. | Bleed 8 dps. |
| plague_bearer | Poison 3 dps; spread stack 2 dps. | T: poison 4 dps; spread stack 3 dps to up to 2 nearby enemies. |
| acid_maw | Poison 3 dps; shield eat 40%. | Poison 4 dps; shield eat 50%. |
| patient_worm | Rot starts 3, passive ramp +2, cap 12. | Rot starts 4, passive ramp +3, cap 14. |
| hollow_gut | Rot starts 3, grows +3; heals for 60% of max-hp amputation. | Rot starts 4, grows +4; heals for 75% of max-hp amputation. |
| blight_spreader | Rot starts 2, grows +2; death spread rot starts 3. | Rot starts 3, grows +3; death spread rot starts 4. |
| ash_maw | Burn 8 dps; team burn still has no decay. | T: burn 10 dps; team burns with no decay also refresh 60 frames on enemy death. |
| plague_pyre | Burn 7 dps; death-spread poison seed 3 dps. | Burn 9 dps; death-spread poison seed 4 dps. |
| slow_bleed | Bleed 3 dps; enemy team slow 15%. | T: bleed 4 dps; enemy team slow 18% and starts with a 1 dps bleed. |
| marrow_drinker | Convert bleed into rot: base 4, growth +3, cap 14. | Convert bleed into rot: base 5, growth +4, cap 16. |
| festering | Poison 3 dps; team poison duration +90 frames and no cap. | T: poison 4 dps; team poison duration +120 frames, no cap, and poisoned enemy deaths spread 1 poison stack. |
| venom_censer | Poison 3 dps; ignite burst 12 dps at 5 stacks. | Poison 4 dps; ignite burst 14 dps at 5 stacks. |
| pit_maw | Rot starts 2, grows +2; enemy team starts with stronger rot. | T: rot starts 3, grows +3; first rotting enemy death spreads rot to its neighbors. |
| wither_bloom | Rot 3 dps, slow 20%, weaken 14%. | Rot 4 dps, slow 25%, weaken 18%. |
| gravewarden | Thorns 6. | T: thorns 8; while alive, adjacent backline allies take 10% less attack damage. |
| live_wire | Shock cap 6. | Shock cap 8. |
| thunderhead | Shock volt 8, cap 4. | Shock volt 10, cap 5. |
| static_swarm | Shock cap 10, duration 270 frames. | Shock cap 12, duration 300 frames. |
| galvanizer | First strike +9; shock cap 8. | First strike +12; shock cap 10. |
| stormlord | Shock cap 10, volt 5. | Shock cap 12, volt 6. |
| dynamo_priest | Shock transfer 60%, cap 7. | Shock transfer 75%, cap 8. |
| arc_warden | Shock volt 5, cap 7, chains to 2. | T: shock volt 6, cap 8, chains to 3. |
| storm_anchor | Shock persist 65%, cap 9. | Shock persist 80%, cap 10. |
| shieldbearer | Neighbor shield 9. | Neighbor shield 12. |
| aegis_warden | Neighbor shield 14; thorns 6. | Neighbor shield 18; thorns 8. |
| oath_keeper | Neighbor shield 24. | Neighbor shield 30. |
| bulwark_acolyte | Neighbor shield 12. | Neighbor shield 16. |
| ward_weaver | Periodic shield 28 every 240 frames. | T: periodic shield 36 every 210 frames and also shields self. |
| barrier_savant | Adjacent ward-caster value +75%, cooldown reduction 30%. | Adjacent ward-caster value +100%, cooldown reduction 35%. |
| mirror_ward | Adjacent ward-caster reflect 50%, radius stays on. | T: reflect 60%; attackers damaged by reflection are marked +10% damage for 90 frames. |
| surge_warden | Adjacent ward-caster value +75%; overcharge cap 2.5x. | Adjacent ward-caster value +100%; overcharge cap 3x. |
| siege_breaker | Strip shield 60%; cleave 60%. | T: strip shield 70%; cleave 70% and cleave also strips shields from splash targets. |
| chitin_drone | Poison 3 dps. | Poison 4 dps. |
| bore_worm | Rot starts 3, grows +3, cap 10. | Rot starts 4, grows +4, cap 12. |
| wailing_shade | Bleed 3 dps, slow 20%. | Bleed 4 dps, slow 25%. |
| pyre_herald | Burn 8 dps. | Burn 10 dps. |
| byakhee | Bleed 4 dps, slow 15%. | Bleed 5 dps, slow 20%. |
| zeal_inquisitor | Burn 7 dps; neighbor attack aura +16%. | Burn 9 dps; neighbor attack aura +20%. |
| coil_viper | Main poison 4 dps; clean-target poison 2 dps. | Main poison 5 dps; clean-target poison 3 dps. |
| web_recluse | Poison 3 dps for 220 frames. | Poison 4 dps for 240 frames. |
| siphon_jelly | Shock cap 6. | Shock cap 8. |
| skull_colossus | Burn 6 dps; heal on kill 12. | T: burn 8 dps; heal on kill 16 and heals the weakest adjacent ally for 8. |
| rust_sentinel | Shock cap 7. | Shock cap 8. |
| runestone_golem | Neighbor shield 16. | Neighbor shield 20. |
| ink_horror | Poison 4 dps. | Poison 6 dps. |
| deep_kraken | Poison 6 dps. | Poison 8 dps. |
| husk | Stubborn hide: self attack damage reduction 8%. | Stubborn hide: self attack damage reduction 12%. |
| gnaw_rat | Bleed 2 dps, slow 10%. | Bleed 3 dps, slow 12%. |
| footman | Line drill: ally directly behind deals +6% attack damage. | Line drill: ally directly behind deals +10% attack damage. |
| mire_thing | Ooze mass: starts with 6 shield. | Ooze mass: starts with 10 shield. |
| flesh_warband | Flesh allies deal +15% attack damage. | Flesh allies deal +20% attack damage. |
| bone_choir | Bone allies take 12% less attack damage. | Bone allies take 16% less attack damage. |
| arcane_seer | Arcane allies attack 12% faster. | Arcane allies attack 16% faster. |
| abyss_maw | Abyss allies' poison +22%. | Abyss allies' poison +30%. |
| order_marshal | Order allies regenerate 3 hp/s. | Order allies regenerate 4 hp/s. |
| prism_horror | Per unique type: +3 damage and +6 hp. | T: per unique type: +4 damage and +8 hp; at 5 types, team gets +8% attack damage. |
| brood_mother | Spiderling token stats +50%. | T: spiderling token stats +100% and its bites poison 1 dps. |
| larval_host | Grubling token stats +50%. | Grubling token stats +100%. |
| spore_sac | Poison 3 dps; sporeling poison bite 1 dps. | Poison 4 dps; sporeling poison bite 2 dps. |
| rat_warren | Ratling token stats +50%. | Ratling token stats +100%. |
| pit_shepherd | Boneling token stats +50%. | Boneling token stats +100%. |
| carrion_choir | On ally death: +3 damage, cap +12. | On ally death: +4 damage, cap +16. |
| bone_harvest | On ally death: +5 max hp, cap +18. | On ally death: +6 max hp, cap +24. |
| mimic_spawn | Copied on-hit values are 120% of source values. | T: copies the ally ahead plus one strongest adjacent on-hit effect, depth 1 only. |
| echo_flesh | Copied on-hit values are 120% of source values. | Copied on-hit values are 140% of source values. |
| hollow_crown | Amplifies resolved auras by 30%. | T: amplifies resolved auras by 40%; overflow beyond caps becomes +5 shield on affected allies. |
| headsman | Execute bonus +110%. | Execute bonus +140%. |
| culler | Percent-hp strike 12%, cap 14. | Percent-hp strike 14%, cap 14. |
| wallbreaker | Strip shield 50%; percent-hp strike 10%, cap 14. | Strip shield 60%; percent-hp strike 12%, cap 14. |
| siege_titan | Percent-hp strike 12%, cap 14. | Percent-hp strike 14%, cap 14. |
| reaper_shade | Team execute +40%. | T: team execute +50%; execute kills grant your team +5% haste for 180 frames. |
| vanguard_drummer | Ally behind gets +22% attack damage. | Ally behind gets +30% attack damage. |
| rear_goad | Ally ahead gets +18% haste. | Ally ahead gets +24% haste. |
| spine_column | Allies above and below get 18% attack damage reduction. | Allies above and below get 24% attack damage reduction. |
| tide_caller_v2 | Ally ahead gets +1 multicast and +10% attack damage. | Ally ahead gets +2 multicast and +20% attack damage, capped by multicast max. |
| storm_conductor | Neighbor haste 15%; own shock cap 7. | Neighbor haste 20%; own shock cap 8. |
| echo_warden | Center unit gets +1 multicast and +10% attack damage. | Center unit gets +2 multicast and +20% attack damage, capped by multicast max. |

## Balance Risks

1. Double scaling: stats already reach 3x at level 3. Ability scaling on top can
   turn a normal three-star into a hard counterless unit. Treat the table as
   starting data and tune with outlier detection.
2. Dot cliffs: poison no-cap, burn no-decay, rot max-hp erosion, and shock chain
   become dangerous when level scaling increases application rate and payoff.
   Watch TTK p10 and status damage share.
3. Support snowball: support units in the center already affect many targets.
   Replacing current `LEVEL_MULT` aura scaling with authored ability values is
   the safer long-term route.
4. Integer mechanics: multicast, summons, mimic copies, taunt, no-cap, and
   no-decay must not scale mechanically unless authored. Those are the primary
   sources of infinite-loop or one-shot risk.
5. Transform density: 22 transforms is enough to make level 3 exciting without
   making every card a rules rewrite. Do not raise this ratio until the UI can
   explain it cleanly.
6. Snapshot fairness: id+level ability resolution is safe for async ghosts, but
   graph-baked aura behavior still needs the existing snapshot aura/relic debt
   resolved before parity is complete.

## Simulation And Validation Plan

Commands run for this report:

```sh
luajit tests/duplicates.lua
luajit tests/synergies.lua
luajit tests/run.lua
luajit tests/snapshot.lua
```

All four passed.

I did not run `tools/sim.lua` because it writes `runs/report.json`, and this
task's write scope allows only this audit document. After implementation, run:

```sh
luajit tests/duplicates.lua
luajit tests/auras.lua
luajit tests/synergies.lua
luajit tests/snapshot.lua
luajit tests/golden.lua
luajit tests/props.lua
luajit tools/sim.lua 400
luajit tools/sim.lua invest 300
luajit tools/sim.lua godroll 300
luajit tools/sim.lua counter 300
sh tools/check.sh
```

Acceptance targets for the first implementation pass:

- no unit outside roughly 2 sigma without an intentional matchup reason;
- TTK p10 does not collapse under burst/multicast boards;
- TTK p90 remains below fatigue for most non-tank mirrors;
- status damage share stays meaningful but not dominant;
- transform units show high synergy lift only with intended partners;
- snapshot replay still reconstructs the same level ability from id+level.

## UI And Card Wording

The card should not print three full rules paragraphs. Use one current-level
line, one compact progression line, and a transform badge only when needed.

Recommended card pattern:

```text
POISON
Strikes poison for 3/s.
II 3/s  |  III 4/s
```

For transforms:

```text
CONTAGION
Strikes poison for 3/s and spreads 2/s.
III AWAKENED: spreads to two nearby enemies.
```

Build/shop details:

- In the shop, if buying would complete a merge, show `MERGE -> II` or
  `MERGE -> III` and the next ability number.
- On board hover, show current values first, next-level values second.
- Use the existing pips for level state; add a small `AWAKENED III` chip only
  for the 22 transform units.
- For support cards, always name the target before the value:
  `Adjacent allies: burn +75%`, `Flesh allies: attack +15%`.
- For binary mechanics, avoid fake multiplication:
  `Taunt. Thorns 8.` is better than `Taunt x2`.
- Generated `MechanicsText` should be preferred for numeric lines so i18n does
  not duplicate 330 hand-written values. Flavor can stay separate.

## Phased Implementation Plan

1. Data pass: add explicit level ability data for a small pilot set:
   `witch`, `skeleton`, `soot_acolyte`, `hookjaw`, `gravewarden`,
   `mimic_spawn`.
2. Resolver pass: centralize `STAT_LEVEL_MULT` and implement
   `effectsFor(id, level)` without changing level-1 output.
3. Build pass: route `Build:buildComp`, aura baking, mimic copying, commander
   bonuses, and shield caster setup through the resolver.
4. Snapshot pass: route `Snapshot.toComp` through the same resolver for
   id+level effects.
5. UI pass: add current/next/awakened card lines and merge previews.
6. Test pass: expand duplicate, aura, synergy, snapshot, and golden coverage.
7. Roster pass: fill the full 110-unit table in waves by effect family, then run
   sim and tune one lever at a time.

Do not implement all 22 transforms in the first code increment. Start with one
numeric-only unit, one support aura, one integer mechanic, and one transform to
validate the data shape and UI before broad content migration.
