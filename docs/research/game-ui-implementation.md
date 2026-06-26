# Historical UI implementation guide

Status: superseded / historical.

This path is kept because UI briefs and older code comments still reference it.
Do not treat the old long guide as the current UI source of truth.

Current UI sources:

- `../../CLAUDE.md`
- `../README.md`
- `../audit/2026-06-26-ui-feel-audio.md`
- `../pixel-art/design-system-source.html`
- `../pixel-art/design-system-spec.md`
- `src/ui/*`

Current rules:

- reuse existing UI primitives before inventing new ones;
- feedback on hover/click/drag is part of done;
- measure text and avoid truncating unreadable mechanics;
- screenshots are required for visual/UI completion when possible;
- current viewport behavior is responsive and must be verified in captures,
  not assumed from old pixel-perfect notes.
