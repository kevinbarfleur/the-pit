# Recherche technique — LÖVE / Lua / pixel art procédural

> Rapport de recherche vérifié sur sources primaires (wiki LÖVE, manuel Lua, dev blogs).
> Sert de référence aux décisions techniques de `CLAUDE.md`. Cible : **LÖVE 11.5**.

## Résumé

- **Version LÖVE** : **11.5 "Mysterious Mysteries"** (stable, déc. 2023) = baseline. 12.0
  "Bestest Friend" en dev (nightlies) mais non officielle. Toutes les APIs ci-dessous existent
  en 11.5.
- LÖVE n'a **pas de scene graph** : les Containers PixiJS se mappent exactement sur la
  transform/matrix stack (`push`/`translate`/`rotate`/`scale`/`pop`). Port propre.
- **Ne pas dessiner un `rectangle()` par pixel par frame** : baker chaque part une fois en
  Canvas/Image, puis dessiner la texture transformée. Décision perf #1.
- Combat déterministe : surcharger `love.run` avec un **accumulateur à pas fixe** + générateurs
  RNG **seedés** (`RandomGenerator`), pas `math.random`.
- Dépendances minimales : `rxi/classic` (~120 LOC) au plus. Éviter `anim8` (frame-based).

## 1. Structure, boucle & packaging

Boot : `conf.lua` → modules → `main.lua` → `love.load()` une fois → boucle `love.update(dt)` +
`love.draw()`. Pas d'entrée `main()`, on définit des callbacks globaux sur la table `love`.

`conf.lua` (doit vivre là, pas dans main.lua) — pièges 11.x : `t.window.vsync` est un **nombre**
(−1/0/1), couleurs en **floats 0..1**. On peut désactiver `physics`/`joystick` pour accélérer le
démarrage.

Modules : un fichier retourne une table ; `require("src.foo")` (points = séparateurs, sans
`.lua`). LÖVE ajoute la racine du jeu à `package.path`.

Lancement : `love .` (dossier contenant `main.lua`). `.love` = ZIP du projet renommé. Fusion exe :
concat `love.exe + game.love`. Outils : makelove / love-build.

