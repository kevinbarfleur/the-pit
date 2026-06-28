# The Pit — Feel Lab

Standalone LÖVE lab for UI/game-feel iteration. It is no longer the primary
research dump; it is a playable workbench for validating feedback against the
current The Pit design system.

## Run

```sh
love feel-lab
love feel-lab --shoot
```

Controls:

- `Esc`: back / close
- `F11`: fullscreen
- `F9`: toggle nightmare shader
- mouse: hover, click, drag everything interactive

`--shoot` writes PNG files to:

```text
~/Library/Application Support/LOVE/the-pit-feel-lab/shots/
```

## Active Rooms

- `Feedback Contract`: source of truth for action feedback. It maps each action
  to motion, sound, delay, payoff, and failure response.
- `Real Components`: current buttons, slots, panels, drag/drop and score punch
  using the real The Pit component copies in `feel-lab/src`.
- `Combat Impact`: clean impact bench for attack motion, damage numbers,
  hitstop, trauma, particles, and sound magnitude.
- `Particle Forge`: dedicated explosion bench for level-up validation, relic
  seals, impact blooms, death bursts, and slot unlocks.
- `Level-Up / Fusion`: merge choreography workbench.
- `SFX Vocabulary`: semantic soundboard. Oneiric is the default identity; other
  packs are comparison tools only.

## Current Principles

- The lab follows the current Build/Grimoire visual language: dense, restrained,
  readable, with payoff reserved for important actions.
- Shader is off by default so components can be inspected clearly. Toggle `F9`
  only when judging final mood.
- The active lab uses current `src.ui`-style atoms only. If a needed component
  does not exist yet, build it in that language before experimenting with it.
- Feel/audio/render stay presentation-only. They never mutate SIM state.

## Docs

- `docs/feedback-contract.md`
- `docs/current-state.md`
