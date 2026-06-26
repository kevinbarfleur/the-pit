# Audit projet - 2026-06-26

Cet audit part de l'etat courant du repo au 2026-06-26. Il ne remplace pas
`CLAUDE.md`, qui reste la source de verite projet. Il sert a documenter ce qui
est solide, ce qui derive, et les prochains axes de consolidation avant que le
projet devienne difficile a maintenir.

## Documents

- [Synthese](2026-06-26-synthese.md) : verdict global, risques majeurs, priorites.
- [Architecture technique](2026-06-26-architecture-technique.md) : LÖVE/Lua, determinisme,
  modularite, fichiers a risque, performance.
- [UI, feel, audio](2026-06-26-ui-feel-audio.md) : coherence visuelle, design system,
  transitions, game feel, son.
- [Economie de run](2026-06-26-economie-run.md) : diagnostic sur l'or,
  la boutique, l'XP, les slots, et la comparaison SAP/Batomon/TFT.
- [Roadmap actionnable](2026-06-26-roadmap.md) : plan par phases, criteres d'acceptation.

## Verifications lancees

- `sh tools/check.sh` : OK.
- `love . --shoot=all --shoot-size=1280x720` : OK.
- Captures inspectees manuellement dans :
  `/Users/kevinbarfleur/Library/Application Support/LOVE/the-pit/shots/`

Captures regardees en priorite : `menu`, `build`, `combat`, `summary`,
`relicpick`, `grimoire_relics`, `designsystem`, `system`, `settings`,
`commander_hover`, `build_relic_hover`.

## Sources externes utilisees

Sources techniques primaires ou quasi primaires :

- LÖVE 11.5 API table : https://raw.githubusercontent.com/love2d-community/love-api/master/love_api.lua
- LÖVE wiki canonique : https://love2d.org/wiki/love.run, https://love2d.org/wiki/love.update,
  https://love2d.org/wiki/love.conf, https://love2d.org/wiki/love.graphics.setColor,
  https://love2d.org/wiki/love.graphics.newCanvas, https://love2d.org/wiki/love.audio.newSource,
  https://love2d.org/wiki/love.sound.newSoundData
- Lua 5.1 Reference Manual : https://www.lua.org/manual/5.1/manual.html
- Fixed timestep : https://gafferongames.com/post/fix_your_timestep/
- Game loop : https://gameprogrammingpatterns.com/game-loop.html

Sources/recherches internes consultees pendant l'audit initial :

- `CLAUDE.md`
- `.codex/agent-routing.md`
- `.codex/agents/love2d-engineer.md`, `.codex/agents/ui-artisan.md`,
  `.codex/agents/game-feel-engineer.md`, `.codex/agents/sound-designer.md`,
  `.codex/agents/autobattler-designer.md`, `.codex/agents/asset-forge.md`
- `docs/research/love2d-tech.md`
- `docs/research/engine-architecture.md`
- `docs/research/game-ui-implementation.md`

Note: plusieurs anciennes sources consultees pendant l'audit ont ensuite ete
retirees du dossier actif. Les rapports ci-dessus restent les syntheses a lire;
ne pas chercher a recharger les anciens dossiers `docs/design`, `docs/base-game`,
`docs/roadmap-lab`, `docs/research/sap` ou `docs/research/batomon`.
