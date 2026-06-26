# Codex Wrapper: sound-designer

Source brief: `.claude/agents/sound-designer.md`

Use this wrapper for procedural audio, SFX recipes, audio director work, reverb,
pitch jitter, ambience, and audible cues for UI or combat events.

Before acting, read:

1. `CLAUDE.md`
2. `.codex/agent-routing.md`
3. `.claude/agents/sound-designer.md`
4. relevant Feel Lab synth/SFX files
5. touched `src/audio/` and cue call sites

Codex-specific rules:

- Interaction audio co-routes with `.codex/agents/game-feel-engineer.md`.
- UI cues should align with `.codex/agents/ui-artisan.md` when the surface is
  being changed.
- Audio is render/cosmetic only. It must be headless-safe and a no-op under the
  mock LÖVE environment.
- Verify LÖVE audio APIs on primary sources before coding.
- Do not add sampled audio assets unless the user explicitly changes the
  procedural-audio constraint.
- Preserve existing user edits in the dirty worktree.

Validation:

Use syntax checks and `sh tools/check.sh`. Do not claim the sound is good by ear
unless it was actually listened to by the user or in a real local run.
