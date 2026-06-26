# Feel Lab — Pipeline pixel + postfx du jeu (cartographie, pour matcher)

> Read-only de `src/core/sprite.lua`, `src/render/postfx.lua`, `affliction_fx.lua`, `arena_draw.lua`, `main.lua`.

## Le bake de sprites — `src/core/sprite.lua`
`Sprite.bake(grid, palette) -> { image, w, h }` : `love.image.newImageData(w,h)` (transparent) → `setPixel` par
char (palette `{r,g,b,a}` floats, '.'/absent = transparent) → `love.graphics.newImage(data)` → **`setFilter("nearest","nearest")`**.
C'est la technique réutilisée pour baker les sprites de particules (`feel-lab/lib/sprite.lua`).

## Rampes Wraeclast par affliction (déjà dans `affliction_fx.lua`)
| Famille | rampe (clair→sombre) | hex clés |
|---|---|---|
| burn | flameHi `0xf7d048` → burn `0xe0792e` → ember `0xc4663a` | montée chaude |
| bleed | bleed `0xd8475e` → bleedDeep `0x6a1414` | sang vif → séché |
| poison | poisonHi (lit ×1.4) → poison `0x93c12f` | |
| rot | rot `0xa86fc4` ↔ rotBrown `0x4a2c1a` | violet ↔ chair |
| shock | blanc cœur → shock `0xf2d24a` | jaune électrique |
| gold/ember (level-up) | gold `0xcda14c` · ember `0xc4663a` · ivoire `0xd8cfae` | |

## Le shader postfx — `src/render/postfx.lua` (reproduit dans `feel-lab/lib/postfx.lua`)
Applique 1:1 sur toute la frame native (texte intact). Composants + valeurs **vérifiées** :
- **Dither Bayer 4×4** (`postfx.lua:123`) : matrice `0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5`, normalisée /16, par **pixel écran** ;
  `col += (bayer4(sc)-0.5) * (6/255) * strength` → gravure 1-bit sans banding.
- **Grain** : `col += (hash21(sc + time*{53,71}) - 0.5) * (0.026 + ...)` (animé, non-seedé = RENDER pur).
- **Palette-lock** : ombres → `void 0x050308` (abysse), hautes → `ember 0xc4663a` (braise), dérive mid → `rot 0xa86fc4` (violet), faible (×0.14/0.10/0.05).
- **Aberration chromatique** radiale (∝ r², ~1px aux bords) · **vignette** (se ferme avec la tension) · displacement onirique des bordures UI (omis dans le lab).

## RÉVÉLATION : à quelle résolution les FX du jeu sont rendus
Le monde combat/build est `nativeWorld=true` → rendu **en résolution écran** (translate ox/oy + `scale`), PAS dans
le canvas 320×180. Les FX du jeu (death burst, affliction_fx, dmgNumbers, sparks) sont donc dessinés là — mais en
**petits rects 1-2 px** (coords virtuelles ×`scale` = blocs nets) + **palette** + **le postfx dither/grain par-dessus**.
⟹ le « pixel » ne vient PAS d'un canvas basse-réso pour les FX, mais de : **petites formes carrées + palette + le
shader d'engraving global**. C'est exactement la recette appliquée au lab (sprites bakés snappés + postfx).

## VFX existants (à dépasser)
Death burst (`arena_draw.lua:139`) : 10 fragments 1-2px, blood/bloodDeep alternés, gravité 0.09, 16-28 frames, additif.
Sparks impact : `circle("line")` rayon croissant (lisse — à refaire chunky). dmgNumbers : texte qui monte (gravité 0.05).
Affliction_fx : flammes/bulles/spores en **rects 1-2px** additifs, fade-in 2-3f + tail 40 %, jitter déterministe (Weyl, pas RNG).

## Conventions pixel (docs/pixel-art)
nearest obligatoire · coords entières · dither Bayer post-blit · palette lockée (jamais primaire pure) · glow additif
LÉGER (jamais blanc) · fade-in/tail-out (jamais alpha=1 partout) · tailles 1-4px conservatrices (ne pas noyer le sprite 64px).
