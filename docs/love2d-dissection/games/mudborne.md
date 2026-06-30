# Dissection technique de Mudborne (LÖVE / moteur maison « tngine »)

> Document de référence pour reproduire les techniques de rendu et de game-feel de
> **Mudborne** (cozy sim pixel-art commercial d'`ellraiser` / TNgineers) dans un
> autre projet LÖVE. Mudborne distribue son code source en clair (c'est la nature
> de LÖVE), ce document est une lecture verbatim de ce code.
>
> Chemins relatifs à la racine du `.love` extrait. Tous les extraits de code et
> de GLSL sont recopiés tels quels. La prose est en français ; le code, les
> identifiants et le GLSL restent dans leur langue d'origine.

---

## Table des matières

1. [Fiche technique](#1-fiche-technique)
2. [Le moteur tngine](#2-le-moteur-tngine)
3. [Pipeline de rendu](#3-pipeline-de-rendu)
4. [Shaders (les 10 fichiers `.frag`)](#4-shaders)
5. [Ambiance jour/nuit & météo](#5-ambiance-journuit--météo)
6. [Animation & game feel](#6-animation--game-feel)
7. [UI / UX](#7-ui--ux)
8. [Audio (feedback)](#8-audio-feedback)
9. [Ce qu'on vole pour The Pit](#9-ce-quon-vole-pour-the-pit)

---

## 1. Fiche technique

| Élément | Valeur |
|---|---|
| Moteur | LÖVE **12.0** (declaré dans `conf.lua` et `build.lua`) |
| Langage | Lua 5.1 / LuaJIT (JIT désactivé sur **tout** macOS — condition `love.system.getOS()=='OS X'` ; Apple Silicon n'est que la raison citée en commentaire — voir `main.lua`) |
| Résolution interne (« game ») | **640 × 360** px (`game.g.game_width/height` dans `md_globals.lua`) |
| Fenêtre par défaut | 1280 × 720, redimensionnable (`conf.lua`) |
| Scale pixel-art par défaut | `game_scale = 2` (réglable 2→6 dans les options ; Steam Deck force 3 à 1280×800) |
| Filtrage | `love.graphics.setDefaultFilter("nearest", "nearest")` partout |
| Renderer | OpenGL forcé via `renderer.txt` (`conf.lua`) |
| Build / packaging | [`love-build`](https://github.com/ellraiser/love-build) (`build.lua`), Steam via `luasteam` |
| Modules LÖVE coupés | `physics`, `touch`, `video` désactivés dans `conf.lua` |
| Maps | Tiled (`.tmx`) exportées en `.lua` via un script Node maison (`map_converter.js`) |
| Sprites | Aseprite + slices, export `.json` parsé au runtime |
| Auteur | Ell (`ellraiser`), studio TNgineers, éditeur Future Friends |

### Le `conf.lua` complet

```lua
-- @file - conf.lua
-- @desc - basic configuration settings for love

-- making sure the game doesnt runs okay without it ready for a certain platform
local override = love.filesystem.read('renderer.txt')
local renderer = {'opengl'}
if override then
  renderer = {override, 'opengl'}
else
  love.filesystem.write('renderer.txt', 'opengl')
end
print('RENDERER: ', override)

function love.conf(t)
  t.version = '12.0'
  t.window.title = 'Mudborne Demo'
  t.window.icon = 'game/resources/icon.png'
  t.window.resizable = true
  t.window.usedpiscale = false
  t.window.width = 1280
  t.window.height = 720
  t.graphics.renderers = renderer
  t.modules.physics = false
  t.modules.touch = false
  t.modules.video = false
end
```

> Note : `12.0` est une version de développement de LÖVE (l'API stable publique
> est 11.5 au moment où ce document est écrit). Le code utilise des fonctions
> 12.x comme `love.graphics.newTextBatch`, `love.filesystem.mountFullPath`,
> `Source:setFilter`, etc. Si vous ciblez 11.5, `newTextBatch` devient
> `newText`, et quelques signatures diffèrent. Le reste des techniques (canvases,
> shaders, quads) est identique entre 11.x et 12.x.

### Arbre des dossiers (commenté)

```
mudborne/
├── conf.lua            -- config LÖVE (version, fenêtre, renderer)
├── main.lua            -- bootstrap : charge tngine, branche les hooks LÖVE -> game.event.*
├── build.lua           -- config love-build (export Steam)
├── steam_appid.txt     -- app id steam
│
├── tngine/             -- LE MOTEUR MAISON (réutilisable, ~"GameMaker fucked up")
│   ├── tn_core.lua     -- coeur : globals, boucle update/tick/tock/draw, hooks LÖVE
│   ├── classes/        -- classes du moteur
│   │   ├── tn_object.lua        -- instance générique (oid, props, scripts, alarms, bbox)
│   │   ├── tn_ui.lua            -- élément UI cliquable lié à un menu
│   │   ├── tn_menu.lua          -- conteneur de UI (panel déplaçable)
│   │   ├── tn_view.lua          -- caméra + culling d'instances par grille
│   │   ├── tn_surface.lua       -- wrapper léger sur love.graphics.Canvas
│   │   ├── tn_tilemap.lua       -- tilemap à canvas "roulant" (rolling), chunké
│   │   ├── tn_sprite.lua        -- sprite (quads) lié à une texture
│   │   ├── tn_texture.lua       -- love.Image + utilitaires + slices Aseprite
│   │   ├── tn_text.lua          -- texte avec icônes inline
│   │   ├── tn_particle.lua      -- définition d'une particule
│   │   ├── tn_particlesystem.lua-- système de particules (update/draw manuels)
│   │   ├── tn_animcurve.lua     -- wrapper sur love.math.newBezierCurve
│   │   └── tn_input.lua         -- input + remapping clavier/manette
│   ├── modules/
│   │   ├── tn_draw.lua          -- helpers de dessin (sprite, slice 9-patch, text, color)
│   │   ├── tn_util.lua          -- helpers (ternary, lerp, clamp, hexToRGB, gridpos, uuid…)
│   │   ├── tn_logger.lua        -- log
│   │   └── tn_profiler.lua      -- profiler step/draw (touche ',' en debug)
│   └── resources/
│       ├── fonts/font-char.png  -- ImageFont par défaut du moteur
│       └── libs/                -- binser (save), json (aseprite), csv (i18n)
│
└── game/               -- LE JEU lui-même, construit avec tngine
    ├── readme.md
    ├── classes/        -- classes "core" du jeu (player, frog, item, book, audio, room…)
    ├── events/         -- hooks d'événements (ev_draw, ev_step, ev_tick, ev_tock, ev_mouse…)
    ├── mobjs/          -- "machine objects" : menus des machines (cauldron, spawner, breeder…)
    ├── modules/        -- md_globals (toutes les globales), md_world, md_ui (95KB), md_collision…
    ├── shaders/        -- LES 10 .frag (eau, glace, neige, nuit, outline, ombres, void, paint…)
    ├── ui/             -- classes UI spécifiques (ui_button, ui_tank, ui_picker, ui_lilypad…)
    └── resources/
        ├── maps/       -- .tmx Tiled + export .lua + map_converter.js
        ├── sprites/    -- spritesheet_w/d.png + .json aseprite (slices)
        └── sound/ music/ -- ogg
```

Le **point clé d'architecture** : `tngine` ne sait rien de Mudborne. C'est un
mini-moteur générique « à la GameMaker » (objets + scripts + alarmes + tilemaps +
particules + UI). Tout le jeu est branché par-dessus via une table globale
`game = { class = {}, event = {} }` et des hooks `main.draw/step/tick/...` que le
moteur appelle.

---

## 2. Le moteur tngine

### 2.1 Bootstrap (`main.lua`)

`main.lua` est le seul fichier que LÖVE charge directement. Il :

1. charge le moteur : `require("tngine.tn_core")` (qui crée la table globale `tn`) ;
2. crée la table de jeu `game = { class = {}, event = {} }` ;
3. charge **tout** le dossier `game/` récursivement avec un helper du moteur :
   ```lua
   tn.util.requireFolder('game', {'map_demo.lua', 'map_dev.lua', 'map_main.lua'})
   ```
   (la liste est une *ignorelist* : les énormes fichiers de map ne sont pas
   `require`-és au boot) ;
4. branche les hooks de `tngine` (`main.draw`, `main.step`, `main.tick`,
   `main.tock`, `main.mousepressed`, …) sur les fonctions `game.event.*`.

Extrait du branchement (`main.lua`) :

```lua
main.draw = function()
  -- special drawing for a 'splashscreen' while preloading
  if not _loaded then
    love.graphics.setCanvas(_temp)
    tn.draw.color(16, 31, 43, 1)
    tn.draw.sprite('sp_pixel', 1, 0, 0, 0, game.g.game_width+10, game.g.game_height+10)
    -- ... logo ...
    love.graphics.setCanvas()
    love.graphics.draw(_temp, 0, 0, 0, game.g.game_scale, game.g.game_scale)
  else
    game.event.draw()
  end
end
main.step = function(dt)
  if not _setup then
    game.event.setup()  -- charge textures, sprites, surfaces
    _setup = true
  elseif not _loaded then
    game.event.load()   -- charge la map, crée les objets
    _loaded = true
    _temp = nil
  end
  if _loaded then
    game.event.step(dt)
  end
  if _G.steam then _G.steam.runCallbacks() end
end
main.tick = function() game.event.tick() end
main.tock = function() game.event.tock() end
main.mousepressed = function(...) game.event.mouse('pressed', ...) end
main.mousereleased = function(...) game.event.mouse('released', ...) end
-- etc.
```

À retenir : un **splash screen dessiné à la main** s'affiche pendant que `setup`
puis `load` tournent sur les premières frames (la première frame fait le setup,
la seconde le load, puis le jeu démarre). C'est un truc simple pour masquer le
coût de chargement sans thread.

### 2.2 La table globale `tn` et les « internals »

`tn_core.lua` crée d'abord `tn = { g = {}, class = {} }` puis une grande table
`tn.internals` qui est le registre central du moteur (façon GameMaker) :

```lua
tn.internals = {
  uuids = {}, room = {}, sprites = {}, menus = {}, uis = {}, objs = {},
  particles = {}, particlesystems = {}, alarms = {}, textures = {}, tilemaps = {},
  openmenus = {}, activemenus = {}, activeobjs = {}, activeobjsmap = {},
  -- ...
  ticks = { ms = 0 },
  _update = 1/60, _step = 1/60, _draw = 1/60,
  step_run = { frame = 1/60, frames = 0, frame_count = 0, frame_delta = 0 },
  _tick = 1/10, tick_run = { ... },
  _tock = 1, tock_run = { ... },
  -- fonts ImageFont par défaut
  font_char = love.graphics.newImageFont('tngine/resources/fonts/font-char.png', " AaBb...", 1),
  binser = require("tngine.resources.libs.tn_binser"),
  json = require("tngine.resources.libs.tn_json"),
  csv = require("tngine.resources.libs.tn_csv")
}
```

`tn.internals.room` est une **grille spatiale 2D** (`room_width/room_grid` =
600×600 cases de 16px). Chaque case contient la liste des UUID d'objets qui
s'y trouvent. C'est ce qui permet le culling O(cases visibles) au lieu de
O(tous les objets) — voir la classe `view`.

`tn.highlighted` et `tn.dragging` centralisent l'état de survol/drag (obj, menu,
ui, tile) recalculé chaque frame depuis la position souris.

### 2.3 La boucle : update / step / tick / tock / draw

Le cœur de `tngine` sépare la fréquence des mises à jour en 3 cadences, dans
`love.update` (`tn_core.lua`) :

```lua
function love.update(delta)
  -- unlimited step (par défaut, tn.internals.capped == false)
  if not tn.internals.capped then
    main._step(delta)
  else
    -- limit step to run every 60 frames (optionnel)
    ...
  end

  -- ticks run every 0.1s
  tn.internals.tick_run.frame_count = tn.internals.tick_run.frame_count + delta
  if tn.internals.tick_run.frame_count >= tn.internals.tick_run.frame then
    tn.internals.tick_run.frame_count = tn.internals.tick_run.frame_count - tn.internals.tick_run.frame
    main._tick()
    tn.internals.tick_run.frame_delta = 0
  end

  -- tocks run every 1s
  tn.internals.tock_run.frame_count = tn.internals.tock_run.frame_count + delta
  if tn.internals.tock_run.frame_count >= tn.internals.tock_run.frame then
    ...
    main._tock()
  end

  -- sort active objs each frame (par depth)
  table.sort(tn.internals.activeobjs, tn.util.depthSort)
end
```

| Hook | Cadence | Usage typique dans Mudborne |
|---|---|---|
| `step(dt)` | chaque frame | mouvement caméra, surbrillance, météo, lumière, tooltip |
| `tick()` | 10 Hz (0.1 s) | avance des frames de sprite, décompte des **alarmes** |
| `tock()` | 1 Hz (1 s) | animations de tuiles, météo on/off, spawn, debug stats |
| `draw()` | chaque frame | tout le pipeline de rendu (`ev_draw.lua`) |

Le **système d'alarmes** (décompté dans `_tick`) est central : tout objet ou UI
peut définir `alarm_scripts[i]` et appeler `obj:alarm(i, secondes)`. Le moteur
décompte et déclenche le script — c'est l'équivalent des `alarm[]` de GameMaker,
et c'est la base de toutes les machines de Mudborne (un cauldron qui met N
secondes à produire, etc.).

Extrait du décompte d'alarmes (`tn_core.lua`, `main._tick`) :

```lua
for i,v in pairs(tn.internals.alarms) do
  local thing = tn.internals.objs[v] or tn.internals.uis[v]
  if thing ~= nil and thing.alarm_scripts then
    for j,a in pairs(thing.alarm_timers) do
      if a > 0 then
        thing.alarm_timers[j] = thing.alarm_timers[j] - 0.1
        if thing.alarm_timers[j] <= 0 then
          if thing.alarm_scripts[j] then thing.alarm_scripts[j](thing) end
          -- ... gestion du reliquat ...
        end
      end
    end
  end
end
```

### 2.4 La classe `object` (l'unité de base)

`tn.class.obj` (`tngine/classes/tn_object.lua`) est l'instance générique. Modèle
« data + scripts » : tout ce que le dev ajoute va dans `obj.props` (données) et
`obj.scripts` (comportements), pour ne jamais polluer les champs du moteur.

Champs notables d'un objet à la création :

```lua
local obj = {
  id = uuid, oid = oid, sprite_id = sprite_id, sprite_frame = 1, sprite_speed = 0,
  scale_x = 1, scale_y = 1, scale_ox = 0, scale_oy = 0,
  class = 'OBJECT', alarm_scripts = {}, alarm_timers = {},
  x = x, y = y, depth = y, depth_mod = love.math.random(), -- depth_mod = tie-break aléatoire
  gx = grid_x, gy = grid_y,
  bbox = { l, r, t, b, w, h },        -- boîte de collision/survol
  layer = 0, active = true, visible = true, in_bounds = false,
  persistent = persistent == true,    -- si true : jamais cullé
  props = {},
  scripts = { step = nil, draw = function(s) s:drawself() end, click, deactivate, destroy, animend }
}
```

Patterns réutilisables :

- **`obj:extend(subclass)`** copie les fonctions d'une sous-classe dans
  `obj.scripts`, en reconnaissant les `alarmN` comme alarmes. C'est l'héritage
  « léger » du moteur : pas de métatables en cascade, juste de la composition de
  scripts.
- **`obj:call('nomscript', ...)`** appelle un script s'il existe (sucre
  syntaxique + tolérance au script manquant).
- **`depth = y`** : tri de profondeur top-down par position Y (classique en
  pixel-art iso/top-down), avec un `depth_mod` aléatoire pour casser les égalités
  de façon déterministe par instance.
- **culling automatique** : un objet hors-vue passe `active=false` (sauf
  `persistent`), il n'est ni `step`-é ni `draw`-é.

### 2.5 La classe `view` (caméra + culling spatial)

`tn.class.view` (`tn_view.lua`) est la caméra. Outre `move`/`moveTowards`
(lerp), sa fonction maîtresse est `activate()` : elle parcourt **uniquement les
cases de la grille `tn.internals.room` couvertes par le viewport (+ marge)** et
active/désactive les objets. C'est le culling.

```lua
moveTowards = function(self, target_x, target_y, spd)
  local cam_x = tn.util.lerp(self.x, self.target_x, spd)
  local cam_y = tn.util.lerp(self.y, self.target_y, spd)
  -- snap quand on est à 0.01 près
  if tn.util.within(cam_x, self.target_x, 0.01) then cam_x = self.target_x end
  ...
end
```

Détail malin pour le pixel-art : la vue garde `draw_x = math.floor(self.x)` et
`frac_x = tn.util.frac(self.x)`. Le monde est rendu à la position **entière**
(`draw_x`) dans un canvas basse-résolution ; le **sous-pixel** (`frac_x`) n'est
appliqué qu'à la toute fin, en décalant le canvas final scalé (voir §3.5). Ça
donne un scroll fluide sans casser le rendu pixel-perfect.

### 2.6 Modules utilitaires

`tn.util` (`tn_util.lua`) regroupe les helpers que tout le code appelle :
`ternary`, `clamp`, `lerp`, `eerp` (lerp exponentiel), `frac`, `within`,
`distance`, `gridpos` (division entière par 16), `hexToRGB`, `uuid`, `choose`,
`copy` (deep copy), `overlap` (AABB), `requireFolder`, `defineSprites`,
`withObjs`/`withMenus` (itérateurs), `depthSort`/`depthSortInv`.

Ces fonctions sont triviales mais c'est **exactement** ce qu'un mini-moteur
maison doit fournir pour que le code de gameplay reste lisible. Exemple :

```lua
ternary = function(condition, truthy, falsey)
  if condition then return truthy else return falsey end
end,
hexToRGB = function(hex)
  hex = hex:gsub("#","")
  return { tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6)), 1 }
end,
```

`tn.draw` (`tn_draw.lua`) fournit `sprite`, `tilemap`, `slice` (9-patch !),
`text`, `color` (en 0-255 plutôt que 0-1), `alpha`, `menus`, `objs`. Le
`tn.draw.color` est notable : il accepte r,g,b,a en 0-255 **ou** une table, et
convertit en 0-1 pour LÖVE — ça évite d'écrire `/255` partout.

---

## 3. Pipeline de rendu

Tout le rendu vit dans `game/events/ev_draw.lua` (~940 lignes). C'est un
**pipeline multi-canvas** : le jeu n'est presque jamais dessiné directement à
l'écran ; chaque « couche » est rendue dans une `surface` (canvas), puis les
surfaces sont composées entre elles, souvent à travers un shader.

### 3.1 Les surfaces (canvas nommés)

Toutes créées dans `ev_load.lua` à la taille interne `640×360 (+1)` via
`tn.class.surface:new()` :

```lua
game.g.surf_screen       = tn.class.surface:new(game.g.game_width+1, game.g.game_height+1)
game.g.surf_game         = tn.class.surface:new(...)
game.g.surf_reflections1 = tn.class.surface:new(...)
game.g.surf_reflections2 = tn.class.surface:new(...)
game.g.surf_water        = tn.class.surface:new(...)
game.g.surf_ui           = tn.class.surface:new(...)
game.g.surf_shadows1     = tn.class.surface:new(...)
game.g.surf_shadows2     = tn.class.surface:new(...)
game.g.surf_lighting     = tn.class.surface:new(...)
game.g.surf_black        = tn.class.surface:new(...)
game.g.surf_blank        = tn.class.surface:new(...)
game.g.surf_void         = tn.class.surface:new(...)
game.g.surf_dream        = tn.class.surface:new(...)
game.g.surf_foliage1     = tn.class.surface:new(...)
game.g.surf_foliage2     = tn.class.surface:new(...)
```

La classe `surface` est un wrapper minimal mais sa méthode `:write()` est le
pattern qu'on réutilise partout : « clear + dessine dans ce canvas + restaure » :

```lua
-- tngine/classes/tn_surface.lua
write = function(self, clear, col, script)
  love.graphics.setCanvas(self.canvas)
    if clear == true then love.graphics.clear(col[1]/255, col[2]/255, col[3]/255, col[4]) end
    script()
  love.graphics.setCanvas()
end,
```

### 3.2 Ordre de dessin (vue d'ensemble de `game.event.draw`)

Les pourcentages sont ceux annotés par l'auteur (coût relatif). L'ordre est :

1. **`surf_reflections1`** — tous les objets `reflectable` redessinés **en noir**
   et **retournés verticalement** (scale Y négatif), + les tilemaps `floor`/`ice`.
   C'est le calque de réflexions dans l'eau.
2. **`surf_reflections2`** — `surf_reflections1` repassé à travers
   `shader_fluid` (ondulation sinusoïdale).
3. **`surf_water`** — la tilemap `water` seule, dans son propre canvas (sert de
   masque/offset aux shaders d'eau et de glace).
4. **`surf_shadows1/2`** — ombres des items (sprite `sp_item_shadow`) par couche.
5. **`surf_foliage1/2`** — feuillage actif + tilemap `floor2` (sert au shader de
   neige comme masque).
6. **`surf_game`** (≈60% du coût) — **le monde** : eau, réflexions colorisées
   (`shader_wshadows`), tadpoles, glace (`shader_ice`), FX d'eau, sol, blocs de
   pierre, objets par couche (`drawObjs(-1/0/1/2)`), herbe, particules, void,
   prévisualisation de placement, barres de vie, etc.
7. **`surf_lighting`** (≈6%) — le **lightmap** : un canvas où l'on peint la
   « noirceur » de la nuit (rectangle sombre) puis des **cercles de lumière**
   (joueur + objets émetteurs). Ce canvas sera *soustrait* à l'image par
   `shader_night`.
8. **`surf_black`** / **`surf_blank`** — lightmaps « plats » (une seule couleur)
   pour les cas où l'on veut éclairer l'UI sans le dégradé.
9. **`surf_screen`** (≈0.5%) — `surf_game` passé à travers `shader_night`
   (applique l'éclairage), + redessin des objets/menus survolés *au-dessus* de
   l'éclairage (pour qu'ils ne soient pas assombris), + objets `qpaint` à travers
   `shader_paint`, + tooltips de panneaux.
10. **`surf_void`** (≈4.5%) — particules de void (pour les transitions/rêve).
11. **transitions** — chaque transition a son mini-canvas.
12. **`surf_ui`** (≈6%) — menus, notifications, dialogues, livre, tooltips,
    debug, curseur, et la transition finale à travers `shader_void`.
13. **Composition finale à l'écran** (≈0.5%) — voir §3.5.

Le pattern récurrent : **`surface:write(clear, col, fn)` pour remplir un canvas,
puis `setShader(s); autre_surface:draw(); setShader()` pour composer**.

### 3.3 Réflexions dans l'eau (le truc le plus élégant du jeu)

Au lieu d'un vrai miroir, Mudborne redessine les objets *à la main*, en noir,
retournés, dans un canvas (`surf_reflections1`) :

```lua
-- game/events/ev_draw.lua
game.g.surf_reflections1:write(true, {0, 0, 0, 0}, function()
  love.graphics.setColor(0, 0, 0, 1)
  for i=1,#tn.internals.activeobjs do
    local aobj = tn.internals.activeobjs[i]
    if aobj.reflectable then
      local frame = aobj.sprite_frame
      love.graphics.draw(
        tn.internals.sprites[aobj.props.reflection_spr].texture,
        tn.internals.sprites[aobj.props.reflection_spr].frames[frame],
        math.floor(aobj.x - game.g.camera.draw_x) + aobj.scale_ox,
        math.floor(aobj.y - game.g.camera.draw_y) + aobj.props.reflections[2], 0,
        aobj.scale_x, aobj.props.reflections[1]   -- reflections[1] = scale Y négatif
      )
    end
    -- ... ponts ...
  end
  -- tilemaps reflétées
  if not game.g.player.props.is_inside then
    tn.draw.tilemap(game.g.tilesets.floor, 0, 2)
    tn.draw.tilemap(game.g.tilesets.ice, 0, 1)
  end
end)
```

Puis ce calque noir est ondulé par `shader_fluid` dans `surf_reflections2`, puis
**recoloré** selon la profondeur de l'eau par `shader_wshadows` au moment où il
est dessiné dans `surf_game` :

```lua
game.g.shader_wshadows:send('fluid', game.g.surf_water.canvas)
game.g.shader_wshadows:sendColor('deep',   game.g.waters[game.g.world][region][1])
game.g.shader_wshadows:sendColor('deeper', game.g.waters[game.g.world][region][2])
love.graphics.setShader(game.g.shader_wshadows)
  game.g.surf_reflections2:draw(0, 0)
love.graphics.setShader()
```

L'idée clef : la « réflexion » est juste une silhouette noire ondulée, recolorée
en deux teintes d'eau (`deep`/`deeper`) — pas de raytracing, juste des canvas.

### 3.4 Intégration Tiled

`md_world.lua > loadMap(map_only, map)` charge l'export `.lua` d'une map Tiled
passée par le `map_converter.js` maison. Format de l'export
(`game/resources/maps/map_demo.lua`, recopié structurellement) :

```lua
return {
  width = 600,
  height = 600,
  layers = {
    { name = "water",      type = "tilelayer", width = 600, height = 600, data = { ... } },
    { name = "ice",        type = "tilelayer", ... },
    { name = "floor",      type = "tilelayer", ... },
    { name = "stone",      type = "tilelayer", ... },
    { name = "stone_dec",  type = "tilelayer", ... },
    { name = "grass",      type = "tilelayer", ... },
    { name = "grass_dec",  type = "tilelayer", ... },
    { name = "floor2",     type = "tilelayer", ... },
    { name = "objs",       type = "objlayer",  files = {"map_demo_objects1.lua"} },
    { name = "void",       type = "tilelayer", ... },
    { name = "floor0_col", type = "tilelayer", ... },  -- couches de collision
    { name = "floor1_col", type = "tilelayer", ... },
  },
  tilesets = { { filename = 'tiled/ts_objects.tsx', firstgid = ... }, ... }
}
```

Le chargement :

```lua
loadMap = function(map_only, map)
  local tiled = love.filesystem.load('game/resources/maps/' .. map .. '.lua')()
  local obj_layer = nil
  for l=1,#tiled.layers do
    local tname = tiled.layers[l].name
    if (tname:find('_col') or tname == 'map') and not tn.g.debug_mode then
      tiled.layers[l].draw = false   -- couches de collision invisibles
    end
    if tname ~= 'objs' then
      -- chaque couche de tuiles devient une tn.class.tilemap
      game.g.tilesets[tname] = tn.class.tilemap:new(
        tname, tiled.width, tiled.height,
        game.g.tilemap_texture, 16, game.g.tilemap_quads, tiled.layers[l], 1)
    else
      obj_layer = tiled.layers[l]   -- couche d'objets traitée à part
    end
  end
  -- objets : chaque entrée { gid, x, y, h_offset, props } est mappée vers un oid
  -- via game.g.dictionary_gid_map, puis instanciée (frog, mobj, foliage, crate…)
  ...
end
```

Notes importantes :

- Les **objets Tiled** sont une "Collection of Images" : chaque objet a un GID
  qui est résolu en `oid` via `game.g.dictionary_gid_map`. Le dico
  (`re_dictionary.lua`) décide quelle classe instancier.
- Pour les **grosses maps**, l'export `.lua` standard de Tiled dépasse la limite
  Lua « main function has more than 65536 constants ». Le `map_converter.js`
  contourne ça en **découpant** les objets dans des fichiers séparés
  (`map_demo_objects1.lua`) chargés à la demande. C'est pour ça que le
  `map_demo.lua` n'est pas `require`-é au boot (cf. ignorelist dans `main.lua`).
- Les couches `floorX_col` portent les **collisions** ; en `loadMap` on parcourt
  toute la grille pour créer les `solid`, les `void`, les points de spawn et les
  **tile-animations** (eau, algues, herbe animées) selon la valeur de tuile.

### 3.5 Tilemap à « canvas roulant » (rolling canvas)

`tn.class.tilemap` (`tn_tilemap.lua`) est l'optimisation de rendu la plus
importante. Une map de 600×600 tuiles ne tient pas raisonnablement dans un seul
canvas. La solution : **le canvas d'une tilemap fait exactement la taille de
l'écran** (`window/scale + 1`), et quand la caméra bouge, on ne **redessine que
la nouvelle rangée/colonne révélée**, en décalant le contenu existant :

```lua
drawQueue = function(self, x1, x2, y1, y2)
  -- 1) recopier le canvas existant décalé de (grid - nouveau) cases
  love.graphics.setCanvas(self.temp_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(self.main_canvas, 0, 0)
  love.graphics.setCanvas()
  love.graphics.setCanvas(self.main_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(self.temp_canvas, (self.grid_x1 - x1)*16, (self.grid_y1 - y1)*16)
  love.graphics.setCanvas()

  -- 2) si on a bougé de plus que la largeur/hauteur -> rerender complet
  if math.abs(self.grid_x1 - x1) >= x_diff or ... then
    -- redessine toutes les tuiles
  else
    -- 3) sinon, ne dessine que la nouvelle colonne (gauche/droite) ou rangée (haut/bas)
    if self.grid_x1 ~= x1 then ... draw new column ... end
    if self.grid_y1 ~= y1 then ... draw new row ... end
  end
  self.grid_x1, self.grid_y1, self.grid_x2, self.grid_y2 = x1, y1, x2, y2
end,
```

Au dessin, la tilemap n'est qu'un `love.graphics.draw(canvas)` positionné selon
la caméra (`tn.draw.tilemap`) :

```lua
tilemap = function(tilemap, offset_x, offset_y)
  local cx = math.floor((tilemap.grid_x1*16) - game.g.camera.draw_x)
  local cy = math.floor((tilemap.grid_y1*16) - game.g.camera.draw_y)
  love.graphics.draw(tilemap.main_canvas, cx+offset_x, cy+offset_y)
end,
```

C'est ce qui permet une map quasi-infinie avec un coût de rendu constant
(un seul draw call par couche, sauf à la frontière où l'on redessine une rangée).

### 3.6 Composition finale et scaling pixel-art

À la toute fin de `game.event.draw`, on assemble les surfaces basse-résolution
et on les scale d'un coup à l'écran, en appliquant le **décalage sous-pixel** de
la caméra pour un scroll lisse :

```lua
-- lightmap "plat" pour la composition finale
game.g.shader_night:send('lightmap', game.g.surf_blank.canvas)
love.graphics.setShader(game.g.shader_night)
  game.g.surf_void:draw(-game.g.camera.frac_x, -game.g.camera.frac_y, 0, game.g.game_scale, game.g.game_scale)
love.graphics.setShader()
love.graphics.setShader(game.g.shader_void)
  game.g.surf_screen:draw(-game.g.camera.frac_x, -game.g.camera.frac_y, 0, game.g.game_scale, game.g.game_scale)
love.graphics.setShader()
game.g.surf_ui:draw(0, 0, 0, game.g.game_scale, game.g.game_scale)
```

Trois principes pixel-art à retenir :

1. **Tout est rendu à la résolution interne** (640×360), puis scalé entier
   (`game_scale`) à la fin.
2. **`nearest` partout** (filtrage) ⇒ pas de flou.
3. **Le monde au pixel entier (`draw_x`), le sous-pixel (`frac_x/frac_y`) appliqué
   seulement à la composition finale** ⇒ scroll fluide sans tremblement de pixels.
   L'UI (`surf_ui`) est composée **sans** décalage sous-pixel (elle reste collée
   à la grille écran).

---

## 4. Shaders

Tous les shaders sont des **fragment shaders** GLSL au format LÖVE (fonction
`effect(color, tex, texture_coords, screen_coords)`). Ils sont chargés une fois
dans `md_globals.lua` :

```lua
-- game/modules/md_globals.lua
shader_outline  = love.graphics.newShader('game/shaders/sh_outline.frag'),
shader_fluid    = love.graphics.newShader('game/shaders/sh_fluid.frag'),
shader_ice      = love.graphics.newShader('game/shaders/sh_ice.frag'),
shader_snow     = love.graphics.newShader('game/shaders/sh_snow.frag'),
shader_wshadows = love.graphics.newShader('game/shaders/sh_shadows.frag'),
shader_void     = love.graphics.newShader('game/shaders/sh_void.frag'),
shader_night    = love.graphics.newShader('game/shaders/sh_night.frag'),
shader_player   = love.graphics.newShader('game/shaders/sh_player.frag'),
shader_paint    = love.graphics.newShader('game/shaders/sh_paint.frag'),
shader_test     = love.graphics.newShader('game/shaders/sh_test.frag'),
```

> **Philosophie générale** : la plupart de ces shaders sont des **opérations
> couleur-clé** (color-keying). On peint des sprites/tuiles dans des couleurs
> « magiques » (rouge pur, cyan pur, vert pur, bleu pur…) et le shader remplace
> ces couleurs par autre chose au moment du rendu. C'est extrêmement bon marché
> et parfaitement adapté au pixel-art à palette réduite. Comparaisons strictes
> `==` sur des couleurs : possible **uniquement** parce que tout est en `nearest`
> sans antialiasing ni mipmaps qui mélangeraient les pixels.

---

### 4.1 `sh_outline.frag` — contour blanc 1px

**Rôle** : transformer n'importe quel sprite opaque en une silhouette **blanche
pure**, pour fabriquer un contour sans dessiner de sprite de contour.

**Chemin** : `game/shaders/sh_outline.frag`

```glsl
// shader used to turn anythingh drawn into pure white
// used to make outlines for certain things to save a sprite

vec4 white = vec4(1.0,1.0,1.0,1.0);

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texcolor = Texel(tex, texture_coords);
  if (texcolor.a < 1.0) discard; // ignore any pixels with transparency
  return white * color;
}
```

**Application** (`md_world.lua > drawObjs`, sur l'objet survolé) — on dessine
l'objet **4 fois**, décalé de 1px dans chaque diagonale, en blanc, puis l'objet
normal par-dessus. Le résultat : un liseré blanc de 1px tout autour.

```lua
love.graphics.setShader(game.g.shader_outline)
  love.graphics.translate(-1, 0)
  obj:call('draw')
  love.graphics.translate(1, -1)
  obj:call('draw')
  love.graphics.translate(1, 1)
  obj:call('draw')
  love.graphics.translate(-1, 1)
  obj:call('draw')
  love.graphics.origin()
love.graphics.setShader()
-- puis obj:draw() normal par-dessus (plus loin dans la boucle)
```

(Aussi utilisé dans `cl_lift.lua` et `mo_zen.lua` pour des objets interactifs.)

**Comment reproduire** : `discard` tous les pixels non-pleinement-opaques, renvoie
blanc. Pour le contour, dessine le sprite 4× (offsets cardinaux ou diagonaux)
sous ce shader, puis le sprite normal au-dessus. Pour un contour plus épais,
augmente les offsets ou fais 8 passes (cardinal + diagonal).

---

### 4.2 `sh_fluid.frag` — ondulation de l'eau

**Rôle** : faire onduler (« wobble ») les réflexions de l'eau via une distorsion
sinusoïdale des coordonnées de texture, animée dans le temps.

**Chemin** : `game/shaders/sh_fluid.frag`

```glsl
// shader used to make the fluid wobbling affect used for all fluids

extern Image fluid; // texture of where fluid is
extern float time; // current game time
extern float height; // window h
extern float cy; // camera offset

// wobble vals
const float z_speed = 2.0;
const float x_freq = 80.0;
const float x_size = 0.0011;
const float y_freq = 10.0;
const float y_size = 0.0;

vec4 black = vec4(0.0, 0.0, 0.0, 1.0); // mask col

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {

  // get size of 1px and a random val to use for wobble
  float ypixel = 1.0 / height;
  float random = texture_coords.y + (cy*ypixel);

  // get wobble
  float x_wave = sin(time*z_speed + random*x_freq) * (x_size);
  float y_wave = sin(time*z_speed + random*y_freq) * (y_size);

  vec4 t_mask = Texel(fluid, texture_coords); // water layer
  vec4 t_actual = Texel(tex, texture_coords); // actual game objs
  vec4 t_warp = Texel(tex, texture_coords + vec2(x_wave, y_wave)); // warped game objs
  vec4 t_wmask = Texel(fluid, texture_coords + vec2(x_wave, y_wave)); // warped mask

  // if mask not black return mix of warp + actual
  if (t_mask != black) {
    // for edges of warped mask remove black leftovers
    if (t_wmask == black) {
      return t_mask;
    }
    return mix(t_warp, t_warp, t_actual);
  // otherwise return actual
  } else {
    return t_actual;
  }

}
```

**Application** (`ev_draw.lua`) — on l'envoie sur `surf_reflections1` pour
produire `surf_reflections2` :

```lua
game.g.surf_reflections2:write(true, {0, 0, 0, 0}, function()
  local window = tn.util.windowSize()
  game.g.shader_fluid:send('height', window.h)
  game.g.shader_fluid:send('cy', game.g.camera.y or 0)
  game.g.shader_fluid:send('time', love.timer.getTime())
  love.graphics.setShader(game.g.shader_fluid)
    game.g.surf_reflections1:draw(0, 0)
  love.graphics.setShader()
end)
```

**Passages clés** :

- `random = texture_coords.y + cy*ypixel` : la phase de l'onde dépend de la
  position Y **en coordonnées monde** (on ajoute l'offset caméra `cy` converti en
  fraction de texture), pour que l'ondulation « accroche » au monde et ne glisse
  pas avec la caméra.
- `x_wave = sin(time*z_speed + random*x_freq) * x_size` : décalage horizontal
  des UV. `x_freq=80` ⇒ beaucoup de crêtes verticalement ; `x_size=0.0011` ⇒
  amplitude minuscule (~1px). `y_size=0.0` ⇒ pas d'ondulation verticale ici.
- Le masque `fluid` (= `surf_water`) délimite **où** appliquer l'effet : hors de
  l'eau (`t_mask == black`) on renvoie l'image telle quelle.
- Le test `t_wmask == black` nettoie les bavures de bord quand le décalage tire
  des pixels hors de la zone d'eau.

> Le `mix(t_warp, t_warp, t_actual)` est un artefact (mixer A et A redonne A) — en
> pratique le shader renvoie l'échantillon décalé `t_warp`.

**Comment reproduire** : passe l'image à distordre + un masque « où est le
fluide » + `time` + hauteur écran + offset caméra. Décale les UV par un
`sin(time + uv.y*freq)*amplitude` minuscule, et n'applique le décalage que dans
la zone du masque.

---

### 4.3 `sh_shadows.frag` — recoloration des réflexions selon l'eau

**Rôle** : transformer la silhouette **noire** des réflexions en une couleur
d'eau correcte (deux teintes de profondeur), au moment de la composer dans le
monde.

**Chemin** : `game/shaders/sh_shadows.frag`

```glsl
// shader used to turn black water shadow into the "correct" color based on water

extern Image fluid; // texture of where fluid is
extern vec4 deep;
extern vec4 deeper;

vec4 red = vec4(1.0, 0.0, 0.0, 1.0);

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texcolor = Texel(tex, texture_coords);
  vec4 t_mask = Texel(fluid, texture_coords); // water layer
  if (texcolor.a == 0.0) discard;
  if (t_mask.rgb == deep.rgb) {
    return deeper;
  } else if (t_mask.rgb == red.rgb) {
    return red;
  } else {
    return deep;
  }
}
```

**Application** : voir §3.3. `deep`/`deeper` proviennent de
`game.g.waters[world][region]` (table de couleurs par monde et par région, dans
`md_globals.lua`), envoyées via `:sendColor`.

**Passages clés** : la couleur de la tuile d'eau (`fluid`) sert de clé : eau
profonde (`deep`) ⇒ réflexion `deeper`, sinon ⇒ `deep`. La réflexion noire elle-
même n'apporte que sa silhouette (`texcolor.a == 0.0 ? discard`).

**Comment reproduire** : color-key sur un masque d'eau pour choisir une teinte de
réflexion selon la profondeur. Aucune info de luminance n'est nécessaire — juste
deux couleurs et un masque.

---

### 4.4 `sh_ice.frag` — glace translucide mélangée à l'eau

**Rôle** : donner à la glace une transparence/teinte qui se fond avec l'eau en
dessous (contournement du fait que les tilemaps `tngine` ne gèrent pas
l'opacité par tuile).

**Chemin** : `game/shaders/sh_ice.frag`

```glsl
// shader used to give ice transparency but nice blending with water too
// tngine tilemaps dont play nice with opacity tiles so this is the work around for now

extern Image water; // texture for water layer
extern float mode;
vec4 cyan = vec4(0.0, 1.0, 1.0, 1.0);
vec4 ice1a = vec4(142.0/255.0, 212.0/255.0, 201.0/255.0, 1.0);
vec4 ice2a = vec4(110.0/255.0, 194.0/255.0, 184.0/255.0, 1.0);
vec4 ice3a = vec4(87.0/255.0, 173.0/255.0, 171.0/255.0, 1.0);
vec4 ice1b = vec4(187.0/255.0, 200.0/255.0, 240.0/255.0, 1.0);
vec4 ice2b = vec4(166.0/255.0, 175.0/255.0, 224.0/255.0, 1.0);
vec4 ice3b = vec4(149.0/255.0, 158.0/255.0, 208.0/255.0, 1.0);
float waterb1a = 170.0/255.0;
float waterb2a = 150.0/255.0;
float waterb1b = 100.0/255.0;
float waterb2b = 80.0/255.0;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 pixel_t = Texel(tex, texture_coords) * color;
  vec4 pixel_w = Texel(water, texture_coords) * color;
  if (pixel_t == cyan) {
    if (mode == 1) {
      if (pixel_w.b < waterb2a) {
        pixel_t.rgb = mix(pixel_w.rgb, ice3a.rgb, 0.9);
      } else if (pixel_w.b < waterb1a) {
        pixel_t.rgb = mix(pixel_w.rgb, ice2a.rgb, 0.9);
      } else {
        pixel_t.rgb = mix(pixel_w.rgb, ice1a.rgb, 0.9);
      }
    } else {
      if (pixel_w.b < waterb2b) {
        pixel_t.rgb = mix(pixel_w.rgb, ice3b.rgb, 0.9);
      } else if (pixel_w.b < waterb1b) {
        pixel_t.rgb = mix(pixel_w.rgb, ice2b.rgb, 0.9);
      } else {
        pixel_t.rgb = mix(pixel_w.rgb, ice1b.rgb, 0.9);
      }
    }
  }
  return pixel_t * color;
}
```

**Application** (`ev_draw.lua`) :

```lua
game.g.shader_ice:send('water', game.g.tilesets.water.main_canvas)
game.g.shader_ice:send('mode', tn.util.ternary(game.g.world == 'awake', 1, 2))
love.graphics.setShader(game.g.shader_ice)
  tn.draw.tilemap(game.g.tilesets.ice, 0, 0)
love.graphics.setShader()
```

**Passages clés** : les tuiles de glace sont peintes en **cyan pur** (clé). Le
shader regarde la canal **bleu** de l'eau sous-jacente (`pixel_w.b`, qui encode
la profondeur) et choisit une des trois teintes de glace, mélangée à 90% avec la
couleur de l'eau (`mix(eau, glace, 0.9)`). `mode` bascule entre palette éveillée
(`a`) et palette du rêve (`b`).

**Comment reproduire** : peindre la glace en couleur-clé, échantillonner l'eau en
dessous, choisir une teinte par seuils sur un canal, et `mix` avec l'eau pour la
translucidité simulée.

---

### 4.5 `sh_snow.frag` — neige sur le feuillage

**Rôle** : recolorer le feuillage couvert de neige (et masquer le reste) selon un
calque de neige.

**Chemin** : `game/shaders/sh_snow.frag`

```glsl
// shader used to change foliage color when covered by snow

extern Image snowtxt; // texture for snow layer
extern float mode;

vec4 snow1 = vec4(180.0/255.0, 240.0/255.0, 230.0/255.0, 1.0);
vec4 snow2 = vec4(224.0/255.0, 235.0/255.0, 255.0/255.0, 1.0);
vec4 blank = vec4(0.0, 0.0, 0.0, 0.0);

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 pixel_t = Texel(tex, texture_coords);
  vec4 pixel_s = Texel(snowtxt, texture_coords);
  if (pixel_s.a > 0.0 && pixel_t.a > 0.0) {
    if (pixel_s.b > 0.78) {
      if (mode == 2.0) {
        pixel_t.rgb = snow2.rgb;
      } else {
        pixel_t.rgb = snow1.rgb;
      }
    } else {
      pixel_t.rgba = blank.rgba;
    }
  }
  return pixel_t * color;
}
```

**Application** (`ev_draw.lua`) :

```lua
love.graphics.setShader(game.g.shader_snow)
  game.g.shader_snow:send('snowtxt', game.g.surf_foliage2.canvas)
  game.g.shader_snow:send('mode', tn.util.ternary(game.g.world == 'awake', 1, 2))
  game.g.surf_foliage1:draw()
love.graphics.setShader()
```

**Passages clés** : là où le calque de neige (`surf_foliage2` = tilemap `floor2`)
est présent **et** où le feuillage est opaque, on remplace par une couleur de
neige si la neige est « épaisse » (`pixel_s.b > 0.78`), sinon on efface le pixel
(`blank`) pour découper proprement le feuillage sous la neige. `mode` ⇒ palette
selon le monde.

**Comment reproduire** : un calque-masque de neige + color-key par seuil sur un
canal pour décider « couvert de neige » vs « caché ». Deux teintes de neige selon
l'ambiance.

---

### 4.6 `sh_night.frag` — éclairage nuit (soustraction de lightmap)

**Rôle** : appliquer l'assombrissement de nuit en **soustrayant** un lightmap
RGB à l'image. Le shader le plus important du jeu pour l'ambiance.

**Chemin** : `game/shaders/sh_night.frag`

```glsl
// shader to apply "nighttime" lighting, using specific rgb subtractions
// which are passed via the lightmap

extern Image lightmap; // texture for lightmap
extern float flash;
vec4 black = vec4(0.0, 0.0, 0.0, 1.0);
vec4 green = vec4(0.0, 1.0, 0.0, 1.0);

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 pixel_t = Texel(tex, texture_coords) * color;
  vec4 pixel_l = Texel(lightmap, texture_coords);
  if (pixel_t == green) return green;
  if (pixel_l.rgb != black.rgb) {
    pixel_t.rgb = pixel_t.rgb - pixel_l.rgb;
  }
  if (flash == 1.0) {
    pixel_t.rgb = pixel_t.rgb * 1.5;
  }
  return pixel_t;
}
```

**Application** (`ev_draw.lua`, dans `surf_screen`) :

```lua
game.g.shader_night:send('lightmap', game.g.surf_lighting.canvas)
game.g.shader_night:send('flash', tn.util.ternary(game.g.light.flash, 1, 0))
love.graphics.setShader(game.g.shader_night)
  game.g.surf_game:draw()
love.graphics.setShader()
```

**Passages clés** :

- L'éclairage est une **soustraction RGB** : `pixel - lightmap`. Le lightmap n'est
  donc pas « combien de lumière » mais « combien d'obscurité retirer à chaque
  canal ». Là où le lightmap est noir (zone éclairée par un cercle de lumière, vu
  ci-dessous), rien n'est soustrait ⇒ pleine luminosité.
- `flash` permet un éclair (×1.5) pour les orages/feedback.
- Le **vert pur est un opt-out** : un pixel exactement vert n'est jamais
  assombri (utilisé comme couleur-clé « toujours pleine lumière »).

Le **lightmap** lui-même est peint dans `surf_lighting` (cf. §5) : un rectangle
sombre (la nuit) puis des **cercles** soustractifs autour des sources de lumière.

> Le même `shader_night` est réutilisé partout dans le pipeline avec des lightmaps
> différents : `surf_lighting` (vrai éclairage du monde), `surf_black` (teinte
> plate pour les menus), `surf_blank` (neutre pour la composition finale).

**Comment reproduire** : rends ta scène dans un canvas. Rends un lightmap (noir =
plein jour, couleur sombre = obscurité ; perce des trous noirs avec des cercles
« additifs » autour des lampes). Compose `scène - lightmap` via un shader. Pour
la couleur de nuit, utilise des soustractions asymétriques par canal (p. ex.
retirer plus de bleu/vert que de rouge pour une nuit chaude).

---

### 4.7 `sh_player.frag` — swap de palette (recoloration)

**Rôle** : recolorer le sprite du joueur (et d'autres créatures) à partir d'une
palette de 6 couleurs envoyées en uniformes. Sprite peint en couleurs primaires
RGB pures + cyan/jaune/rose comme clés.

**Chemin** : `game/shaders/sh_player.frag`

```glsl
// shader used to convert player palette
// this is 6 colors, primary color in 3 shades,
// an optional secondary color in 2 shades (for spots)
// and then the cheek color

vec4 blue =   vec4(0.0, 0.0, 1.0, 1.0); // primary light
vec4 green =  vec4(0.0, 1.0, 0.0, 1.0); // primary mid
vec4 red =    vec4(1.0, 0.0, 0.0, 1.0); // primary dark
vec4 cyan =   vec4(0.0, 1.0, 1.0, 1.0); // secondary light
vec4 yellow = vec4(1.0, 1.0, 0.0, 1.0); // secondary dark
vec4 pink =   vec4(1.0, 0.0, 1.0, 1.0); // check

extern vec4 pal1;
extern vec4 pal2;
extern vec4 pal3;
extern vec4 pal4;
extern vec4 pal5;
extern vec4 pal6;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texcolor = Texel(tex, texture_coords);
  if (texcolor.a == 1.0) {
    texcolor.a = color.a;
  }
  if (texcolor.rgb == blue.rgb) texcolor.rgb = pal1.rgb;
  if (texcolor.rgb == green.rgb) texcolor.rgb = pal2.rgb;
  if (texcolor.rgb == red.rgb) texcolor.rgb = pal3.rgb;
  if (texcolor.rgb == cyan.rgb) texcolor.rgb = pal4.rgb;
  if (texcolor.rgb == yellow.rgb) texcolor.rgb = pal5.rgb;
  if (texcolor.rgb == pink.rgb) texcolor.rgb = pal6.rgb;
  return texcolor;
}
```

**Application** (`cl_player.lua > scripts.draw`) :

```lua
love.graphics.setShader(game.g.shader_player)
  local px = math.floor(self.x - game.g.camera.draw_x)
  local py = math.floor(self.y - game.g.camera.draw_y)
  tn.draw.sprite(self.sprite_id, self.sprite_frame, px + self.scale_ox, py + self.scale_oy,
    0, self.scale_x, self.scale_y, 0, 0,
    tn.util.ternary(game.g.dev_ignore_walls, 0.3, 1))
love.graphics.setShader()
```

Les 6 couleurs de palette sont des `pal1..pal6` envoyées avant le `setShader`
(les palettes par défaut/par espèce sont dans `md_globals.lua`, ex. `player =
{'#4f7d69','#426e61','#2d4d4b','#426e61','#2d4d4b','#cc6677'}` et `trait1..7`,
`mushroom1..24`, etc.). Le même shader sert pour les grenouilles, les variants,
le livre (`cl_book.lua`), le disco (`cl_disco.lua`), les ascenseurs.

**Passages clés** : color-key par couleur primaire pure ⇒ remplacement par la
couleur de palette. 3 nuances pour la couleur primaire (light/mid/dark), 2 pour
la secondaire (taches), 1 pour les joues. Le canal alpha du sprite est multiplié
par l'alpha de dessin (`color.a`) pour gérer le fondu.

**Comment reproduire** : dessine tes sprites en niveaux de « couleurs-index »
(rouge/vert/bleu/cyan/jaune/magenta purs), envoie 6 uniformes de couleur, et
remplace. C'est de la recoloration sans table de palette texture — idéal pour
générer des variantes de créatures à la volée (très pertinent pour The Pit).

---

### 4.8 `sh_paint.frag` — blend « quantum painted »

**Rôle** : effet de surbrillance « onirique » sur les objets peints (quantum
paint), en ajoutant une teinte bleu-rêve et en perçant le fond.

**Chemin** : `game/shaders/sh_paint.frag`

```glsl
// shader to make a fancy blend for quantum painted objs

vec4 dream = vec4(193.0/255.0,219.0/255.0,252.0/255.0,1.0);
vec4 black1 = vec4(39.0/255.0,31.0/255.0,69.0/255.0,1.0);
vec4 black2 = vec4(32.0/255.0,48.0/255.0,54.0/255.0,1.0);

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texcolor = Texel(tex, texture_coords);
  if (texcolor.rgb == black1.rgb || texcolor.rgb == black2.rgb) discard;
  texcolor.rgb += dream.rgb * 0.4;
  return texcolor * color;
}
```

**Application** (`ev_draw.lua` et `md_world.lua > drawObjs`) :

```lua
if game.g.highlighted_obj ~= nil and game.g.highlighted_obj.props.qpaint then
  love.graphics.setShader(game.g.shader_paint)
  game.g.highlighted_obj:draw()
  love.graphics.setShader()
end
-- et un second passage pour tous les objets 'qpaint' de la couche :
love.graphics.setShader(game.g.shader_paint)
for i=1,#painted do painted[i]:draw() end
love.graphics.setShader()
```

**Passages clés** : `discard` des deux noirs (clés des contours sombres awake/
dream) pour ne garder que la matière, puis ajout additif d'une teinte bleu-rêve à
40%. Effet d'aura sans texture supplémentaire.

**Comment reproduire** : additionne une teinte à `texcolor.rgb` et `discard` les
couleurs de contour pour un effet « brillant/spectral » bon marché.

---

### 4.9 `sh_void.frag` — zones de vide transparentes / transitions

**Rôle** : rendre transparentes les zones marquées « void » pour laisser voir une
couche en dessous (le vide, le rêve), et piloter les transitions d'écran.

**Chemin** : `game/shaders/sh_void.frag`

```glsl
// shader used to turn void areas (marked as 010rgb) transparent to show the void (or whatever else you might want!)

extern Image gamemap; // texture of where fluid is
extern Image voidmap; // texture of where fluid is
extern float prog;
vec4 mask = vec4(0.0, 0.0, 0.0, 1.0);
vec4 blue = vec4(0.0, 0.0, 1.0, 1.0);
vec4 blank = vec4(0.0, 0.0, 0.0, 0.0);

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texcolor = Texel(tex, texture_coords);
  vec4 gamecolor = Texel(gamemap, texture_coords);
  vec4 voidcolor = Texel(voidmap, texture_coords);
  if (texcolor.rgb == mask.rgb) return blank;
  if (texcolor.rgb == blue.rgb) {
    if (gamecolor.rgb == mask.rgb) {
      gamecolor.rgb = voidcolor.rgb;
    }
    gamecolor.r -= prog;
    gamecolor.g -= prog*2;
    gamecolor.b -= prog;
    return gamecolor;
  }
  return texcolor * color;
}
```

**Application** (`ev_draw.lua`) — composition finale et transitions :

```lua
-- composition finale de surf_screen
love.graphics.setShader(game.g.shader_void)
  game.g.surf_screen:draw(-game.g.camera.frac_x, -game.g.camera.frac_y, 0, game.g.game_scale, game.g.game_scale)
love.graphics.setShader()

-- transition (cercle qui s'ouvre/ferme) : prog = ratio d'avancement
if game.g.transition ~= nil then
  game.g.shader_void:send('gamemap', game.g.surf_screen.canvas)
  game.g.shader_void:send('voidmap', game.g.surf_void.canvas)
  game.g.shader_void:send('prog', game.g.transition.props.ratio)
  love.graphics.setShader(game.g.shader_void)
    love.graphics.draw(game.g.transition.props.surf, 0, 0)
  love.graphics.setShader()
end
```

**Passages clés** : le noir pur (`mask`) devient transparent (`blank`) ⇒ les
trous de la transition laissent voir dessous. Le bleu pur (`blue`) est remplacé
par l'image de jeu (`gamemap`), avec un assombrissement progressif `prog` (plus
sur le vert) pour le fondu de transition vers le vide.

**Comment reproduire** : un masque de transition dessiné dans un mini-canvas
(cercle, étoile…) + un shader qui interprète des couleurs-clés comme « montre le
jeu » / « montre le vide » / « transparent », piloté par un `prog` animé de 0→1.

---

### 4.10 `sh_test.frag` — shader de dev (inutilisé)

**Rôle** : assombrir tout — uniquement pour tester localement. Chargé mais non
utilisé en prod.

**Chemin** : `game/shaders/sh_test.frag`

```glsl
// unused - just used for local dev shader testing

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 pixel_t = Texel(tex, texture_coords);
  pixel_t.rgb -= 0.6;
  return pixel_t * color;
}
```

---

### 4.11 Récapitulatif des shaders

| Shader | Rôle | Technique | Entrées clés |
|---|---|---|---|
| `sh_outline` | contour 1px | tout opaque → blanc, dessiné 4× décalé | — |
| `sh_fluid` | ondulation eau | distorsion UV sinusoïdale + masque | `fluid`, `time`, `height`, `cy` |
| `sh_shadows` | recolore réflexions | color-key sur masque d'eau | `fluid`, `deep`, `deeper` |
| `sh_ice` | glace translucide | color-key cyan + mix avec eau | `water`, `mode` |
| `sh_snow` | neige sur feuillage | masque neige + seuil + recolor | `snowtxt`, `mode` |
| `sh_night` | éclairage nuit | **soustraction** d'un lightmap RGB | `lightmap`, `flash` |
| `sh_player` | swap palette | color-key 6 couleurs primaires | `pal1..pal6` |
| `sh_paint` | aura onirique | add teinte + discard contours | — |
| `sh_void` | void/transitions | color-key transparent + fondu `prog` | `gamemap`, `voidmap`, `prog` |
| `sh_test` | dev | assombrit tout | — |

Le **fil conducteur** : tout repose sur le **color-keying** (couleurs pures
comme sémantique) et la **composition multi-canvas**. Aucun shader n'est coûteux ;
tout le « rendu riche » vient de l'orchestration de canvas dans `ev_draw.lua`.

---

## 5. Ambiance jour/nuit & météo

### 5.1 Le temps

Dans `md_globals.lua` :

```lua
time = (60*7),              -- 1 vraie seconde = 1 minute de jeu (donc 1 vraie minute = 1h)
time_dawn_start = 60*5,     -- 05:00
time_day_start = 60*7,      -- 07:00
time_dusk_start = 60*19,    -- 19:00
time_night_start = 60*21,   -- 21:00
day = 1, tod = 'day', world = 'awake',
weather = false, weather_alpha = 0,
weather_start = (60*8), weather_end = (60*16),
```

### 5.2 Le niveau de lumière (`light_level`)

Calculé chaque frame dans `ev_step.lua` via `game.world.setLightLevel()`
(`md_world.lua`). `light_level` va de 0 (plein jour) à 1 (pleine nuit), avec des
**transitions linéaires** à l'aube et au crépuscule :

```lua
setLightLevel = function()
  local original_tod = game.g.tod
  local lvl = game.g.light_level
  if game.g.time >= game.g.time_day_start and game.g.time < game.g.time_dusk_start then
    lvl = 0; game.g.tod = 'day'
  elseif game.g.time >= game.g.time_dusk_start and game.g.time < game.g.time_night_start then
    local ratio = (game.g.time - game.g.time_dusk_start) / (game.g.time_night_start - game.g.time_dusk_start)
    lvl = ratio; game.g.tod = 'dusk'
  elseif game.g.time >= game.g.time_night_start or game.g.time < game.g.time_dawn_start then
    lvl = 1; game.g.tod = 'night'
  elseif game.g.time >= game.g.time_dawn_start and game.g.time < game.g.time_day_start then
    local ratio = (game.g.time - game.g.time_dawn_start) / (game.g.time_day_start - game.g.time_dawn_start)
    lvl = 1 - ratio; game.g.tod = 'dawn'
  end
  if game.g.weather == true and game.g.world == 'awake' then
    if lvl < 0.2*game.g.weather_alpha then lvl = 0.2*game.g.weather_alpha end  -- la pluie assombrit un minimum
  end
  if game.g.world == 'dream' or game.g.player.props.dreaming then lvl = lvl + 0.5 end
  if game.g.player.props.is_inside then lvl = 0 end                            -- l'intérieur est éclairé
  if game.g.controller.props.splash.props.state < 4 then lvl = 0 end
  game.g.light_level = lvl
  if original_tod ~= game.g.tod then game.world.todChange() end                -- déplace les NPC, etc.
end
```

### 5.3 Le lightmap (cercles soustractifs)

`light_level` pilote la peinture du lightmap dans `surf_lighting` (`ev_draw.lua`).
Les couleurs de nuit par monde sont dans `md_globals.lua` :

```lua
-- "ces valeurs RGB sont SOUSTRAITES aux valeurs réelles pour produire les couleurs de nuit"
light = {
  awake = { dark = {90, 120, 30}, light2 = {60, 80, 40}, light1 = {30, 40, 50} },
  dream = { dark = {10, 50, 20}, light2 = {5, 30, 20}, light1 = {0, 10, 20} },
  flash = false
},
light_level = 0,
```

Construction du lightmap (`ev_draw.lua`) :

```lua
game.g.surf_lighting:write(true, {0, 0, 0, 1}, function()
  -- 1) remplir tout l'écran avec la "noirceur" (dark * light_level)
  tn.draw.color(game.g.light[game.g.world].dark[1]*game.g.light_level,
                game.g.light[game.g.world].dark[2]*game.g.light_level,
                game.g.light[game.g.world].dark[3]*game.g.light_level)
    love.graphics.rectangle('fill', 0, 0, game.g.game_width+1, game.g.game_height+1)

  -- 2) cercles extérieurs (light2) autour du joueur et des objets émetteurs
  tn.draw.color(game.g.light[game.g.world].light2[1]*game.g.light_level, ...)
    love.graphics.circle('fill', px, py, 26)
  for i=1,#tn.internals.activeobjs do
    local obj = tn.internals.activeobjs[i]
    if obj.props.lighting and not obj.props.covered and obj.visible then
      love.graphics.circle('fill', ox + lighting[2], oy + lighting[3], lighting[4])
    end
  end

  -- 3) cercles intérieurs (light1, plus clairs) — même boucle, rayon lighting[5]
  ...
end)
```

Comme `shader_night` **soustrait** ce lightmap, peindre un cercle moins sombre
(`light1 < light2 < dark`) « creuse » un halo de lumière autour des sources. Plus
`light_level` est haut (nuit), plus la base est sombre et plus les halos
ressortent. Une lampe d'objet est définie par
`obj.props.lighting = { monde, offset_x, offset_y, rayon_ext, rayon_int, [cond] }`.

### 5.4 Météo (pluie / neige)

- **Activation** (`ev_tock.lua`, chaque seconde) : `weather` est vrai entre
  `weather_start` et `weather_end`. Un nouveau jour (`md_world.newDay`) tire des
  horaires de pluie aléatoires et alterne « jour de pluie / jour sec ».
- **Fondu** (`ev_step.lua`) : `weather_alpha` monte/descend en douceur autour des
  bornes (`+/- 0.1*dt`), ce qui module l'opacité des particules **et** la lumière
  minimale et le volume de l'ambiance pluie.
- **Particules** (`ev_step.lua`) : selon la région, on émet `snow_` ou `raindrop_`
  via le système de particules, dans une zone autour de la caméra :

```lua
local region = game.collision.getRegion(game.g.player.x, game.g.player.y)
if game.g.weather == true then
  local weather_fx = tn.util.ternary(region == 4, 'snow_', 'raindrop_')   -- région 4 = enneigée
  local weather_amount = tn.util.ternary(region == 4, 1, 2)
  game.g.psystem_robj:createRegion(weather_fx .. game.g.world,
    game.g.camera.draw_x-64, game.g.camera.draw_y-64,
    game.g.game_width+128, game.g.game_height+128, weather_amount*game.g.weather_alpha)
  -- éclaboussures de pluie sur l'eau / l'herbe (sprites fx selon la tuile)
  ...
end
```

- **Rendu** : les particules de pluie sont dessinées avec
  `tn.draw.alpha(game.g.weather_alpha)` pour le fondu global. La neige (région 4)
  est ce qui alimente `sh_snow` (le calque `floor2`/`foliage2` sert de masque de
  neige).

### 5.5 Monde « rêve » vs « éveillé »

`world` (`'awake'` / `'dream'`) double tout : deux spritesheets, deux tilesets,
deux palettes de couleurs d'eau (`waters.awake` / `waters.dream`), deux jeux de
couleurs de nuit (`light.awake` / `light.dream`). Le passage se fait par une
transition (`shader_void`) et un `replacePixels` du tileset. C'est la même scène,
recolorée — un excellent exemple de réutilisation d'assets via shaders/palettes.

---

## 6. Animation & game feel

### 6.1 Sprites animés

Chaque objet a `sprite_speed` (secondes/frame). L'avance se fait dans `_tick`
(10 Hz) du moteur (`tn_core.lua`) :

```lua
for i=1,#tn.internals.activeobjs do
  local inst = tn.internals.activeobjs[i]
  if inst.sprite_speed > 0 then
    inst.sprite_incr = inst.sprite_incr + 0.1
    if inst.sprite_incr >= inst.sprite_speed then
      inst.sprite_frame = inst.sprite_frame + 1
      inst.sprite_incr = 0
      if inst.sprite_frame > #tn.internals.sprites[inst.sprite_id].frames then
        inst:call('animend')   -- hook de fin d'anim
        inst.sprite_frame = 1
      end
    end
  end
end
```

Le hook `animend` permet de chaîner des animations (ex. une machine qui revient à
l'idle après son cycle).

### 6.2 Tweening : courbes de Bézier (`tn.class.animcurve`)

`tn.class.animcurve` (`tn_animcurve.lua`) est un wrapper sur
`love.math.newBezierCurve` pour des trajectoires/easings personnalisés :

```lua
set = function(self, ...)
  self:reset()
  local args = {...}
  if args[1] ~= nil then
    self.curve = love.math.newBezierCurve(unpack(args))
    self.curvev = 0
  end
end,
anim = function(self, amount)
  self.curvev = self.curvev + amount
  if self.curvev > 1 then self.curvev = 1 end
  return self:get()   -- évalue la courbe à curvev (0..1)
end,
```

C'est utilisé pour des mouvements « juteux » (sauts de têtards, pop d'items, etc.)
où l'on veut une accélération non linéaire facile à définir avec des points de
contrôle.

Pour les easings simples, `tn.util.lerp(a, b, t)` et `tn.util.eerp(a, b, t)`
(lerp exponentiel) suffisent — le mouvement caméra est un `moveTowards` lerpé
(`ev_step.lua` : `game.g.camera:moveTowards(tx, ty, ts)` avec
`camera_speed = 0.05`).

### 6.3 Particules (`tn.class.particlesystem`)

Système maison léger : définitions de particules dans `tn.internals.particles`,
6 systèmes globaux dans `md_globals.lua` (`psystem_bobj`, `psystem_aobj`,
`psystem_robj` pour la météo, `psystem_vobj` pour le void, etc.). Les particules
ont vitesse, direction, accélération, gravité (avec cap), durée de vie, délai.
`update` les fait avancer et supprime les mortes ; `draw` est **manuel** (appelé
dans `ev_draw` à la bonne couche). Pratique :

```lua
createRegion = function(self, particle_id, x, y, w, h, amount)
  for p=1,amount do
    self:create(particle_id, love.math.random(x, x+w), love.math.random(y, y+h))
  end
end,
```

`createRaw` renvoie une particule modifiable avant insertion (`insertRaw`) — utile
pour étaler des durées de vie (ex. les jets d'eau « stream » dans `loadMap`).

### 6.4 Surbrillance et feedback au survol

Le moteur calcule chaque frame l'objet/menu/ui survolé (`tn_core.lua > _step`,
via AABB sur la position souris convertie en coordonnées monde). Le feedback
visuel :

- **Objet survolé** : contour blanc via `sh_outline` (4 passes) + un sprite
  `sp_obj_highlight` au-dessus, et redessin de l'objet **par-dessus l'éclairage**
  (`surf_screen`) pour qu'il reste lumineux.
- **UI survolée** : la frame de sprite passe à `sprite_frame+1` (cf. §7).
- **Curseur** : sprite personnalisé (`game.g.mouse`), `love.mouse.setVisible(false)`.

La conversion souris→monde (essentielle pour un jeu scalé) est dans `_step` :

```lua
tn.mouse.x = love.mouse.getX()
tn.mouse.y = love.mouse.getY()
tn.mouse.rx = (tn.mouse.x/tn.g.game_scale) + tn.internals.view.draw_x
tn.mouse.ry = (tn.mouse.y/tn.g.game_scale) + tn.internals.view.draw_y
tn.mouse.gx = tn.util.gridpos(tn.mouse.rx)
tn.mouse.gy = tn.util.gridpos(tn.mouse.ry)
```

---

## 7. UI / UX

### 7.1 Architecture : menus + UI

- **`tn.class.menu`** : un panneau (éventuellement déplaçable, relatif à la
  caméra ou non) qui contient une liste de `ui`.
- **`tn.class.ui`** (`tn_ui.lua`) : un élément cliquable lié à un menu, avec
  `props`/`scripts`/`alarms` comme un objet. Position **relative** au menu parent.
- Le moteur gère le survol/clic/drag de tout ça via `tn.highlighted` /
  `tn.dragging` recalculés chaque frame, triés par `depth`.

`md_ui.lua` (≈95 KB) est l'usine à menus du jeu (création/positionnement de tous
les panneaux : inventaire, shop, livres, machines, options…). Les classes UI
spécialisées sont dans `game/ui/` (`ui_button`, `ui_tank`, `ui_picker`,
`ui_slot`, `ui_lilypad`, `ui_traitkey`, etc.).

### 7.2 Le dessin par défaut d'une UI (feedback de survol)

Le cœur du feedback hover est dans `tn.class.ui:drawself()` (`tn_ui.lua`) — c'est
le pattern « frame N normale / frame N+1 survolée », appliqué aussi aux 9-patch :

```lua
drawself = function(self)
  local sx = math.floor(self.x - tn.internals.view.draw_x)
  local sy = math.floor(self.y - tn.internals.view.draw_y)
  if self.voffset_x then sx = sx + self.voffset_x end
  if self.voffset_y then sy = sy + self.voffset_y end
  -- survolé / sélectionné / en cours de drag -> frame +1
  local sf = tn.util.ternary(tn.highlighted.ui == self.id or self.selected or self.dragging,
                             self.sprite_frame+1, self.sprite_frame)
  if tn.internals.sprites[self.sprite_id].slice then
    tn.draw.slice(self.sprite_id, sf, sx, sy, self.width, self.height)  -- 9-patch
  else
    tn.draw.sprite(self.sprite_id, sf, sx, sy)
  end
  return sx, sy
end,
```

Convention forte du projet : **la frame suivante d'un sprite d'UI est l'état
survolé**. Pas de teinte programmatique, pas de scale — juste un swap de frame,
ce qui laisse l'artiste contrôler totalement le rendu hover/pressed.

### 7.3 `ui_button.lua` — le bouton (état, feedback, audio)

`game/ui/ui_button.lua` (≈28 KB) étend `tn.class.ui`. Sa création gère le label,
la validité, et un éventuel **9-patch** (`slice`) pour des boutons de taille
arbitraire :

```lua
new = function(self, x, y, spr, menu, type, label, slice)
  local ui = tn.class.ui:new(x, y, spr, menu, type)
  ui:extend(self)
  ui:define({
    label = label, valid = true, value = '', slice = nil, count = 0,
    hybrid = '', mushroom = '', mindex = 0, color = game.g.colors.font_white
  })
  if slice ~= nil then
    ui.props.slice = slice
    ui.width = slice.width+5
    ui.height = slice.height+5
    ui.bbox.r = slice.width+4
    ui.bbox.b = slice.height+4
    if slice.sprite_frame then ui.sprite_frame = slice.sprite_frame end
  end
  return ui
end,
```

Son `draw` montre toute la logique de feedback (survol → frame+1, invalide →
frame 3, label recoloré au survol, icônes, compteurs, décals « home_ ») :

```lua
draw = function(self, x, y)
  local highlighted = game.g.highlighted_ui == self
  if self.props.slice ~= nil then
    local slice = self.props.slice
    -- 9-patch : frame+1 si survolé
    tn.draw.slice(slice.sprite_id, tn.util.ternary(highlighted, self.sprite_frame+1, self.sprite_frame),
                  x, y, slice.width, slice.height)
    if self.type:find('home_') then
      tn.draw.sprite('sp_button_decal', tn.util.ternary(highlighted, 2, 1), x+4, y+4)
      tn.draw.sprite('sp_button_decal', tn.util.ternary(highlighted, 4, 3), x+slice.width-4, y+4)
    end
  else
    local sx, sy = self:drawself()
    if self.type == 'achievement' then
      local prog = game.g.settings.achievements[self.props.index]
      if prog ~= true then tn.draw.sprite(self.sprite_id, 25, sx, sy) end
    end
  end
  -- état invalide : overlay frame 3
  if not self.props.valid then
    if self.props.slice ~= nil then
      tn.draw.slice(self.sprite_id, 3, x, y, self.props.slice.width, self.props.slice.height)
    else
      tn.draw.sprite(self.sprite_id, 3, x, y)
    end
  end
  -- label centré, recoloré au survol
  if self.props.label then
    local baseline = math.floor(self.height/2)-5
    tn.draw.text(self.props.label, x+1, y+baseline,
      tn.util.ternary(highlighted, game.g.colors.font_white, self.props.color), nil, self.width, 'center')
  end
  -- ... overlay 'qsave' pendant la sauvegarde, icônes d'item, compteurs, mushrooms ...
end,
```

Le **clic** déclenche d'abord le son, puis branche sur le `type` du bouton (la
méthode `click` est un gros routeur de ~600 lignes : `home_*`, `settings_*`,
`a11y_*`, `fileslot_*`, `color_*`, `bed_sleep*`, `trade`, `npcnext`,
`picker_option`, `chapter_next`, liens externes, etc.). L'essentiel pour le
feel :

```lua
click = function(self, btn, menu)
  game.g.audio:call('play', 'click')   -- FEEDBACK AUDIO IMMÉDIAT à chaque clic
  local inst = self:getMenu().inst
  if self.type == 'home_start' then
    game.g.controller.props.splash:close()
    menu:close()
    game.g.controller.props.files:open()
    ...
  elseif self.type:find('settings_') then
    ...  -- toggles, sliders volume, scaling, fullscreen (changent la frame à 3 = "actif")
    game.world.saveSettings()
  elseif self.type:find('color_') then
    menu.props.color = self.type
    menu.props.palette = game.g.colors[self.type:gsub('color_', '')]
    game.g.audio:call('play', 'chime' .. tostring(love.math.random(1, 7)))  -- son varié
  ...
  end
end,
```

À noter : les **toggles** (vsync on/off, plein écran, accessibilité) passent leur
sprite_frame à `3` (état « enfoncé/actif ») et remettent le bouton opposé à `1` —
encore une fois, l'état visuel = un index de frame.

### 7.4 Pipeline de clic du moteur

L'ordre de traitement d'un clic (`tn_core.lua > _mousepressed`) : marque le bouton
comme down, gère le drag de menu/ui, **appelle le hook utilisateur**
(`game.event.mouse`), puis dispatche au `obj`/`ui`/`menu` survolé :

```lua
-- ui survolée
if tn.highlighted.ui ~= nil then
  local ui = tn.internals.uis[tn.highlighted.ui]
  if ui then
    local menu = ui:getMenu()
    if menu.is_open then ui:click(button) end
  end
end
```

`ui:click` n'appelle le script `click` que si l'élément est `visible`. C'est un
**feedback différé court** : le pointer-down est immédiat (son + état), l'action
peut suivre.

### 7.5 9-patch (`tn.draw.slice`)

Pour des panneaux/boutons de taille variable, `tngine` fournit un vrai 9-slice
(`tn_draw.lua`), en mode `stretch` ou `repeat`. C'est ce qui permet aux tooltips,
panneaux et boutons d'épouser n'importe quelle dimension à partir d'un petit
sprite. Extrait (mode stretch) :

```lua
slice = function(slice_id, frame_index, x, y, width, height, opacity, mode)
  local slice = tn.internals.sprites[slice_id].frames[frame_index]
  -- 4 coins
  love.graphics.draw(slice.texture, slice.tl.frames[1], x+slice.tl_offset_x, y)
  love.graphics.draw(slice.texture, slice.tr.frames[1], x+slice.tr_offset_x+width, y)
  love.graphics.draw(slice.texture, slice.bl.frames[1], x+slice.bl_offset_x, y+slice.m_offset_y+height)
  love.graphics.draw(slice.texture, slice.br.frames[1], x+slice.br_offset_x+width, y+slice.m_offset_y+height)
  if mode == 'stretch' then
    -- bords + centre étirés (scale en X ou Y)
    love.graphics.draw(slice.texture, slice.tm.frames[1], x+slice.tm_offset_x, y, 0, width, 1)
    love.graphics.draw(slice.texture, slice.ml.frames[1], x+slice.ml_offset_x, y+slice.t_offset_y, 0, 1, sh)
    love.graphics.draw(slice.texture, slice.mr.frames[1], x+slice.mr_offset_x+width, y+slice.t_offset_y, 0, 1, sh)
    love.graphics.draw(slice.texture, slice.bm.frames[1], x+slice.bm_offset_x, y+slice.m_offset_y+height, 0, width, 1)
    love.graphics.draw(slice.texture, slice.mm.frames[1], x+slice.mm_offset_x, y+slice.t_offset_y, 0, sw, sh)
  else
    -- mode repeat : on répète les bords/centre par portions
    ...
  end
end,
```

### 7.6 Le livre (`cl_book.lua`)

`cl_book.lua` (≈1228 lignes) est l'interface de codex/quêtes (les « lilypads » de
chapitres, les pages illustrées). Il réutilise `shader_player` pour recoloriser
des sprites de créatures dans les pages :

```lua
love.graphics.setShader(game.g.shader_player)
  -- envoi pal1..pal6 selon l'espèce
  ... draw sprite ...
love.graphics.setShader()
```

C'est cohérent avec le reste : **un seul shader de palette** sert au monde, à
l'UI et aux illustrations du livre.

---

## 8. Audio (feedback)

### 8.1 La classe `audio` (`cl_audio.lua`)

`game.class.audio` est un objet `tngine` (`oid='audio'`, persistant) qui charge
**tous** les SFX en `static` et l'ambiance/musique en `stream`, dans une grande
table `props.sfx` :

```lua
sfx = {
  click    = { love.audio.newSource('game/resources/sound/click.ogg', 'static'), 0.03},
  open     = { love.audio.newSource('.../open.ogg', 'static'), 0.05},
  rollover = { love.audio.newSource('.../rollover.ogg', 'static'), 0.05},
  error    = { love.audio.newSource('.../error.ogg', 'static'), 0.05},
  -- familles à variantes : la valeur est un NOMBRE = nb de variantes
  splash = 4,
  splash_1 = { love.audio.newSource('.../splash_1.ogg', 'static'), 0.4},
  ...
  step_grass = 8, step_grass_1 = {...}, ...
  frog = 8, frog_1 = {...}, ...
},
```

Chaque entrée est `{ source, volume_de_base }`. Les **familles** (clé = nombre N)
permettent de jouer une variante aléatoire parmi N, avec un pitch légèrement
randomisé — c'est ce qui évite la fatigue auditive (pas) :

```lua
play = function(self, sound)
  if game.g.player.props.dreaming or game.g.controller.props.splash.is_open then return nil end
  local source = nil
  if type(self.props.sfx[sound]) == 'number' then
    -- famille : on tire une variante au hasard + pitch 0.90..1.10
    source = self.props.sfx[sound .. '_' .. tostring(love.math.random(1, self.props.sfx[sound]))]
    if source ~= nil then source[1]:setPitch(love.math.random(90, 110)/100) end
  else
    source = self.props.sfx[sound]
  end
  if source ~= nil then
    source[1]:stop()
    source[1]:setVolume(source[2] * (self.props.sfx_level/10))   -- volume base * réglage joueur
    source[1]:play()
  end
end,
```

### 8.2 Ambiance et musique adaptatives

La méthode `step` (appelée chaque frame) **mixe en continu** plusieurs pistes
d'ambiance selon l'heure (`day_lvl`/`night_lvl` calculés exactement comme
`setLightLevel`), le monde (`awake`/`dream`) et la météo. Deux versions de chaque
piste de musique (`a` = éveillé, `b` = rêve) jouent en parallèle, on ne fait que
monter/descendre leurs volumes — crossfade gratuit entre les deux mondes :

```lua
self.props.ambience.day_awake[1]:setVolume(day_lvl * (ambience_level/10) * base * awake_lvl * silence)
self.props.ambience.night_awake[1]:setVolume(night_lvl * ... * awake_lvl * silence)
self.props.ambience.rain[1]:setVolume(game.g.weather_alpha * ... )
-- filtre lowpass quand on est à l'intérieur :
if game.g.player.props.is_inside then
  source[1]:setFilter({ type = 'lowpass', volume = source[1]:getVolume() * 0.9, highgain = 0.1 })
end
```

Toutes les pistes d'ambiance sont lancées en boucle à volume 0 dès le départ
(`source:setLooping(true); setVolume(0); play()`), et on ne joue que sur le
volume — pas de start/stop, donc pas de clics ni de latence.

### 8.3 Où le feedback est déclenché

- **UI** : `game.g.audio:call('play', 'click')` au début de chaque
  `ui_button:click` ; `chime`/`chimes` variés pour les actions « positives »
  (choix de couleur, complétion de chapitre).
- **Monde** : pas/water/wood/mud lors des déplacements ; `splash`, `saw`,
  `hammer`, `chop`, `net`, `frog` lors des interactions.
- **Règle** : un son par interaction, joué via `play` qui coupe l'instance
  précédente (`source:stop()` avant `play()`) — pas d'empilement.

---

## 9. Ce qu'on vole pour The Pit

Sélection des techniques les plus directement transposables au moteur Lua/LÖVE de
The Pit, avec un mini « comment l'appliquer ».

1. **Outline 1px par shader + 4 passes décalées** (`sh_outline`).
   *Pourquoi* : surbrillance lisible des cartes/monstres survolés sans dessiner de
   sprite de contour.
   *Comment* : `discard` les pixels non-opaques, renvoie blanc ; dessine la carte
   4× décalée de ±1px sous le shader, puis la carte normale par-dessus. Couleur de
   contour = `white * color`, donc teintable (passe la couleur de faction).

2. **Swap de palette par color-key** (`sh_player`, 6 uniformes).
   *Pourquoi* : The Pit génère des créatures procédurales — recoloriser des sprites
   « index » par faction/rareté/variant sans dupliquer les assets.
   *Comment* : peins les sprites en rouge/vert/bleu/cyan/jaune/magenta purs (3
   nuances primaires, 2 secondaires, 1 accent), envoie `pal1..pal6`, remplace. Zéro
   texture de palette.

3. **Éclairage par soustraction de lightmap** (`sh_night` + cercles).
   *Pourquoi* : ambiance grimdark, halos autour des entités/sigils actifs, mise en
   valeur du front de combat.
   *Comment* : rends la scène dans un canvas ; peins un lightmap (rectangle sombre
   = base, cercles plus clairs autour des sources) ; compose `scène - lightmap`.
   Anime l'intensité (pulsation d'un sigil = rayon de cercle animé).

4. **Pipeline multi-canvas + composition finale scalée** (`tn.class.surface` +
   `ev_draw`).
   *Pourquoi* : séparer proprement sol / entités / FX / UI, appliquer des shaders
   par couche, garder un rendu pixel-perfect.
   *Comment* : un canvas basse-résolution par couche logique, `surface:write(clear,
   col, fn)`, puis `setShader; surf:draw(); setShader()` pour composer. Scale entier
   à la toute fin, **sous-pixel caméra appliqué seulement à la composition**.

5. **Réflexion « fausse » : silhouette noire retournée + ondulation + recolor**
   (`sh_fluid` + `sh_shadows`).
   *Pourquoi* : si The Pit a une arène avec sol réfléchissant / sang / mare, c'est
   l'effet « miroir » le moins cher possible.
   *Comment* : redessine les entités en noir, scale Y négatif, dans un canvas ;
   ondule les UV par `sin(time + uv.y*freq)*amp` minuscule masqué par la zone ;
   recolore la silhouette par color-key.

6. **Mini-moteur « objet = data + scripts + alarms »** (`tn.class.obj` +
   `extend`/`call` + alarmes décomptées dans un tick 10 Hz).
   *Pourquoi* : modéliser proprement les entités de combat, leurs cooldowns et
   leurs effets différés sans machine à états ad hoc.
   *Comment* : `props` pour les données, `scripts` pour les comportements,
   `obj:alarm(i, t)` pour un effet retardé (parfait pour des cooldowns
   déterministes si tu remplaces le temps mur par des ticks de sim).

7. **Boucle multi-cadence (step/tick/tock)** (`tn_core`).
   *Pourquoi* : séparer la sim/animation rapide (frame), la logique moyenne
   (0.1 s) et les événements lents (1 s) — cohérent avec la frontière SIM/présentation de The Pit.
   *Comment* : accumulateurs de delta avec seuils ; le `step` reste pour la
   présentation, le `tick/tock` pour des cadences fixes déterministes.

8. **UI : feedback hover par swap de frame + 9-patch** (`tn.class.ui:drawself`,
   `tn.draw.slice`).
   *Pourquoi* : The Pit veut des boutons/cartes/panneaux au même niveau de craft,
   avec hover/press francs.
   *Comment* : convention « frame N = normal, N+1 = survol, 3 = désactivé/actif » ;
   un 9-patch pour les conteneurs de taille variable (frames `tl/tm/tr/ml/mm/...`).

9. **Audio à variantes + pitch random + volume-only** (`cl_audio`).
   *Pourquoi* : feedback de combat (impacts, déclenchements) sans répétition
   robotique ; ambiances qui se croisent sans clic.
   *Comment* : familles de N variantes (clé numérique), `setPitch(0.9..1.1)`,
   `stop()` avant `play()` ; ambiances lancées en boucle à volume 0 et pilotées
   seulement par le volume (crossfade gratuit).

10. **Tilemap à canvas roulant pour grandes scènes** (`tn.class.tilemap`).
    *Pourquoi* : si une arène/biome de The Pit dépasse l'écran, garder un coût de
    rendu constant.
    *Comment* : canvas de la taille de l'écran, décalage du contenu existant au
    scroll, redessin de la seule nouvelle rangée/colonne révélée ; un seul draw
    call par couche.

---

### Annexe — où regarder dans le code source

| Sujet | Fichier(s) |
|---|---|
| Bootstrap / hooks LÖVE | `main.lua`, `tngine/tn_core.lua` |
| Boucle update/tick/tock | `tngine/tn_core.lua` (`love.update`, `main._tick/_tock`) |
| Objet / culling / caméra | `tngine/classes/tn_object.lua`, `tn_view.lua` |
| Surfaces / canvas | `tngine/classes/tn_surface.lua`, `game/events/ev_load.lua` |
| Pipeline de rendu | `game/events/ev_draw.lua` |
| Tilemap / Tiled | `tngine/classes/tn_tilemap.lua`, `game/modules/md_world.lua` (`loadMap`), `game/resources/maps/` |
| Shaders (déclaration) | `game/modules/md_globals.lua` (lignes ~744-753) |
| Shaders (code) | `game/shaders/*.frag` |
| Jour/nuit/météo | `game/modules/md_world.lua` (`setLightLevel`, `newDay`), `game/events/ev_step.lua`, `ev_tock.lua` |
| Lumières/lightmap | `game/events/ev_draw.lua` (`surf_lighting`), `md_globals.lua` (`light`) |
| UI base | `tngine/classes/tn_ui.lua`, `tn_menu.lua`, `game/modules/md_ui.lua` |
| Bouton | `game/ui/ui_button.lua` |
| Helpers de dessin | `tngine/modules/tn_draw.lua` |
| Utilitaires | `tngine/modules/tn_util.lua` |
| Audio | `game/classes/cl_audio.lua` |
| Particules | `tngine/classes/tn_particlesystem.lua`, `tn_particle.lua` |
| Tweening | `tngine/classes/tn_animcurve.lua` |
| Joueur (draw + palette) | `game/classes/cl_player.lua` (~ligne 871) |
| Livre / codex | `game/classes/cl_book.lua` |
