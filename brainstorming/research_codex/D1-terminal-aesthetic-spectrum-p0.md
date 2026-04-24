# D1. Terminal Aesthetic Spectrum - P0

## Sources
- Cogmind official site: https://www.gridsagegames.com/cogmind/
- Dwarf Fortress Wiki, Tileset repository: https://dwarffortresswiki.org/Tileset_repository
- Loop Hero Wiki, Cards: https://loophero.fandom.com/wiki/Cards
- Cultist Simulator Wiki, Cards: https://cultistsimulator.fandom.com/wiki/Cards
- Monaspace official site: https://monaspace.githubnext.com/

## Findings
- Strict ASCII is coherent but expensive in usability. A full monospace grid makes layout, animation, responsive scaling, and modern controls harder. It also risks narrowing the audience before the core loop has proven itself.
- Cogmind is the best high-end terminal reference: it proves that terminal UI can be animated, readable, and combat-rich. The lesson is not to copy full ASCII, but to treat grid discipline, particles, logs, and color-coded state as first-class game feel.
- Dwarf Fortress tilesets show a long-standing pattern: ASCII logic and tile/pixel representation can coexist. The Pit can use ASCII containers and glyph language while still rendering enemy sprites or card art inside panels.
- Loop Hero and Cultist Simulator are stronger references for hybrid readability. They use cards, text, and symbolic assets to make complex systems tangible. The Pit needs the same clarity because the player must compare cards, resources, node rewards, and risk quickly.
- A terminal-inspired UI should avoid app-like softness: too many rounded cards, gradients, shadows, and spring animations will fight the theme. But real buttons, hover states, tooltips, and modern accessibility are still required.

## Recommendation for The Pit
- Choose `hybrid terminal` for MVP.
- Use DOM/React for:
  - Navigation, panels, card grid, inventory, upgrade tables, logs, tooltips, modals.
- Use PixiJS for:
  - Combat visualization, damage numbers, enemy intent effects, loot bursts, hit flashes.
- Use the terminal language in the component kit:
  - Box panels with single-line ASCII borders.
  - Important modals with double-line flavor borders.
  - Logs as timestamped terminal output.
  - Progress bars as text-first bars, not glossy meters.
  - Cards as bordered terminal blocks with rarity glyphs and tags.
- Do not ship pure text combat unless scope forces it. Minimum combat visual should include enemy name, intent, HP bar, attack log, hit flash, and floating number layer.
- Pixel sprites: allow them, but contain them. Use 32x32 or 48x48 sprites inside ASCII panels. Keep cards mostly typographic for MVP unless art exists already.
- Visual rule: terminal structure, modern usability, limited pixel art accents. If a UI element would look natural in Warp/Zed/k9s and still fit a dungeon roguelite, it is probably on target.
