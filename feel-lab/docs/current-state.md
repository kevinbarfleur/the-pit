# Feel Lab — Current State

Updated: 2026-06-27.

The previous research notes in this folder were removed from the active lab
because they described an earlier project state. The real game now already has
the main transplants: `src/ui/feel.lua`, `src/ui/juice.lua`, procedural
`src/audio/sfx.lua`, build merge particles, current Build chrome, and the
Grimoire grid/card language.

## Active Direction

The lab should no longer answer "which style should the game have?" The style is
the current The Pit design system. The lab should answer narrower questions:

- is this action readable at the exact moment it fires?
- does the sound match the visual magnitude?
- is the delay long enough to feel, but short enough to stay responsive?
- does the payoff look important only when the action is important?
- can the effect be ported without touching SIM state?

## Cleanup Decisions

- Shader is off by default in the lab so UI can be inspected clearly. Use `F9`
  only when judging final mood.
- Oneiric is the default sound identity. Other packs remain comparison tools.
- The active lab must use current `src.ui`-style atoms only. Missing components
  are built in that language before they become test material.
- The menu prioritizes `Feedback Contract`, `Real Components`, `Combat Impact`,
  `Particle Forge`, `Level-Up / Fusion`, and `SFX Vocabulary`.
- Explosion work lives in `Particle Forge` first. Other rooms should consume
  those presets instead of inventing one-off particle language.
- Transition/modal prototypes are not part of the active surface.

## Validation

Run:

```sh
love feel-lab --shoot
```

Inspect:

```text
~/Library/Application Support/LOVE/the-pit-feel-lab/shots/
```

For a production port, also run the game captures:

```sh
love . --shoot=all --shoot-size=1280x720
```