Sources : [love.run](https://love2d.org/wiki/love.run) · [Config_Files](https://love2d.org/wiki/Config_Files) · [Game_Distribution](https://love2d.org/wiki/Game_Distribution)

## 2. Rendu pixel-perfect

- `love.graphics.setDefaultFilter("nearest","nearest")` **avant** de créer toute texture (sinon
  flou bilinéaire). Par texture : `Texture:setFilter("nearest","nearest")`.
- `love.graphics.setLineStyle("rough")`, `setLineWidth(1)`. NB : taille points/lignes en pixels,
  **non** affectée par `scale` (11.0) → préférer `rectangle("fill",…)` pour des cellules.
- **Viewport** : le pattern canvas basse resolution + scale entier reste une option pixel-perfect,
  mais le projet actuel utilise un viewport responsive/fill (`src/ui/viewport.lua`) avec safe areas.
  Ne pas revenir au letterbox integer-only sans decision explicite.
- `setBackgroundColor`, `setColor`, `clear` : **floats 0..1** (piège de port 11.0).

Sources : [setDefaultFilter](https://love2d.org/wiki/love.graphics.setDefaultFilter) · [setLineStyle](https://love2d.org/wiki/love.graphics.setLineStyle)

## 3. Port du rigging engine → matrix stack

Modèle mental : un Container Pixi `(x,y, pivot, rotation, scale, children)` = un bloc
`push → translate → rotate → scale → translate(-pivot) → [draw] → [recurse children] → pop`. La
pile **est** le scene graph ; les enfants héritent car dessinés tant que la transform du parent
est sur la pile.

Signatures vérifiées : `push()`, `translate(dx,dy)`, `rotate(angle)` (**radians**),
`scale(sx,sy)`, `pop()`. Ordre non commutatif. Le pivot peut passer par les args `ox,oy` de
`love.graphics.draw(tex,x,y,r,sx,sy,ox,oy)` (analogue direct du `pivot` Pixi) **ou** par un
`translate(-ox,-oy)` explicite. Option : `love.math.newTransform(...)` + `applyTransform` si on
a déjà une matrice par part. Profondeur de pile bornée (~64) ; toujours apparier push/pop.

Sources : [push](https://love2d.org/wiki/love.graphics.push) · [newTransform](https://love2d.org/wiki/love.math.newTransform)

## 4. Sprites depuis grilles — baker, pas pixel-par-pixel

- (a) `rectangle()` par pixel **chaque frame** = des milliers de draw calls → **à éviter** pour
  des rigs animés.
- (b) **baker une fois** : `love.image.newImageData(w,h)` (init transparent), `ImageData:setPixel(x,y,r,g,b,a)`
  (coords 0-indexées, floats 0..1), `love.graphics.newImage(data)`, puis `img:setFilter("nearest")`.
  Chaque **part** du rig = une Image bakée ; l'anim = transformations de ces Images.
- Alternative : render-to-Canvas (`newCanvas`, `setCanvas`, dessiner une fois).

Pour 10–50 rigs : ~N draw calls/perso (triv” rapide). Le `nearest` sur l'image bakée est
non négociable.

Sources : [newImageData](https://love2d.org/wiki/love.image.newImageData) · [ImageData:setPixel](https://love2d.org/wiki/ImageData:setPixel) · [newCanvas](https://love2d.org/wiki/love.graphics.newCanvas)

## 5. Perf & timing déterministe

- **SpriteBatch** (`newSpriteBatch`) aide pour **beaucoup d'instances d'une même texture**
  (terrain, props, particules), **pas** pour des rigs articulés (pivots/rotations par part).
- **Pas de temps fixe** : la boucle par défaut passe un `dt` variable → maths flottantes
  non reproductibles. Surcharger `love.run` avec un **accumulateur** (`TICK=1/60`,
  `MAX_FRAME_SKIP` borne le rattrapage). `love.draw` tourne par frame ; option : interpoler avec
  le reste de lag. Lib : `bjornbytes/tick`.
- **RNG déterministe** : `love.math.newRandomGenerator(seed)` (flux isolé), jamais `math.random`
  global pour la sim. `love.math.noise` est déterministe (gen procédurale).

Sources : [love.run](https://love2d.org/wiki/love.run) · [Fix Your Timestep](https://gafferongames.com/post/fix_your_timestep/) · [love.math.noise](https://love2d.org/wiki/love.math.noise)

## 6. Pixel art procédural (sans artiste)

- **Grille + index palette** (notre approche) : baker en Image.
- **Rampes / théorie HSB** (technique fondatrice) : hue-shift ~20°/cran, brillance L→R. Réf
  **Slynyrd Pixelblog 1**. Génération programmatique : `chickensoft-games/PalettePainter`.
- **Symétrie / miroir** : générer une moitié, miroiter (silhouettes cohérentes).
- **Automates cellulaires & bruit** : `love.math.random` seedé + lissage, ou `love.math.noise`
  (déterministe) pour cavernes/textures.

URLs : [Slynyrd palettes](https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes) ·
[Lospec tutorials](https://lospec.com/pixel-art-tutorials) · [Lospec palettes](https://lospec.com/palette-list) ·
[procedural generator](https://lospec.com/procedural-pixel-art-generator/)

## 7. Librairies — recommandation lean

| Lib | Verdict |
|---|---|
| `rxi/classic` | Utiliser au besoin (OOP ~120 LOC, MIT). |
| `hump` (timer/gamestate/vector/signal) | Cherry-pick par fichier. |
| `anim8` | **Éviter** : frame-based, inadapté au rigging procédural. |
| `bjornbytes/tick` | Optionnel : boucle pas-fixe clé en main. |

**Stack retenue pour The Pit** : pour l'instant **zéro dépendance** ; rendu/rig/combat écrits à
la main ; pas fixe hand-rollé. Ajouter `classic` + `hump.timer`/`hump.gamestate` seulement si
nécessaire.

## Caveats

1. Passer à 12.0 plus tard = re-vérifier `setColor`/canvas/shader (ajouts + quelques retraits).
2. Le `love.run` pas-fixe implique : décider quelle horloge pilote chaque système (les tweens qui
   affectent le combat doivent tourner dans l'update fixe ; le purement cosmétique peut être en
   temps réel) — sinon on réintroduit du non-déterminisme.
