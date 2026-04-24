# D2. Typography - P0

## Sources
- Monaspace official site: https://monaspace.githubnext.com/
- Monaspace GitHub: https://github.com/githubnext/monaspace
- JetBrains Mono official page: https://www.jetbrains.com/lp/mono/
- JetBrains Mono GitHub: https://github.com/JetBrains/JetBrainsMono
- W3C WCAG contrast minimum: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html

## Findings
- Monaspace is a good primary choice because it is a monospace superfamily rather than a single face. Its five related variants allow tone shifts without breaking grid alignment. That is useful for a terminal RPG where logs, stats, headings, flavor, and item names should feel related but not identical.
- JetBrains Mono is the right fallback: mature, readable, open, code-oriented, and widely recognized. It should be the fallback for browsers/platforms where Monaspace has issues.
- Font variety should be functional, not decorative. Too many variants in one panel will produce visual noise. The safe pattern is one default UI face, one display/system face, and one flavor face used sparingly.
- The type scale should be small and disciplined. Terminal UIs become unreadable when every stat has its own size. Use weight, dimming, brackets, and alignment more often than large type changes.
- Accessibility interacts with typography. Body text at 12px may look authentic but will be fatiguing. Use 14px as the real body floor on desktop; reserve 12px for labels, timestamps, and metadata.

## Recommendation for The Pit
- Font stack:
  - Primary: `Monaspace Neon`.
  - Headings/system labels: `Monaspace Krypton` or `Monaspace Neon` bold.
  - Narrative/event flavor: `Monaspace Argon`.
  - Item names or rare callouts: `Monaspace Xenon` sparingly.
  - Avoid `Monaspace Radon` for core UI; use only for rare handwritten/corrupted flavor if tested.
  - Fallback: `JetBrains Mono`, then `ui-monospace`, `SFMono-Regular`, `Menlo`, `Consolas`, monospace.
- Type scale:
  - 12px: timestamps, hotkeys, short tags, metadata.
  - 14px: default body, tables, card text, logs.
  - 16px: important values, selected node, card title in detail view.
  - 20px: panel headings, modal titles.
  - 24px: splash/title only.
- Line height:
  - Dense tables/logs: 1.25-1.35.
  - Paragraph/event text: 1.45-1.6.
  - Buttons/cards: 1.2-1.35.
- Letter spacing:
  - Default: 0.
  - Small caps/labels: 0.02em-0.06em.
  - Avoid wide tracking on body text.
- CSS implementation notes:
  - Enable tabular numbers where available.
  - Disable ligatures in stat tables if they alter perceived alignment.
  - Test box drawing and fallback fonts early; not all monospace fonts align border glyphs identically.
  - Body text must meet WCAG AA contrast: 4.5:1 minimum.
