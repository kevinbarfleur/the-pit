# Pixel art procédural — conventions du moteur

Tous les visuels de The Pit sont **générés par code** (grilles + palette), pas dessinés. Ce
document fige les conventions du pipeline pour que créatures, props et biomes restent cohérents.
Sources techniques vérifiées : `docs/research/love2d-tech.md`.

## 1. Pipeline

```
grille (table de strings)  +  palette (char -> {r,g,b,a})
        │  Sprite.bake()  (src/core/sprite.lua)
        ▼
ImageData:setPixel par cellule  ->  love.graphics.newImage  ->  setFilter("nearest")
        │  (UNE fois au chargement, jamais par frame)
        ▼
Image transformée via la matrix stack (rig)  ->  canvas virtuel 320×180  ->  blit ×4
```

Règle d'or perf : **bake une fois, transforme ensuite**. Jamais des milliers de `rectangle()`
par frame. Le filtre `nearest` est obligatoire sur chaque texture (sinon flou au scale-up).

## 2. Palette

`src/core/palette.lua` : un caractère = une couleur RGBA (floats 0..1). `' '` et tout caractère
absent = **transparent**. Palette "Wraeclast" portée du bestiaire : désaturée, sang/or/os/violet.

Pour ajouter des teintes, suivre la théorie des **rampes** (Slynyrd) : séquence ordonnée par
luminosité avec **hue-shift ~20° par cran** (plus chaud/clair vers le haut, plus froid/sombre
vers le bas), saturation max au milieu, jamais 0/100 % pur. Réfs : Slynyrd Pixelblog 1, Lospec.

## 3. Convention de rig (créatures)

Parts nommées par convention : `head, torso, armBack, armFront, weapon, legs, tail`. Une part
**absente est ignorée** (la sorcière n'a pas de jambes, le démon pas d'arme) — pas de crash, les
anims par défaut testent l'existence avant d'agir.

Une définition (`src/data/creatures.lua`) :
```lua
C.nom = {
  name = "NOM",
  parts = { head = { grid = {...}, pivot = {x=, y=} }, ... },
  rig = {                       -- l'ORDRE = ordre de dessin (z-order)
    { part="legs", at={0,-5} },            -- parent absent => attaché à la racine
    { part="head", parent="torso", at={3,0} },
  },
  idlePose = { armFront=0, weapon=-math.pi/2 },  -- poses de repos (radians)
  animations = { idle=function(char,t) ... end },-- optionnel : override custom
}
```

Sémantique (identique à PixiJS) : `at` = position où le **pivot** de la part se place dans
l'espace local du parent ; `pivot` = point d'ancrage dans la grille de la part. Dessin récursif :
`push → translate(at) → rotate → scale → translate(-pivot) → draw → [enfants] → pop`. Les enfants
héritent de la transformation du parent (la pile EST le scene graph).

Animations : signature `(char, t, progress) -> { rootDx, rootDy, tint?, alpha? }` ; elles
écrivent `rot/sx/sy` directement sur `char.parts[name]`. `t` est en **frames** (≈ deltaTime
PixiJS @60fps) pour réutiliser tels quels les magic numbers de la référence. L'orientation
gauche/droite est un **miroir au niveau du root** (`facing = ±1`) ; les anims travaillent
toujours « vers l'avant ».

## 4. Props & biomes (à porter)

Mêmes principes :
- **Props** : `{ name, grids (1 ou N frames), pivot, animation? }`. Statique = 1 grille bakée ;
  multi-frame = N grilles alternées ; oscillant = transform sur le container.
- **Biomes** : `paintStatic(g)` (baké une fois dans un canvas) + `paintDynamic(g, t)` (redessiné
  par frame : fumée, lave, neige, brume). En **code** (pas en grille) car trop grand pour des
  strings — on décrit des structures paramétrables (montagne, arbre mort, coulée de lave).

## 5. Références sources (PixiJS)

Le créateur a fourni 3 fichiers HTML/PixiJS de référence (bestiaire riggé, reliquaire de props,
biomes du Pit). Le **bestiaire** a servi de modèle au moteur de rig actuel. **À vendoriser sous
`docs/pixel-art/reference/`** au moment de porter props & biomes (engine et data déjà compatibles
avec l'approche grille+palette LÖVE).
