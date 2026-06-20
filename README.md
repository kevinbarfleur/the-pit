# The Pit

Autobattler **multijoueur asynchrone** en **Lua + LÖVE (Love2D)**, dont tous les visuels sont
**générés procéduralement** (pixel art en grilles + palette, aucun asset dessiné). Univers
grimdark cryptique : Cthulhu × Path of Exile × Dark Souls. On descend *Le Puits*.

> v0 actuelle = **playground** : des créatures riggées s'attaquent automatiquement au cooldown,
> avec dégâts, mort en fondu et relance de bataille. Le but : éprouver le moteur de rendu/rig.

## Lancer

```sh
love .                      # nécessite LÖVE 11.5  (brew install --cask love)
```
Contrôles : `espace` reset · `b` os (debug pivots) · `p` pause · `echap` quitter.

## Tester (sans écran)

```sh
luajit tests/headless.lua   # smoke test : mocke LÖVE et exécute la vraie logique
```

## Repère

- `CLAUDE.md` — brief permanent du projet (vision, design, décisions techniques, archi).
- `docs/research/` — recherches détaillées (game design des autobattlers + technique LÖVE).
- `docs/pixel-art/` — conventions du moteur de rig + pipeline pixel art procédural.
- `src/` — code (core / data / combat / fx / scenes). Voir `CLAUDE.md` §5.

## Stack

LÖVE 11.5 · LuaJIT · zéro dépendance externe · rendu canvas virtuel 320×180 scalé ×4 ·
boucle à pas de temps fixe (combat déterministe) · sprites bakés une fois en `Image` nearest.
