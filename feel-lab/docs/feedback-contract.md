# Feel Lab — Feedback Contract

Status: active source for feel iteration.

The lab exists to validate presentation feedback before it is ported to the real
game. It must follow the current Build and Grimoire visual language: dense,
readable, restrained, with strong payoff only on important actions.

## Rule

An interaction is not done until it has:

- immediate motion on pointer-down or hover;
- an audible cue from the shared SFX vocabulary;
- a clear delay policy when the action changes state or scene;
- a payoff that communicates what mechanically happened;
- a failure response that is quieter than success but still readable.

## Current Contract

| Action | Immediate visual | Sound | Delay | Payoff | Failure |
| --- | --- | --- | --- | --- | --- |
| Hover button | lift + glow | `hover` | 0 | none | none |
| Press CTA | sink + ember flash + eyes close | `press` | ~0.80s | scene/action fires | disabled stays quiet |
| Buy unit | gold punch + offer reaction | `coin` | ~0.12s | unit settles | `error`, no spend |
| Drag pickup | lift + shadow + tilt | `pickup` | 0 | piece follows hand | none |
| Drop valid | socket glow + piece nudge | `place` | ~0.08s | piece locks to grid | `drop` + return spring |
| Merge/level-up | convergence + ring + hitstop | `ladder` + `success` | staged | level text + relic offer armed | none |
| Relic pick | card seal + glow settle | `success` | ~0.16s | return to build | refuse only if explicit |
| Combat hit | damage number + impact flash | `thud` | 0 | HP delta readable | smaller cue for blocked/miss |
| Unlock slot | locked socket opens | `unlock` | ~0.14s | new adjacency space | level max state |

## Rooms

- `Feedback Contract`: first stop; validates action contracts.
- `Real Components`: checks current buttons, slots, panels, drag/drop.
- `Combat Impact`: validates attack motion, damage numbers, hitstop, trauma,
  particles, and sound magnitude.
- `Particle Forge`: validates exportable particle/explosion presets for
  level-up, relic seal, heavy impact, death, and unlock payoffs.
- `Level-Up / Fusion`: experiments on merge choreography.
- `SFX Vocabulary`: auditions semantic cues, with Oneiric as default.

## Porting Rule

When a behavior is validated here, port the smallest reusable part to `src/`:

- motion/timing: `src/ui/feel.lua`, `src/ui/juice.lua`, or `src/ui/drag.lua`;
- UI surface: existing `src/ui/*` atoms first; create the missing atom if the
  current design language needs it;
- sound: semantic cue through `src/audio/sfx.lua`;
- particles/explosions: validate in `Particle Forge`, then port the preset
  shape instead of recreating ad hoc bursts;
- build merge: `Build:spawnMergeFx` and its existing particle path;
- combat impact: render-side combat drawing only, never SIM.
