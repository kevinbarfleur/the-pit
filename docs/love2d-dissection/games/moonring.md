# Dissection technique : Moonring (LÖVE / Lua)

> Document de reference destine a reproduire les techniques visuelles et de
> game-feel de **Moonring** (Fluttermind / Dene Carter) dans un autre projet
> LÖVE, **sans avoir acces au code source**. Tous les extraits sont recopies
> verbatim depuis la version extraite (build `0.0.956`), avec leur chemin
> relatif. La prose est en francais ; le code, les identifiants, les chemins et
> le GLSL restent en version originale.
>
> Convention de lecture : quand un fichier est cite, le chemin est relatif a la
> racine du `.love` decompresse (le dossier qui contient `main.lua`).

---

## Sommaire

1. [Fiche technique](#1-fiche-technique)
2. [Architecture](#2-architecture)
3. [Pipeline de rendu et post-processing](#3-pipeline-de-rendu-et-post-processing)
4. [Shaders](#4-shaders)
5. [Systeme de particules](#5-systeme-de-particules)
6. [Animation et game-feel](#6-animation-et-game-feel)
7. [UI / UX](#7-ui--ux)
8. [Audio (feedback)](#8-audio-feedback)
9. [Ce qu'on vole pour The Pit](#9-ce-quon-vole-pour-the-pit)

---

## 1. Fiche technique

| Element | Valeur |
|---|---|
| Moteur | LÖVE (le code teste `love.getVersion()` au runtime ; il vise LÖVE 11.x — usage de `love.graphics.newCanvas`, `Texel`, `love.graphics.captureScreenshot`, `setBlendMode("add","alphamultiply")`). |
| Langage | Lua 5.1 / LuaJIT (le code fait `jit.os`, `jit.arch`, `jit.off()`). |
| Resolution interne | **1280 x 721** px (mode "BigScreen"). Variable `G_Globals.pixelWidth = 1280`, `G_Globals.pixelHeight = floor(720 + 0 + 1) = 721`. Tout est dessine dans un canvas a cette taille puis upscale a la fenetre. |
| Taille de tuile | `tileSize = 24 * spriteScale`, avec `spriteScale = 2` => **48 px** par tuile a l'ecran. La grille jouable fait `noUITilesWide = 28` tuiles de large, `tilesHigh = 18`. |
| Filtrage | Sprites/fonts en `nearest` (pixel-perfect). **Exception notable** : le canvas final `G_ScreenCanvas` est en `linear` (voir section 3) pour adoucir l'upscale non-entier sous le CRT. |
| Palette | 3 couleurs dynamiques (`G_PrimaryColour`, `G_SecondaryColour`, `G_TertiaryColour`) + une table fixe de ~20 couleurs nommees + 34 "strobes" (cycles de couleurs animes). Le look "palette limitee BBC Micro" vient d'un shader de recolorisation, pas des assets. |
| Polices | Fontes bitmap (`newImageFont`) en `nearest` + une TTF "Fantasy One" pour les titres. |
| Audio | Musique **tracker** (`.xm` / `.it`) streamee, SFX `.wav` echantillonnes + **SFXR procedural** (synthese a la volee, mise en cache). |

### Bibliotheques tierces embarquees (`library/`)

| Fichier | Role |
|---|---|
| `library/middleclass.lua` | POO (toutes les classes `CParticle`, `CParticleEffect`... en derivent). |
| `library/gamestate.lua` | Pile d'etats (hump.gamestate de Matthias Richter). |
| `library/easing.lua` | (Reecrit maison sous le prefixe `G_*`, voir section 6.) |
| `library/vector.lua` | `CVector` (clone, rotate, addVec, magnitudeSquared...). |
| `library/lume.lua` | Utilitaires (notamment `lume.vector(angle, dist)`). |
| `library/sfxr.lua` | Synthese sonore type sfxr/Bfxr (51 KB). |
| `library/tesound.lua` | Gestionnaire de sources audio (TEsound). |
| `library/music_handler.lua` | Fade/crossfade de la musique tracker. |
| `library/push.lua` | Resolution/letterbox (present mais **non utilise** dans le pipeline principal — Moonring fait son propre scaling, voir 3). |
| `library/tools.lua` | 70 KB d'utilitaires (HSL, dashLine, deepcopy, cloneRGBA, splitString, spiral table...). |
| `library/perlin.lua`, `simplex_noise.lua`, `multifractal.lua` (à la racine) | Bruit. |
| `library/jumper.lua`, `library/core/grid.lua`, `library/core/bheap.lua` | Pathfinding A*. |
| `library/bitser.lua`, `ser.lua`, `serpent.lua` | Serialisation des saves. |

### Arbre des dossiers (commente)

```
moonring/
  main.lua                 # Point d'entree : conf, load, update, draw, run, post-process, audio
  globals.lua              # G_Globals : resolutions, tailles de tuiles, indices de batch, layout UI
  shaders/                 # 13 fragment shaders .fs (voir section 4)
  library/                 # Libs tierces + core/ (pathfinding)
  assets/
    tile_atlas.png         # Atlas principal des tuiles (342 KB)
    aap-64-1x.png          # Palette 64 couleurs (utilisee pour teinter les monstres)
    noise128.png           # Masque de bruit 128px (effet "rayons X" des sprites)
    light_circle.png       # Sprite de halo de lumiere
    beeb*.png, moonring_font*.png  # Fontes bitmap
    sprites/               # ~91 sprites UI (curseur, glyphes manette, icones...)
    sound/                 # 75 .wav + 105 .lua (descripteurs SFXR) 
    chunks/, ruins/, linkTextures/
  music/                   # 43 .xm + 18 .it (modules tracker)
  data/                    # CSV de design, strings, geometric_effects, save/
  generated/sfxr/          # Sons SFXR pre-generes
  # Couche simulation/regles
  state_game.lua           # 970 KB : l'etat de jeu principal (update/draw/logique)
  state_game_gui.lua       # 163 KB : tout le chrome UI du jeu
  state_game_dungeon_chunks.lua, state_game_zoom.lua, state_game_triggers.lua
  state_editor.lua         # Editeur de cartes
  state_title_screen.lua   # Ecran-titre
  actor.lua, actor_manager.lua, actor_brains.lua, actor_boss.lua, actions.lua
  map.lua, dungeon_*.lua, cell_data.lua, world_data.lua
  # Rendu / effets
  tile_screen_manager.lua  # Le coeur du rendu monde : tuiles -> SpriteBatches -> canvas
  particle.lua, particle_effect.lua, particle_manager.lua, particle_data.lua
  pretty_text.lua          # Texte riche avec tags couleur + shader de recolorisation
  rising_text.lua, circles.lua, weather.lua, fireworks.lua
  # UI
  inventory_panel.lua, character_panel.lua, buy_panel.lua, sell_panel.lua,
  skill_tree.lua, note_panel.lua, speech_area.lua, multi_choice_box.lua,
  confirm_box.lua, number_box.lua, alert_box.lua, mouse_handler.lua
```

---

## 2. Architecture

### 2.1 Point d'entree et boucle

Il n'y a **pas de `conf.lua`** separe : la config est minimale et inline dans
`main.lua`.

`main.lua` (lignes 304-306) :

```lua
function love.conf(t)
  t.console = true
end
```

La fenetre n'est donc PAS configuree via `conf.lua` mais imperativement dans
`love.load` (voir section 3.1). C'est un choix deliberé : Moonring veut lire la
taille du bureau d'abord, puis se dimensionner.

Moonring **surcharge `love.run`** (copie quasi conforme de l'exemple du wiki
LÖVE) pour y intercaler l'instrumentation de profilage et la gestion manuelle du
GC sur Switch. Structure de la boucle, `main.lua` 2145-2218 :

```lua
function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end
  local dt = 0
  prof.startTick()
  return function()
    prof.instrumentSectionStart("love.run")
    if G_EnableGCManagement then collectgarbage("stop") end
    if love.event then
      love.event.pump()
      for name, a,b,c,d,e,f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a,b,c,d,e,f)
      end
    end
    if love.timer then dt = love.timer.step() end
    if love.update then love.update(dt) end
    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      prof.endTick(); prof.draw(); prof.startTick()
      love.graphics.present()
    end
    if G_EnableGCManagement then
      local gc_mem = collectgarbage("count") / 1024
      if gc_mem > 300 then collectgarbage("collect") else collectgarbage("step", 20) end
    end
    if love.timer then love.timer.sleep(0.001) end
  end
end
```

Points a retenir :
- `love.timer.sleep(0.001)` en fin de frame : limiteur de CPU minimal.
- Le GC est pilote a la main (collecte complete si > 300 MB, sinon pas
  incrementaux de 20). Active seulement sur Switch (`G_EnableGCManagement`).
- `love.update(dt)` appelle `gameUpdate(dt)` qui fait tourner un **fixed update**
  a `FIXED_UPDATE_TIME = 1 / 40` (40 Hz) pour la souris et la logique :

`main.lua` 243 :

```lua
FIXED_UPDATE_TIME = 1 / 40
```

`main.lua` 1376-1423 (`gameUpdate`) :

```lua
local acc = 0
local function gameUpdate(dt)
  acc = acc + dt
  if acc >= FIXED_UPDATE_TIME then
    acc = acc - FIXED_UPDATE_TIME
    G_MouseHandler.fixedUpdate()
  end
  -- ... sons retardes, fade ...
  GameState.update(dt)
  G_MusicHandler.update(dt)
  if not G_Console.isOn then
    G_Frame = G_Frame + 1
    if not G_NoStrobe then G_StrobeFrame = G_StrobeFrame + 1 end
  end
  G_updateScreenShake(FIXED_UPDATE_TIME)
  G_updateChromaticAberration(FIXED_UPDATE_TIME)
  -- ...
  TEsound.cleanup()
end
```

`G_Frame` est le compteur de frames global ; il sert d'horloge a presque toutes
les animations (strobes, shaders, particules, lignes pointillees).

### 2.2 Machine a etats

Pile d'etats via `library/gamestate.lua` (hump). Au demarrage, `love.load`
bascule sur l'ecran-titre (`main.lua` 1203) :

```lua
GameState.switch(G_stateTitleScreen)
```

Les trois etats reels sont :
- `G_stateTitleScreen` (`state_title_screen.lua`) — menu, animation de palette.
- `G_stateGame` (`state_game.lua`) — le jeu. C'est un mega-objet (970 KB) qui
  delegue le rendu monde a `tile_screen_manager.lua`, le chrome a
  `state_game_gui.lua`, les chunks a `state_game_dungeon_chunks.lua`, et la vue
  "zoom" locale a `state_game_zoom.lua`.
- `G_stateEditor` (`state_editor.lua`) — editeur de niveaux.

`gamestate.lua` expose `switch`, `push`, `pop`, `current`. Les callbacks
(`update`, `draw`, `keypressed`...) sont forwardes a `stack[#stack]` via un
`__index` metatable. Moonring n'utilise PAS `GS.registerEvents` (qui patcherait
les `love.*`) : il appelle explicitement `GameState.update(dt)`,
`GameState:draw()`, `GameState.keypressed(...)` depuis ses propres callbacks,
pour controler l'ordre exact (canvas, post-process) autour.

### 2.3 Diagramme texte du flux d'une frame

```
love.run loop
  |
  |-- love.update(dt) -> gameUpdate(dt)
  |     |-- fixed update souris @40Hz
  |     |-- GameState.update(dt)        (logique de l'etat courant)
  |     |-- G_MusicHandler.update(dt)   (fade musique)
  |     |-- G_Frame++ / G_StrobeFrame++
  |     |-- G_updateScreenShake()        (decale screenShakeX/Y)
  |     |-- G_updateChromaticAberration()
  |
  |-- love.draw() -> gameDraw()
        |-- setCanvas(G_ScreenCanvas)              <= tout le jeu va dans CE canvas
        |     |-- GameState:draw()
        |     |     |-- drawWorldDisplay -> tileScreenManager:draw()
        |     |     |       |-- setCanvas(gTileMapCanvas)
        |     |     |       |-- remplit 3 SpriteBatch (default/additive/xray)
        |     |     |       |-- setShader(recolour) -> draw default+additive batch
        |     |     |       |-- setShader(monochrome_with_noise) -> draw xray batch
        |     |     |       |-- setCanvas(G_ScreenCanvas) ; draw(gTileMapCanvas)
        |     |     |-- dotted lines (shader dotted_line)
        |     |     |-- HUD, barres de vie, GUI panels (shader recolour par bloc)
        |     |-- G_drawScreenTransitionEffect()    (transition losanges)
        |     |-- G_drawLoadingText()
        |-- setCanvas()                             <= retour a l'ecran reel
        |-- si CRT actif: setShader(crt_emulation) ; send iTime
        |-- draw(G_ScreenCanvas, offsetX+shakeX, offsetY+shakeY, 0, scale, scale)
        |-- setShader() ; console ; debug overlays
```

L'idee architecturale-clef : **toute la scene (monde + UI) est composee dans un
seul canvas a resolution interne fixe (1280x721)**, puis ce canvas unique est
projete a l'ecran avec le shader CRT et le decalage de screen-shake. Le scaling
ecran ne touche jamais la logique ni le layout.

---

## 3. Pipeline de rendu et post-processing

C'est le point fort de Moonring. La chaine est volontairement simple mais tres
efficace. Resume : **3 niveaux de canvas**.

```
[SpriteBatches tuiles] --recolour--> gTileMapCanvas --> G_ScreenCanvas --CRT--> ecran
[UI / HUD / texte]      --recolour (par bloc)------------^
```

### 3.1 Initialisation de la fenetre et du canvas (`main.lua` 967-1085)

```lua
love.window.setMode(0, 0, {fullscreentype = "desktop"}) -- FAKE set the window to a full-screen window

local arx = love.graphics.getWidth()
local ary = love.graphics.getHeight()
arx = love.graphics.getWidth() / G_Globals.screenWidth
ary = love.graphics.getHeight() / G_Globals.screenHeight
local s = math.min(arx, ary)
s = math.floor(s * 6) / 6
G_Globals.screenWidth  = math.floor(G_Globals.pixelWidth)
G_Globals.screenHeight = math.floor(G_Globals.pixelHeight)
love.window.setMode(G_Globals.screenWidth, G_Globals.screenHeight,
  {fullscreentype = "desktop", resizable=true, vsync=true,
   minwidth=G_Globals.pixelWidth/2, minheight=G_Globals.pixelHeight/2})
love.window.setTitle("Moonring")

G_VirtualKeyboard.setResolution(G_Globals.screenWidth, G_Globals.screenHeight)

G_ScreenCanvas = love.graphics.newCanvas(G_Globals.pixelWidth, G_Globals.pixelHeight)
-- ... chargement des images en nearest ...
-- G_ScreenCanvas:setFilter("nearest", "nearest")
G_ScreenCanvas:setFilter("linear", "linear")
```

Note importante (commentaire dans le code) : le filtre `nearest` du canvas final
est **commente** au profit de `linear`. Sous CRT, l'upscale non-entier passe en
bilineaire pour eviter le scintillement de pixels ; c'est compense par le shader
CRT qui ajoute son propre grain.

Le shader CRT est cree une seule fois (`main.lua` 1073) ; les autres post-process
(spellrazor, bloom, chromatic) sont **charges en commentaire** => ils ne sont
PAS dans le pipeline final :

```lua
G_ShaderCRTEmulation         = love.graphics.newShader("shaders/crt_emulation.fs")
--  G_ShaderSpellrazor           = love.graphics.newShader("shaders/spellrazor.fs")
--  G_ShaderBloom                = love.graphics.newShader("shaders/bloom.fs")
--  G_ShaderChromaticAbberation  = love.graphics.newShader("shaders/chromatic_abberation.fs")
```

### 3.2 Calcul du scaling (letterbox maison) (`main.lua` 1331-1349)

Moonring n'utilise pas `push.lua`. Il calcule lui-meme un facteur d'echelle
uniforme et des offsets de centrage (barres noires) :

```lua
function love.resize(w,h)
  G_calculateScreenResizeValues(w,h)
end

function G_calculateScreenResizeValues(sx, sy)
  local aspect_game   = G_Globals.pixelWidth / G_Globals.pixelHeight
  local aspect_screen = G_Globals.screenWidth / G_Globals.screenHeight

  local sw = sx / G_Globals.pixelWidth
  local sh = sy / G_Globals.pixelHeight

  if sw < sh then gDrawScale = sw else gDrawScale = sh end

  local h_space = sx - (G_Globals.pixelWidth   * gDrawScale)
  local v_space = sy - (G_Globals.pixelHeight  * gDrawScale)
  G_DrawOffsetHorizontal = h_space / 2
  G_DrawOffsetVertical   = v_space / 2
end
```

`gDrawScale` = min(largeur, hauteur) pour garder l'aspect ; `G_DrawOffset*` =
moitie de l'espace restant => centrage. Ces valeurs sont reinjectees dans le
`MouseHandler` pour convertir coordonnees ecran <-> coordonnees virtuelles.

### 3.3 La passe de composition (`main.lua` 1587-1668, `gameDraw`)

```lua
local function gameDraw()
  if _steam ~= nil then _steam.runCallbacks() end

  G_MouseHandler.setXYAndScale(G_DrawOffsetHorizontal + G_Globals.screenShakeX,
                               G_DrawOffsetVertical + G_Globals.screenShakeY, gDrawScale)

  love.graphics.setLineWidth(2)

  if G_ScreenCanvas then
    love.graphics.setCanvas(G_ScreenCanvas)     -- (1) tout va dans le canvas interne
  end

  GameState:draw()                              -- (2) monde + UI

  G_drawScreenTransitionEffect()                -- (3) transition losanges
  G_drawLoadingText()
  love.graphics.setCanvas()                      -- (4) retour ecran

  -- cas special: ecran-titre sans CRT => blit direct, pas de shader
  if not G_Options.crtEmulation and GameState:getName() == "TitleScreen" then
    love.graphics.setShader()
    if G_ScreenCanvas then
      love.graphics.draw(G_ScreenCanvas, G_DrawOffsetHorizontal + G_Globals.screenShakeX,
                         G_DrawOffsetVertical + G_Globals.screenShakeY, 0, gDrawScale, gDrawScale)
    end
    return
  end

  local ca = G_Globals.defaultChromaticAbberation
  if not G_Options.crtEmulation then ca = 0; end
  if G_Globals.totalChromaticAberrationTime > 0 then
    ca = ca + (0.0002 * G_Globals.currentChromaticAberrationAmount)
  end

  if G_Options.crtEmulation then
    G_ShaderCRTEmulation:send("iTime", G_Frame)   -- (5) horloge du grain CRT
    love.graphics.setShader(G_ShaderCRTEmulation)
  end

  if G_ScreenCanvas then
    love.graphics.draw(G_ScreenCanvas, G_DrawOffsetHorizontal + G_Globals.screenShakeX,
                       G_DrawOffsetVertical + G_Globals.screenShakeY, 0, gDrawScale, gDrawScale)  -- (6) blit final scale + shake
  end
  love.graphics.setShader()

  if G_SFXREditOn == true then sfxrEdit.draw(0,0) end
  G_Console.draw()
  -- overlays debug ...
end
```

A retenir :
- Le **screen-shake** est applique au moment du blit final (offset de la
  position de dessin du canvas), donc il secoue toute l'image d'un bloc, sans
  jamais retoucher la logique ni les coordonnees du monde. Le CRT masque les
  bords decales par son masque/feather (voir 4.3).
- La **variable `ca` (chromatic aberration)** est calculee mais le shader
  associe etant commente, elle est vestigiale dans ce build. L'aberration
  chromatique reste neanmoins disponible en tant qu'effet (cf. `chromatic_abberation.fs`).
- L'ecran-titre a un chemin court (pas de CRT si l'option est off).

### 3.4 Le canvas intermediaire des tuiles (`tile_screen_manager.lua`)

Le rendu monde a son propre canvas `gTileMapCanvas`. `CTSM:draw` (567-731,
extraits clefs) :

```lua
function CTSM:draw(x, y)
  local old_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(gTileMapCanvas)
  love.graphics.clear(0,0,0, 1)
  love.graphics.setColor(1,1,1,1)
  self.tileBatch:clear()
  self.tileBatchAdditive:clear()
  self.tileBatchXRay:clear()

  local batches = {}
  batches[G_Globals.DEFAULT_BATCH]   = self.tileBatch
  batches[G_Globals.ADDITIVE_BATCH]  = self.tileBatchAdditive
  batches[G_Globals.XRAY_BATCH]      = self.tileBatchXRay

  -- _drawBucketOrder = liste triee des "buckets" (tranches Y pour le tri en profondeur)
  table.sort(_drawBucketOrder)
  -- ... pour chaque bucket, pour chaque commande, batch:add(...) avec la bonne couleur ...

  -- PASSE 1 : tuiles opaques + additives, recolorisees
  local old_shader = love.graphics.getShader()
  love.graphics.setShader(gShaderRecolour)
  gShaderRecolour:send("darkCol", G_SecondaryColour)
  gShaderRecolour:send("lightCol", G_PrimaryColour)
  gShaderRecolour:send("darkestCol", G_TertiaryColour)

  love.graphics.setColor(1,1,1,1)
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(batches[G_Globals.DEFAULT_BATCH], center_x, center_y, rot, scale, scale, -scroll_x + center_x, -scroll_y + center_y)

  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.draw(batches[G_Globals.ADDITIVE_BATCH], center_x, center_y, rot, scale, scale, -scroll_x + center_x, -scroll_y + center_y)

  -- PASSE 2 : sprites "rayons X" (creatures vues a travers les murs), shader bruit monochrome
  love.graphics.setColor(1,1,1, 0.5 + love.math.random() * 0.5)
  love.graphics.setShader(gShaderMonochromeWithNoise)
  gShaderMonochromeWithNoise:send("noiseXOffset", love.math.random())
  gShaderMonochromeWithNoise:send("noiseYOffset", love.math.random())
  love.graphics.setBlendMode("alpha")
  gShaderMonochromeWithNoise:send("mask", self.noiseImageData)
  love.graphics.draw(batches[G_Globals.XRAY_BATCH], center_x, center_y, rot, scale, scale, -scroll_x + center_x, -scroll_y + center_y)

  love.graphics.setColor(1,1,1,1)
  love.graphics.setBlendMode("alpha")
  love.graphics.setShader(old_shader)

  -- liens, effets geometriques (mode additif), bbox du monde (dashLine)...

  -- Resolution : on revient au canvas appelant (G_ScreenCanvas) et on blit
  love.graphics.setBlendMode("alpha", "alphamultiply")
  local alpha = 1
  if self.isZoomingIn or self.isZoomingOut then alpha = self.zoomFraction end
  love.graphics.setColor(1,1,1, alpha)
  love.graphics.setCanvas(old_canvas)
  love.graphics.draw(gTileMapCanvas, x, y)

  -- Pendant un zoom, on superpose une copie agrandie/retrecie (gBackupCanvas) en crossfade
  if self.isZoomingIn or self.isZoomingOut then
    -- ... draw(gBackupCanvas, ..., rot, scale, scale, center_x, center_y) avec alpha = 1-zoomFraction
  end
  love.graphics.setColor(1,1,1,1)
end
```

Caracteristiques importantes :
- **Tri en profondeur par "buckets"** : chaque sprite est range dans un bucket
  indexe par sa coordonnee Y (`bucket_index = floor(bucket_y + BUCKET_KLUDGE) + 1`),
  puis les buckets sont tries par `table.sort`. C'est un tri par tranches Y
  (depth sorting) bon marche, sans tri global des sprites.
- **Pool de commandes de dessin** reutilise frame a frame pour eviter le GC
  (voir 3.5).
- **3 SpriteBatch** (un par mode de blend) : opaque (`alpha`), additif
  (`add, alphamultiply`), et rayons-X (alpha + shader de bruit).
- Le scroll fractionnaire et la rotation/scale du zoom sont appliques au
  `draw` du batch via les parametres `(rot, scale, scale, ox, oy)`.

### 3.5 Pool de commandes (anti-GC) (`tile_screen_manager.lua` 60-119)

```lua
local _drawBuckets = {}
local _drawBucketOrder = {}
local _bucketSizes = {}

local _drawCommandPool = {}
local _nextDrawCommandIndex = 1
local _initialDrawCommandPoolSize = 5000

local function addDrawCommandToBucket(bucket_index, quad, x, y, rotation, scale_x, scale_y, offset_x, offset_y, col_index, batch_type, scale)
  local bucket = _drawBuckets[bucket_index]
  if bucket == nil then
    bucket = {}
    _drawBuckets[bucket_index] = bucket
    _bucketSizes[bucket_index] = 0
    table.insert(_drawBucketOrder, bucket_index)
  end
  local size = _bucketSizes[bucket_index] + 1
  _bucketSizes[bucket_index] = size
  local cmd
  if _nextDrawCommandIndex <= #_drawCommandPool then
    cmd = _drawCommandPool[_nextDrawCommandIndex]
    _nextDrawCommandIndex = _nextDrawCommandIndex + 1
  else
    cmd = {}
    _drawCommandPool[_nextDrawCommandIndex] = cmd
    _nextDrawCommandIndex = _nextDrawCommandIndex + 1
  end
  cmd[1] = quad; cmd[2] = x; cmd[3] = y; cmd[4] = rotation
  cmd[5] = scale_x; cmd[6] = scale_y; cmd[7] = offset_x; cmd[8] = offset_y
  cmd[9] = col_index; cmd[10] = batch_type; cmd[11] = scale
  bucket[size] = cmd
  return cmd
end

local function resetDrawCommands()
  for k, _ in pairs(_bucketSizes) do _bucketSizes[k] = 0 end
  _nextDrawCommandIndex = 1
end
```

L'astuce : les tables `cmd` ne sont JAMAIS liberees ; on reset juste les
compteurs de taille a chaque frame. Zero allocation par sprite => zero pression
GC sur le rendu monde. Le point d'entree public est `CTSM:addToSpriteBatch`
(774-783) qui calcule le quad et le bucket Y :

```lua
function CTSM:addToSpriteBatch(index, col, px, py, ang, flip_x, flip_y, offset_x, offset_y, bucket_y, batch_number, scale)
  local quad    = self:getQuadFromIndex(index)
  local ox, oy  = self:getOriginXYFromIndex(index)
  ang = math.rad(ang)
  local bucket_index = math.floor(bucket_y + BUCKET_KLUDGE) + 1
  if bucket_index < 1 or bucket_index > MAX_BUCKETS then return end
  addDrawCommandToBucket(bucket_index, quad, px+G_Globals.halfTileSize, py+G_Globals.halfTileSize, ang, flip_x, flip_y, offset_x + ox, offset_y + oy, col, batch_number or G_Globals.DEFAULT_BATCH, scale or 1)
end
```

---

## 4. Shaders

Les shaders sont des **fragment shaders LÖVE** (`.fs`), c'est-a-dire qu'ils
definissent une fonction `effect(color, texture, texture_coords, screen_coords)`.
Tous sont dans `shaders/`. On les classe en 3 familles :

- **Post-process plein ecran** : `crt_emulation.fs` (le seul actif), plus
  `bloom.fs`, `old_bloom.fs`, `spellrazor.fs`, `chromatic_abberation.fs`
  (presents mais commentes).
- **Recolorisation / palette** : `recolour.fs`, `recolour_title_screen.fs`,
  `text_recolour.fs`, `monochrome_with_noise.fs`.
- **Utilitaires** : `dotted_line.fs`, `is_remembered.fs`,
  `draw_editor_map.fs`, `draw_editor_map_with_memory.fs`.

### 4.1 `shaders/recolour.fs` — le coeur de la palette (CRUCIAL)

C'est LA technique qui donne a Moonring son look "3 couleurs". Les assets ne sont
PAS colorises : ils encodent un **index de palette dans les canaux de couleur**.
Le shader remappe chaque pixel vers l'une des 3 couleurs dynamiques.

GLSL integral :

```glsl
extern vec4 darkCol;
extern vec4 lightCol;
extern vec4 darkestCol;

vec4 effect( vec4 color, Image texture, vec2 uv, vec2 screen_coords )
{
  vec4 pixel = Texel(texture, uv);
  float a = pixel.a;
  if (pixel.g == 0.0)
    return vec4(0.0,0.0,0.0,a);
  else if(pixel.g == 1.0)
    return vec4(1.0,1.0,1.0,a) * color;
  else if(pixel.r > 0.6)
    pixel = lightCol;
  else if (pixel.g > 0.3)
    pixel = darkCol;
  else
    pixel = darkestCol;
  pixel.a = a;
  return pixel * color;
}
```

Convention d'encodage des assets (deduite du shader) :
- `g == 0.0` exactement => pixel **noir** force (ombre/contour).
- `g == 1.0` exactement => pixel **blanc** pur (multiplie par `color`, donc peut
  etre teinte par la couleur de dessin courante — utile pour les highlights).
- sinon, on choisit parmi 3 teintes selon des seuils :
  - `r > 0.6` => `lightCol` (= `G_PrimaryColour`)
  - sinon `g > 0.3` => `darkCol` (= `G_SecondaryColour`)
  - sinon => `darkestCol` (= `G_TertiaryColour`)

Code Lua d'application (3 sites identiques). `tile_screen_manager.lua` 636-639 :

```lua
love.graphics.setShader(gShaderRecolour)
gShaderRecolour:send("darkCol", G_SecondaryColour)
gShaderRecolour:send("lightCol", G_PrimaryColour)
gShaderRecolour:send("darkestCol", G_TertiaryColour)
```

(idem dans `state_game_gui.lua` autour des lignes 2301, 2401, 2524, 2741 — chaque
panneau UI qui dessine des sprites de tuiles le fait par bloc.)

**Comment reproduire.** Dessiner ses sprites en "index map" : canal vert =
selecteur de zone (0 = noir, 1 = blanc, intermediaire = teinte), canal rouge =
distinction clair/fonce. Au runtime, on envoie 3 couleurs `vec4` au shader et on
dessine normalement. On obtient un reskin instantane de tout l'art en changeant
3 uniforms — parfait pour des ambiances par biome, des flashs de degats, ou un
cycle de palette anime (voir l'ecran-titre, 4.2).

### 4.2 `shaders/recolour_title_screen.fs`

Variante pour l'ecran-titre, ou l'encodage utilise des canaux **purs** (R, G, B
separes) plutot que des seuils :

```glsl
extern vec4 darkCol;
extern vec4 lightCol;
extern vec4 darkestCol;

vec4 effect( vec4 color, Image texture, vec2 uv, vec2 screen_coords )
{
  vec4 pixel = Texel(texture, uv);
  float a = pixel.a;
  if (pixel.r > 0.5 && pixel.g > 0.5)  
    return vec4(1.0, 1.0, 1.0 ,a) * color;
  else if (pixel.r > 0.0)
    pixel = lightCol;
  else if(pixel.g > 0.0)
    pixel = darkCol;
  else if (pixel.b > 0.0)
    pixel = darkestCol;
  else
    return vec4(0.0, 0.0, 0.0, a);
  pixel.a = a;
  return pixel * color;
}
```

Encodage : rouge=light, vert=dark, bleu=darkest, jaune (r&g)=blanc, noir=noir.

Application avec **cycle de palette anime** (`state_title_screen.lua` 282-304) :

```lua
self.time = self.time + dt
local gt = self.time / 60
gt = gt + 0.8
gt = gt % 1
local r,g,b = tools.HSL(gt, 0.6, 0.5)
G_PrimaryColour = {r,g,b, 1}
gt = (gt + 0.3) % 1
r,g,b = tools.HSL(gt, 0.5, 0.5)
G_SecondaryColour = {r,g,b, 1}
gt = (gt + 0.6) % 1
r,g,b = tools.HSL(gt, 0.5, 0.4)
G_TertiaryColour = {r, g, b, 1}

love.graphics.setShader(G_ShaderRecolourTitleScreen)
G_ShaderRecolourTitleScreen:send("lightCol",    G_PrimaryColour)
G_ShaderRecolourTitleScreen:send("darkCol",     G_SecondaryColour)
G_ShaderRecolourTitleScreen:send("darkestCol",  G_TertiaryColour)
```

Le titre derive lentement dans l'espace teinte (3 teintes decalees de 0.3 et 0.6
sur la roue, saturations/luminosites figees) => arc-en-ciel sombre et organique.

### 4.3 `shaders/crt_emulation.fs` — le post-process actif (CRUCIAL)

Combine **barrel distortion**, **masque feather** (bords arrondis), **scanlines
de bloom** (lignes alternees plus/moins lumineuses) et **grain de bruit** anime.

```glsl
vec2 distortionFactor = vec2 (1.0, 1.0);//vec2 (1.002, 1.003);// 
float scaleFactor = 1.0;//1.001; //1;
float feather = 0.005;// 0;
float scroll = 0.0;
extern number iTime;

float random(vec2 uv)
{
 	return fract(sin(dot(uv, vec2(15.5151, 42.2561))) * 12341.14122 * sin(iTime * 0.03));   
}

float noise(vec2 uv)
{
 	vec2 i = floor(uv);
  vec2 f = fract(uv);
  
  float a = random(i);
  float b = random(i + vec2(1.,0.));
	float c = random(i + vec2(0., 1.));
  float d = random(i + vec2(1.));
  
  vec2 u = smoothstep(0., 1., f);
  
  return mix(a,b, u.x) + (c - a) * u.y * (1. - u.x) + (d - b) * u.x * u.y;                      
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) 
{
  // to barrel coordinates
  number bloom = mod(scroll + px.y, 3.0);

  if (bloom > 1.0) 
    bloom = 1.2;
  else 
    bloom = 0.9;

  uv = uv * 2.0 - vec2(1.0);
  // distort
  uv *= scaleFactor;
  uv += (uv.yx*uv.yx) * uv * (distortionFactor - 1.0);
  number mask = (1.0 - smoothstep(1.0-feather,1.0,abs(uv.x)))
              * (1.0 - smoothstep(1.0-feather,1.0,abs(uv.y)));
  // to cartesian coordinates
  uv = (uv + vec2(1.0)) / 2.0;

  vec4 noise = vec4(noise(uv * 75.));
  vec4 col = color * Texel(tex, uv) * mask * bloom;
  return mix(col, noise, 0.01);
}
```

Decomposition :
- **Scanlines de bloom** : `bloom = mod(px.y, 3.0)` cree un motif sur 3 lignes
  ecran ; une ligne sur trois est a `1.2` (plus claire), les autres a `0.9`
  (plus sombres). C'est un effet de balayage CRT bon marche en luminance.
- **Barrel distortion** : conversion en coordonnees [-1,1], puis
  `uv += (uv.yx*uv.yx) * uv * (distortionFactor - 1.0)`. Ici `distortionFactor =
  (1,1)` => distorsion **neutre** dans ce build (la ligne de vraie distorsion est
  commentee : `vec2(1.002, 1.003)`). Le code est pret a courber l'image mais reste
  plat par defaut.
- **Masque feather** : double `smoothstep` sur `abs(uv.x)` et `abs(uv.y)` =>
  assombrit doucement les bords (vignette/arrondi de tube). C'est ce qui cache
  les bords decales par le screen-shake.
- **Grain** : un `noise(uv*75.)` value-noise dont la graine depend de
  `sin(iTime*0.03)` => grain qui scintille lentement. Melange a 1% :
  `mix(col, noise, 0.01)`.

Application (`main.lua` 1637-1645) :

```lua
if G_Options.crtEmulation then
  G_ShaderCRTEmulation:send("iTime", G_Frame)
  love.graphics.setShader(G_ShaderCRTEmulation)
end
if G_ScreenCanvas then
  love.graphics.draw(G_ScreenCanvas, G_DrawOffsetHorizontal + G_Globals.screenShakeX,
                     G_DrawOffsetVertical + G_Globals.screenShakeY, 0, gDrawScale, gDrawScale)
end
love.graphics.setShader()
```

`iTime` recoit `G_Frame` (compteur de frames), pas un temps en secondes — le grain
avance d'un cran par frame logique. Le shader est applique **uniquement au blit
final** du canvas complet, donc une seule passe plein ecran.

**Comment reproduire.** C'est un excellent CRT "minimal viable" : pas de texture
de masque RGB, juste des scanlines de luminance modulo 3, une vignette feather et
un grain anime. Cout : une passe. Pour un look plus prononce, decommenter les
facteurs de distorsion. Le secret du "feel" : combiner ce CRT avec le
screen-shake applique au meme blit, pour que la vignette absorbe les bords.

### 4.4 `shaders/monochrome_with_noise.fs` — effet "rayons X"

Sert a dessiner les creatures visibles **a travers les murs** : elles
apparaissent en niveaux de gris, decoupees par un masque de bruit (effet
pointilliste/spectral).

```glsl
extern Image mask; // Holds a random arrangement of alpha-values
extern float noiseXOffset;
extern float noiseYOffset;

vec4 effect( vec4 color, Image texture, vec2 uv, vec2 screen_coords )
{  
  vec4 pixel = Texel(texture, uv);

  uv[0] *= 100.0 + noiseXOffset;
  uv[1] *= 100.0 + noiseYOffset;
  
  vec4 mask_pixel = Texel(mask, uv);

  float a = pixel.a * mask_pixel.a;
  float c =  pixel.r + pixel.g + pixel.b;

  pixel.r = c;
  pixel.g = c;
  pixel.b = c;
  pixel.a = a * color.a;
  return pixel;
}
```

- Desature en additionnant les canaux (`c = r+g+b`) => gris (volontairement
  "brule", peut depasser 1).
- L'alpha final est multiplie par l'alpha du **masque de bruit** echantillonne a
  haute frequence (`uv*100`), avec des offsets aleatoires par frame
  (`noiseXOffset/YOffset`) => le sprite scintille et se dissout en grain.

Application (`tile_screen_manager.lua` 648-655) :

```lua
love.graphics.setColor(1,1,1, 0.5 + love.math.random() * 0.5)
love.graphics.setShader(gShaderMonochromeWithNoise)
gShaderMonochromeWithNoise:send("noiseXOffset", love.math.random())
gShaderMonochromeWithNoise:send("noiseYOffset", love.math.random())
love.graphics.setBlendMode("alpha")
gShaderMonochromeWithNoise:send("mask", self.noiseImageData)
love.graphics.draw(batches[G_Globals.XRAY_BATCH], ...)
```

Le masque est `assets/noise128.png`, charge en `nearest` + wrap `repeat`
(`tile_screen_manager.lua` 145-147) :

```lua
self.noiseImageData = love.graphics.newImage("assets/noise128.png")
self.noiseImageData:setFilter("nearest", "nearest")
self.noiseImageData:setWrap( "repeat", "repeat" )
```

### 4.5 `shaders/text_recolour.fs` — texte riche teinte

Recolorise du texte dont les pixels sont TOUS BLANCS ; la decision se base sur le
**canal vert de `color`** (la couleur de vertex/dessin), pas du pixel. C'est ce
qui permet d'encoder une "classe de teinte" par fragment de texte via la couleur
de dessin.

```glsl
extern vec4 darkCol;
extern vec4 lightCol;
extern vec4 darkestCol;
// Recolours text with text tags. The original pixels are ALL WHITE
// so we rely on color.g instead of the usual pixel.g value
vec4 effect( vec4 color, Image texture, vec2 uv, vec2 screen_coords )
{
  vec4 pixel = Texel(texture, uv);
  float a = pixel.a * color.a;
  if (color.g == 0.0)
      return vec4(0,0,0,a);
  else 
  if(color.g == 1.0)
      return vec4(1,1,1,a);
  else 
  if(color.g > 0.6)
      pixel = lightCol;
  else 
  if (color.g > 0.3)
      pixel = darkCol;
  else
      pixel = darkestCol;
       
  pixel.a = a;
  return pixel;
}
```

Application via la classe `CPrettyText` (`pretty_text.lua`). Le texte est
decoupe en fragments par tags `{col1}`, `{white}`, etc., puis dessine via un
`love.graphics.newText` avec ce shader. Extrait `pretty_text.lua` 88-112 :

```lua
function CPrettyText:draw(x, y, alpha, shadow)
  alpha = alpha or 1
  local old_shader = love.graphics.getShader()
  love.graphics.setShader(self.shader)

  local col1 = tools.cloneRGBA(G_PrimaryColour)
  local col2 = tools.cloneRGBA(G_SecondaryColour)
  local col3 = tools.cloneRGBA(G_TertiaryColour)

  love.graphics.setColor(0,0,0,alpha)
  if shadow then
    love.graphics.draw(self.textObject, x, y+2)
    love.graphics.draw(self.textObject, x, y-2)
    love.graphics.draw(self.textObject, x-2, y)
    love.graphics.draw(self.textObject, x+2, y)
  end
  love.graphics.setColor(1,1,1,alpha)

  self.shader:send("darkCol", col2)
  self.shader:send("lightCol", col1)
  self.shader:send("darkestCol", col3)

  love.graphics.draw(self.textObject, x, y)
  love.graphics.setShader(old_shader)
end
```

Le shader est cree une seule fois au niveau module (`pretty_text.lua` 26) :
`local text_shader = love.graphics.newShader("shaders/text_recolour.fs")`. Les
macros couleur sont definies en haut du fichier (`textmacros.col1 =
{99/255,155/255,1,1}` etc.). L'ombre est faite par 4 dessins decales en noir.

### 4.6 `shaders/dotted_line.fs` — lignes pointillees animees

Anime des tirets le long d'une `love.graphics.line` en fonction de la position
ecran et du temps. Sert aux lignes de visee/ciblage et aux bbox de zone.

```glsl
extern number iTime;

vec4 effect( vec4 color, Image texture, vec2 uv, vec2 screen_coords)
{
  vec4 pixel = Texel(texture, uv);
  pixel.r = color.r;
  pixel.g = color.g;
  pixel.b = color.b;

  float a = color.a;

  float z = mod(((screen_coords.x + screen_coords.y) + iTime), 10.0);
  if(z < 5.0) a = 0.0;    
  pixel.a = a;

  return pixel;
}
```

`(x+y+iTime) mod 10` < 5 => trou ; sinon => trait. `iTime` defile => les tirets
"marchent". Application (`state_game.lua` 7127-7140) :

```lua
local old_shader = love.graphics.getShader()
love.graphics.setShader(G_ShaderDottedLine)
local t = G_Frame
if G_Options.photosensitivity then t = math.floor(t / 10) end
G_ShaderDottedLine:send("iTime", t)
for _, v in ipairs(G_AllDashLines) do
  love.graphics.setColor(v.col)
  love.graphics.line(v.x1 + x, v.y1 + y, v.x2 + x, v.y2 + y)
end
G_AllDashLines = {}
love.graphics.setShader(old_shader)
```

(Le mode photosensibilite ralentit le defilement ; pattern recurrent dans tout le
jeu : `G_Options.photosensitivity` divise les horloges visuelles.)

### 4.7 `shaders/is_remembered.fs` — composition alpha par masque

Combine la couleur d'une texture avec l'**alpha d'une seconde** (masque de
"memoire" : zones deja explorees). Utilise par la minimap/brouillard.

```glsl
extern Image mask; // the alpha of this image is ignored

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) 
{
  return vec4(Texel(tex, uv).rgb, Texel(mask, uv).a) * color;
}
```

### 4.8 `shaders/draw_editor_map.fs` et `draw_editor_map_with_memory.fs`

Visualisation de la carte dans l'editeur (`state_editor.lua` 121-122 charge
`is_remembered.fs` et `draw_editor_map.fs` ; `state_game.lua` 429 charge
`draw_editor_map_with_memory.fs`).

`draw_editor_map.fs` — etale fortement une valeur stockee dans le canal rouge
(`c = 1 - col[0]*25`) en niveaux de gris :

```glsl
extern Image mask; // the alpha of this image is ignored

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) 
{
  vec4 col = Texel(tex, uv);
  float c = 1.0 - (col[0] * 25.0);
  col[0] = c;
  col[1] = c;
  col[2] = c;
  col[3] = 1.0;
  return col * color;
}
```

`draw_editor_map_with_memory.fs` — variante qui prend le rouge tel quel et
applique le masque de memoire en alpha (avec un `*2.0` pour "fausser" la
luminosite) :

```glsl
extern Image mask; // the alpha of this image is ignored

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) 
{
  vec4 col = Texel(tex, uv);
  float c = col[0];//1 - (col[0] * 25.0);
  col[0] = c;
  col[1] = c;
  col[2] = c;
  col[3] = 1.0;
  float m = Texel(mask, uv).a;
  return vec4(col.rgb, m) * color * 2.0; // Falsely brighten the damned thing up a bit
}
```

### 4.9 Shaders presents mais NON actifs (post-process alternatifs)

Ces shaders existent dans `shaders/` mais ne sont references qu'en commentaire
dans `main.lua`. Ils sont documentes ici car ils representent des techniques
reutilisables et montrent l'historique du pipeline.

`shaders/bloom.fs` — bloom separable (flou vertical + horizontal a 5 taps) avec
extraction par seuil de luminance :

```glsl
extern number threshold = 1.0;

extern number canvas_w = 512 * 2;
extern number canvas_h = 288 * 2;
         
const number offset_1 = 1.5;
const number offset_2 = 3.5;

const number alpha_0 = 0.13;//0.23;
const number alpha_1 = 0.20; //0.32;
const number alpha_2 = 0.02;//0.07;

float luminance(vec3 color)
{
   // numbers make 'true grey' on most monitors, apparently
   return ((0.212671 * color.r) + (0.715160 * color.g) + (0.072169 * color.b));
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
   vec4 texcolor = Texel(texture, texture_coords);

   // Vertical blur
   vec3 tc_v = texcolor.rgb * alpha_0;
   
   tc_v += Texel(texture, texture_coords + vec2(0.0, offset_1)/canvas_h).rgb * alpha_1;
   tc_v += Texel(texture, texture_coords - vec2(0.0, offset_1)/canvas_h).rgb * alpha_1;
   
   tc_v += Texel(texture, texture_coords + vec2(0.0, offset_2)/canvas_h).rgb * alpha_2;
   tc_v += Texel(texture, texture_coords - vec2(0.0, offset_2)/canvas_h).rgb * alpha_2;
   
   // Horizontal blur
   vec3 tc_h = texcolor.rgb * alpha_0;

   tc_h += Texel(texture, texture_coords + vec2(offset_1, 0.0)/canvas_w).rgb * alpha_1;
   tc_h += Texel(texture, texture_coords - vec2(offset_1, 0.0)/canvas_w).rgb * alpha_1;
   
   tc_h += Texel(texture, texture_coords + vec2(offset_2, 0.0)/canvas_w).rgb * alpha_2;
   tc_h += Texel(texture, texture_coords - vec2(offset_2, 0.0)/canvas_w).rgb * alpha_2;
   
   // Smooth
   vec3 extract = smoothstep(threshold * 0.7, threshold, texcolor.rgb) * texcolor.rgb;
   return vec4(extract + tc_v * 0.8 + tc_h * 0.8, 1.0);
}
```

Note : ce bloom fait extraction + flou H + flou V **dans une seule passe** (pas
de ping-pong de canvas), d'ou un flou volontairement court (5 taps de chaque
cote). `canvas_w/canvas_h` doivent etre envoyes en uniforms pour calibrer le pas.

`shaders/old_bloom.fs` et `shaders/spellrazor.fs` (identiques) — un "bloom" tres
cheap qui n'est en fait qu'un leger flou horizontal renforce sur une scanline sur
deux :

```glsl
vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc)
{  
  vec4 source = Texel(tex, tc);
  
  // Was 1024
  tc.x -= 1.0 / 1024.0;
  vec4 left = Texel(tex, tc) * 0.2;

  // Was 1024

  tc.x += 2.0 / 1024.0;
  vec4 right = Texel(tex, tc) * 0.2;
  float sl = floor(mod(sc.y, 2.0));
  return (source + (left + right)*sl) * colour * (0.8+sl);
}
```

`shaders/chromatic_abberation.fs` — glitch RGB-split plein ecran (decalage des
canaux R/G/B + brillance) :

```glsl
// A basic glitch shader with chromatic abberation, brightening and darkening, applied to the whole screen
extern number colourAdd;
extern number chromaticAbberation;
extern number brightMult;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
  const float x_scaler = 0.3;
  vec4 pixel = vec4(0,0,0,1);

  texture_coords.x += (chromaticAbberation * x_scaler);
  vec4 pixelR = Texel(texture, texture_coords);
  texture_coords.x -= (chromaticAbberation * x_scaler * 2.0);
  texture_coords.y -=  chromaticAbberation;

  vec4 pixelG = Texel(texture, texture_coords);
  texture_coords.y += (chromaticAbberation * 2.0);

  vec4 pixelB = Texel(texture, texture_coords);
 
  float average = (pixelR.r + pixelG.g + pixelB.b) / 3.0;
  pixel.r = (brightMult * average) + (pixelR.r + colourAdd);
  pixel.g = (brightMult * average) + (pixelG.g + colourAdd); 
  pixel.b = (brightMult * average) + (pixelB.b + colourAdd); 

  return pixel * 1.2;
}
```

Bien que le shader ne soit pas branche, la **logique de pilotage** de
l'aberration existe et reste utile comme patron de "decay" temporel
(`main.lua` 1723-1750) :

```lua
function G_startChromaticAberrationTimeAndPower(time, power)
  G_Globals.currentChromaticAberrationTime = time
  G_Globals.totalChromaticAberrationTime = G_Globals.currentChromaticAberrationTime
  G_Globals.chromaticAberrationPower = power or 0.25
end

function G_updateChromaticAberration(dt)
  if G_Globals.currentChromaticAberrationTime > 0 then
    G_Globals.currentChromaticAberrationTime = G_Globals.currentChromaticAberrationTime - (1 * dt)
    if G_Globals.currentChromaticAberrationTime < 0 then G_Globals.currentChromaticAberrationTime = 0 end
    G_Globals.currentChromaticAberrationAmount = G_Globals.chromaticAberrationPower * G_Globals.currentChromaticAberrationTime / G_Globals.totalChromaticAberrationTime
  end
end
```

### 4.10 La palette de couleurs (`colour_list.lua`)

Le shader recolour s'appuie sur 3 couleurs dynamiques, mais le jeu definit aussi
une **table fixe de ~20 couleurs nommees** (utilisee pour les particules, le
texte, les barres) et **34 strobes** (cycles de couleurs animes). Table fixe
(`colour_list.lua` 1-45) :

```lua
local colourList =
{
  {0x00/0xff, 0x00/0xff, 0x00/0xff, 0xff/0xff }, -- BLACK
  {0xff/0xff, 0xff/0xff, 0xff/0xff, 0xff/0xff }, -- WHITE
  {0xEE/0xff, 0x00/0xff, 0x00/0xff, 0xff/0xff }, -- RED
  {0x6f/0xff, 0xdd/0xff, 0xd5/0xff, 0xff/0xff }, -- CYAN
  {0x55/0xff, 0x44/0xff, 0xaa/0xff, 0xff/0xff }, -- PURPLE
  {0x18/0xff, 0x64/0xff, 0x44/0xff, 0xff/0xff }, -- GREEN
  {0x2b/0xff, 0x51/0xff, 0x87/0xff, 0xff/0xff }, -- BLUE
  {0xff/0xff, 0xff/0xff, 0x00/0xff, 0xff/0xff }, -- YELLOW
  {0xdd/0xff, 0x77/0xff, 0x11/0xff, 0xff/0xff }, -- ORANGE
  {0x77/0xff, 0x44/0xff, 0x33/0xff, 0xff/0xff }, -- BROWN
  -- ... DARK_BROWN, DARK_GREY, GREY, LIGHT_GREEN, LIGHT_BLUE, LIGHT_GREY,
  --     REFLECTION, AMBER, TRANSPARENT, TRANSPARENT_BLACK
}
BLACK = 1; WHITE = 2; RED = 3; CYAN = 4; PURPLE = 5; GREEN = 6; BLUE = 7
YELLOW = 8; ORANGE = 9; BROWN = 10 -- etc.
```

Les **strobes** sont des sequences d'indices de couleur parcourues selon le
frame, avec un mode (`XY_STROBE`, `X_STROBE`, `Y_STROBE`, `RAND_STROBE`) qui
decide si la phase depend de la position ecran X, Y, des deux, ou est aleatoire.
Exemples (`colour_list.lua` 98-134) :

```lua
G_Strobes[STROBE_RED_XY ]      = {YELLOW, ORANGE, RED,                         XY_STROBE}
G_Strobes[STROBE_RAINBOW_XY]   = {YELLOW, GREEN, CYAN, BLUE, PURPLE, RED, ORANGE, XY_STROBE}
G_Strobes[STROBE_FLICKER_BLUE] = {BLUE, BLUE, BLUE, BLUE, LIGHT_BLUE, LIGHT_BLUE,
  LIGHT_BLUE, LIGHT_BLUE, WHITE, LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE, BLUE, BLUE,
  BLUE, BLUE, RAND_STROBE}
```

Lecture d'une couleur de strobe (`colour_list.lua` 158-164) :

```lua
function G_getStrobeColour(index, frame)
  frame = math.floor(frame)
  local strobe = G_Strobes[index]
  local l = #strobe - 1            -- dernier element = le MODE, on l'exclut
  local i = strobe[(frame % l) + 1]
  return tools.cloneRGBA(colourList[i])
end
```

Exemple d'usage (texte d'alerte qui clignote rouge, `state_game.lua` 5060) :

```lua
love.graphics.setColor(G_getStrobeColour(STROBE_RED_XY, G_FixedFrame / 10))
love.graphics.printf("Safety: Off!", wx, 0, G_WorldDisplayWidth, "center")
```

### 4.11 Generation des 3 couleurs de palette (`main.lua` 2006-2015)

```lua
function G_setPrimaryAndSecondaryColours(hue1, hue2, hue3, sat)
  local r,g,b = tools.HSL(hue1, sat, 0.6)
  G_PrimaryColour = {r,g,b, 1}
  r,g,b = tools.HSL(hue2, sat, 0.5)
  G_SecondaryColour = {r,g,b, 1}
  r,g,b = tools.HSL(hue3, sat, 0.4)
  G_TertiaryColour = {r, g, b, 1}
end
```

La fonction HSL (`library/tools.lua` 1781) :

```lua
function tools.HSL(h, s, l)
   if s == 0 then return l,l,l end
   h, s, l = h*6, s, l
   local c = (1-math.abs(2*l-1))*s
   local x = (1-math.abs(h%2-1))*c
   local m,r,g,b = (l-.5*c), 0,0,0
   if h < 1     then r,g,b = c,x,0
   elseif h < 2 then r,g,b = x,c,0
   elseif h < 3 then r,g,b = 0,c,x
   elseif h < 4 then r,g,b = 0,x,c
   elseif h < 5 then r,g,b = x,0,c
   else              r,g,b = c,0,x
   end
   return (r+m),(g+m),(b+m)
end
```

Les 3 luminosites fixes (0.6 / 0.5 / 0.4) garantissent que `lightCol` >
`darkCol` > `darkestCol`, ce qui preserve la lisibilite du shading quel que soit
le biome. C'est l'astuce qui rend la recolorisation "safe" : on ne change que la
teinte, jamais l'ordre de luminosite.

---

## 5. Systeme de particules

Architecture **data-driven a 3 niveaux** :

```
particle_data.lua  (146 definitions d'effets, tables Lua pures)
        |
        v
CParticleEffect    (un emetteur : pond des particules, gere vie/rotation/chaines)
        |
        v
CParticle          (une particule : position, velocite, gravite, anim, couleur)

CParticleManager   (orchestre tous les CParticleEffect : update, collision, draw, save)
```

Les particules ne sont PAS rendues directement : elles s'ajoutent aux memes
SpriteBatch que les tuiles (via `display:addToSpriteBatch`), donc elles passent
par le **meme tri par buckets et le meme shader recolour/additif** que le monde.
C'est l'unification qui donne la coherence visuelle.

### 5.1 Le manager (`particle_manager.lua`)

Cree les effets, les met a jour en fixed-step, gere collisions et nettoyage,
serialise.

```lua
function CParticleManager:initialize(game, map, display)
  self.game  = game
  self.display      = display
  self.map          = map
  self.particleEffects = {}
  self.damageAreas = {}
  particleData.populate()        -- resout les heritages "baseParticle" + valide les chaines
end

function CParticleManager:addParticleEffect(name, position, angle, actor_parent, sprite_override, initial_state, do_not_populate)
  if G_NoParticles then return end
  local p = CParticleEffect(self, name, position, angle, actor_parent, sprite_override, initial_state, do_not_populate)
  p.ID = #self.particleEffects
  table.insert(self.particleEffects, p)
  return p
end

function CParticleManager:fixedUpdate(is_running)
  for _, v in ipairs(self.particleEffects) do
    v:fixedUpdate(is_running)
    v:collideWithActors()
  end
  for i = #self.particleEffects, 1, -1 do
    local pe = self.particleEffects[i]
    if pe.isDead and #pe.particles == 0 then
      table.remove(self.particleEffects, i)
    end
  end
end

function CParticleManager:addParticleEffectsToDrawList()
  local h_dx, h_dy = self.display:getHalfWidthAndHeight()
  h_dx = h_dx - 1; h_dy = h_dy - 1
  local screen_center_x = h_dx * G_Globals.tileSize + G_Globals.halfTileSize
  local screen_center_y = h_dy * G_Globals.tileSize + G_Globals.halfTileSize
  for i, v in ipairs(self.particleEffects) do
    v:addParticlesToDrawList(screen_center_x, screen_center_y)
  end
end
```

Le manager expose aussi des requetes spatiales (`getParticleOfTypeNearXYWithRange`,
`getAllFlameParticleEffects`, `killAllParticlesWithName`) car les particules sont
**gameplay** autant que visuelles (le feu se propage, les projectiles touchent).
Et il sait se **serialiser** (`getParticleManagerAsData` / `setUpFromData`), donc
les effets persistants (feu, brume) survivent a une sauvegarde.

### 5.2 L'effet/emetteur (`particle_effect.lua`)

`CParticleEffect:initialize` lit la definition et initialise l'etat (extraits) :

```lua
self.particleData             = particleData[name]
self.delay                    = self.particleData.initialDelay or 0
self.startAngle               = angle or 0
self.effectRotation           = self.particleData.effectRotation or 0
self.effectLife               = self.particleData.effectLife or 10
self.currentLife              = self.effectLife
self.framesBetweenParticles   = self.particleData.framesBetweenParticles or 2
self.maxParticles             = self.particleData.maxParticles or 10
self.spreadAngle              = self.particleData.spreadAngle or 360
self.rotationMultiplierPerFrame = self.particleData.rotationMultiplierPerFrame or 1
self.particlesPerFrame        = self.particleData.particlesPerFrame or 1
self.isStepTime               = self.particleData.isStepTime or false
self.isLooping                = self.currentLife == 0
```

Mecaniques notables :

- **Emission par arc.** `addParticle` (195-230) repartit les particules sur un
  arc (`spreadAngle`), en variant l'angle, la distance au centre, l'angle de
  velocite et la vitesse via des plages (`distanceRange`, `speedRange`,
  `speedAngleRange`, `radialSpacingRange`). Chaque plage peut etre un scalaire ou
  un `{min, max}` :

```lua
function CParticleEffect:getInitialSpeed()
  if type(self.particleData.speedRange) == "table" then
    return math.random() * (self.particleData.speedRange[2] - self.particleData.speedRange[1]) + self.particleData.speedRange[1]
  else
    return self.particleData.speedRange or 0
  end
end
```

- **Step-time vs realtime.** `isStepTime` : l'effet n'avance que quand le jeu
  "tourne un tour" (`is_running`), pas en continu. C'est essentiel pour un jeu au
  tour par tour : les particules de gameplay se figent entre deux tours, mais on
  autorise toujours le **premier** update (`firstUpdate`) pour qu'elles soient
  visibles immediatement.
- **Chaines d'effets.** `chain = {{"big_smoke", 2}, {"burn_up_non_step_time", 10}}`
  declenche d'autres effets a des instants precis de la vie de l'effet :

```lua
function CParticleManager:addChainedParticleEffectsFromThisParticleEffect(pe)
  local chain = pe.particleData.chain
  if type(chain) ~= "table" then chain = {chain} end
  for _, v in ipairs(chain) do
    local name = v[1]; local time = v[2]
    if (pe.effectLife - pe.currentLife) == time then
      self:addParticleEffect(name, pe.position, pe.startAngle, pe.parentActor)
    end
  end
end
```

- **Actions a la mort.** Une particule peut declencher une action gameplay quand
  elle meurt (`actionOnDeath`) : explosions, propagation de feu/poison/cecite,
  laisser une fleche ramassable, etc. La table de dispatch est enorme
  (`particle_effect.lua` 338-419) — c'est le pont entre VFX et regles.
- **Rendu** (`addParticlesToDrawList`, 465-512) : chaque particule visible est
  ajoutee au bon batch (default ou additive) avec un **bucket Y** legerement
  decale (`bucketOffset`) pour passer devant/derriere les acteurs :

```lua
local batch = G_Globals.DEFAULT_BATCH
local bucket = math.floor(my) + v.bucketOffset + G_Globals.halfTileSize * 2
if self.particleData.additive then batch = G_Globals.ADDITIVE_BATCH end
self.display:addToSpriteBatch(frame, v.col, mx, my, v.angle + self.totalRotation, v.scaleX, v.scaleY, 0, v.yOffset, bucket, batch)
```

### 5.3 La particule (`particle.lua`)

Simule la physique simple (velocite + drag + gravite + rebond), l'animation et le
cycle de couleur. Update (`particle.lua` 262-379, extraits) :

```lua
function CParticle:fixedUpdate()
  if self.angleWithMovement == false then
    self.angle = self.angle + self.particleRotation
  end
  self.scaleX = self.scaleX * self.scalePerTick
  self.scaleY = self.scaleY * self.scalePerTick
  self:reduceLifeAndDieIfAppropriate()
  self:move()
  self:updateAnimationFrame()
end

function CParticle:move()
  -- attracteur optionnel (projectiles a tete chercheuse)
  -- ...
  self.relativePosition:addVec(self.velocity)
  if self.windEffect then
    local wind_vec = self.parent.particleManager.game:getWindAsVector()
    self.relativePosition.x = self.relativePosition.x + wind_vec.x * self.windEffect
    self.relativePosition.y = self.relativePosition.y + wind_vec.y * self.windEffect
  end
  self.verticalVelocity = self.verticalVelocity + self.gravity
  self.verticalOffset = self.verticalOffset + self.verticalVelocity
  if self.verticalOffset < 0 then
    self.verticalOffset = 0
    if self.dieOnLanding then self.isDead = true; self:createParticleOnDeath() end
    self.verticalVelocity = -self.verticalVelocity * self.bounceAmount
  end
  self.drawPosition:setWithVector(self.relativePosition)
  self.drawPosition:rotate(self.parent.totalRotation)   -- herite la rotation de l'effet
  self.floorPosition:setWithVector(self.drawPosition)
  self.drawPosition.y = self.drawPosition.y - self.verticalOffset  -- "hauteur" = offset vertical
  self:updateWorldPosition()
  self:updateVisibility()
  if self.angleWithMovement then self.angle = old_pos:angleTo(self.drawPosition) end
  if self.verticalOffset == 0 and self.gravity ~= 0 then
    self.velocity:mulNum(self.dragOnLanding)
  else
    self.velocity:mulNum(self.drag)
  end
end

function CParticle:updateAnimationFrame()
  self.animDelay = self.animDelay + 1
  if self.animDelay > self.delayBetweenFrames then
    self.animDelay = 1
    self.animFrame = self.animFrame + 1
    if self.animFrame > #self.animation then self.animFrame = 1 end
  end
  self.colourIndex = self.colourIndex + self.colourSpeed
  if self.colourIndex >= #self.colours then self.colourIndex = self.colourIndex - #self.colours end
  self.col = self.colours[math.floor(self.colourIndex) + 1]
end
```

Idees-clefs :
- **Fausse 3D** : la "hauteur" d'une particule est un simple `verticalOffset`
  soustrait a la position Y de dessin. Avec `gravity`, `verticalVelocity` et
  `bounceAmount`, on obtient des debris/etincelles qui retombent et rebondissent
  en vue 2D top-down.
- **Visibilite liee a la lumiere/FOV** (`updateVisibility`, 381-388) : une
  particule n'est visible que si sa cellule est `isVisible and (isLit or isFelt)`
  (ou `alwaysVisible`). Les VFX respectent le brouillard de guerre.
- **Cycle de couleur** : `colours = {WHITE, CYAN, BLUE}` + `colourSpeed` =>
  defilement de palette par particule.

### 5.4 Anatomie d'une definition (`particle_data.lua`)

Chaque effet est une table. Champs reels observes (definition `test`,
`particle_data.lua` 7-43) :

```lua
particleData["test"] =
{
  initialDelay          = 5,
  anims                 = {"sparkle_1", "sparkle_2", "sparkle_3", "sparkle_2", "sparkle_1"},
  animDelay             = 2,
  prebake               = true,
  angleWithMovement     = false,
  angleWithSpread       = true,
  maxParticles          = 10,
  killOnMaxParticles    = false,
  effectLife            = 20,
  framesBetweenParticles = 3,   -- If ZERO this means emit no particles
  isInWorldSpace        = false, -- If in world space, particles do not move with the effect
  distanceRange         = 1,   -- the distance of the arc of effects created
  spreadAngle           = 360,          -- total angle the arc contains
  radialSpacingRange    = 0,
  speedRange            = -5,        -- Initial speed based on circle
  speedAngleRange       = 0,
  drag                  = 1,
  particleLifeRange     = 20,
  particleRotationRange = {-300, 300},
  verticalOffset        = 0,
  verticalVelocity      = 0,
  gravity               = 0,
  bounceAmount          = 0,
  dragOnLanding         = 0,
  dieOnLanding          = false,
  effectRotation        = 360,
  effectVelocityRotation=  10,
  colours               = {WHITE, CYAN, BLUE},
  colourSpeed           = 0.4,
  bucketOffset          = 0,
  additive = true,
  dieOnAnimationEnd     = false,
}
```

Exemple de **flamme continue** (effet de vie infinie, en world-space, additif,
gravite negative pour monter ; `particle_data.lua` 924-953) :

```lua
particleData["flame"] =
{
  anims                 = {"flame", "flame_2", "flame_3"},
  animDelay             = 3,
  dieOnAnimationEnd     = true,
  prebake               = false,
  angleWithSpread       = false,
  angleWithMovement     = false,
  isInWorldSpace        = true, -- If in world space, particles do not move with the effect
  maxParticles          = 3,
  effectLife            = 0,      -- 0 => boucle eternelle (isLooping)
  framesBetweenParticles = 3,
  distanceRange         = {0, 0.25},
  spreadAngle           = 0,
  radialSpacingRange    = {-10, 10},
  speedRange            = {5,5},
  speedAngleRange       = {0,0},
  drag                  = 1,
  effectRotation        = 0,
  effectVelocityRotation= 0,
  particleRotationRange = {-57,57},
  colours               = {AMBER},
  colourSpeed           = 0.1,
  additive = true,
  gravity               = -10,    -- monte
  isFlame                = true   -- tag gameplay : se propage, fait des degats
}
```

Exemple d'**heritage** via `baseParticle` (`particle_data.lua` 913-919) :

```lua
particleData["sigil_smoke"] =
{
    baseParticle = "bash_circle",   -- copie tous les champs de bash_circle...
    maxParticles          = 15,     -- ...puis surcharge
    anims = {"sigils_1","sigils_2","sigils_3","sigils_4","sigils_5","sigils_6","sigils_7","sigils_8"},
    speedRange            = {2, 2},
}
```

La resolution d'heritage et la validation des chaines se font une fois au
demarrage (`particleData.populate`, `particle_data.lua` 3459-3484) :

```lua
function particleData.populate()
  for k, v in pairs(particleData) do
    if type(v) == "table" then
      for property, data in pairs(v) do
        if property == "baseParticle" then
          assert(particleData[data], "Cannot use particle " .. data.. " as base class for particle: " .. k)
          local new_data = tools.deepcopy(particleData[data])
          for k2, v2 in pairs(v) do
            new_data[k2] = v2
            particleData[k] = new_data
          end
          break
        end
        if property == "chain" then
          for _, pair in ipairs(data) do
            local effect_life = v.effectLife
            local name = pair[1]; local time = pair[2]
            assert(time <= effect_life, k .. ": chain set at time: " .. time .. " which is beyond the effect's lifespan: " .. effect_life)
          end
        end
      end
    end
  end
end
```

Il y a **146 effets** definis (`firebomb`, `fire_ring`, `rotbomb`, `blindbomb`,
`boss_death_1`, `big_smoke`, `spores`, `polymorph`, `smoke`, `beam`, `spiral`,
`rain`, `quake`, `wind`, `blood_rain`, `sparks`, `poison`, `blind`, ...). Le
vocabulaire de tuning (env. 40 champs) couvre emission, arc, physique,
animation, couleur, chaines et actions de gameplay.

### 5.5 Spawn cote gameplay

Un effet se cree par un simple appel nomme. Exemple (mort d'enclume,
`particle_effect.lua` 379-386) :

```lua
self.particleManager:addParticleEffect("mechanical_parts", CVector(wx, wy))
self.particleManager:addParticleEffect("smoke", CVector(wx, wy))
```

La signature complete : `addParticleEffect(name, position, angle, actor_parent,
sprite_override, initial_state, do_not_populate)`. `actor_parent` attache l'effet
a un acteur (il suit sa `drawPosition`), `sprite_override` remplace l'animation
(utile pour qu'un meme effet "fleche en vol" prenne le sprite de l'arme tiree).

---

## 6. Animation et game-feel

### 6.1 Easing (`library/easing.lua`)

Bibliotheque complete d'easings, toutes prefixees `G_*`, prenant `t` dans [0,1]
et renvoyant la valeur eased. Familles : quad, cubic, quartic, quintic, sine,
circular, exponential, elastic, back, bounce. Exemples representatifs :

```lua
function G_quadEaseInOut(t)
  if t < 0.5 then return 2 * t * t end
  return (-2 * t * t) + (4 * t) - 1
end

function G_sineEaseOut(t)
  return math.sin(t * math.pi / 2)
end

function G_backEaseOut(t)
  local p = 1 - t
  return 1 - (p * p * p - p * math.sin(p * math.pi))
end

function G_bounceEaseOut(t)
  if t < 4 / 11 then return 121 * t * t / 16
  elseif t < 8 / 11 then return (363 / 40.0 * t * t) - (99 / 10.0 * t) + 17 / 5.0
  elseif t < 9 / 10 then return (4356 / 361.0 * t * t) - (35442 / 1805.0 * t) + 16061 / 1805.0 end
  return (54 / 5.0 * t * t) - (513 / 25.0 * t) + 268 / 25.0
end
```

Pattern d'usage typique dans le jeu : une `fraction` 0->1 qui avance par
`dt`/frame, passee a un easing pour piloter une interpolation
(`math.lerp(a, b, easing(fraction))`). Exemple dans `state_game:draw` (4971-4972) :

```lua
local l = math.max(self.characterPanel.fraction, self.leftHandUIFraction)
local wx = math.lerp(G_NoGUIWorldOffsetX, G_WithGUIWorldOffsetX, l)
```

(L'ouverture des panneaux glisse la vue monde via une fraction lerpee.)

### 6.2 Screen shake

Demarre par `G_startScreenShakeTimeAndPower(time, power)` ; le shake **le plus
fort gagne** (on n'ecrase pas un shake plus intense en cours). `main.lua`
1708-1741 :

```lua
function G_startScreenShakeTimeAndPower(time, power)
  if G_Options.photosensitivity then return end
  if time < G_Globals.currentScreenShakeTime then return end
  if power < G_Globals.currentScreenShakePower then return end
  G_Globals.currentScreenShakeTime = time
  G_Globals.totalScreenShakeTime = G_Globals.currentScreenShakeTime
  G_Globals.currentScreenShakePower = power or 0.25
end

function G_updateScreenShake(dt)
  if G_Globals.currentScreenShakeTime > 0 then
    G_Globals.currentScreenShakeTime = G_Globals.currentScreenShakeTime - (1 * dt)
    if G_Globals.currentScreenShakeTime < 0 then G_Globals.currentScreenShakeTime = 0 end
    local size = G_Globals.currentScreenShakePower * G_Globals.currentScreenShakeTime / G_Globals.totalScreenShakeTime
    size = size * 0.75 -- Reduce it a bit!
    G_Globals.screenShakeX = ((math.random() * size) - size / 2) -- purely visual: math.random, not love.math.random
    G_Globals.screenShakeY = ((math.random() * size) - size / 2)
  end
end
```

Caracteristiques :
- L'amplitude **decroit lineairement** avec le temps restant
  (`power * timeLeft / totalTime`).
- `screenShakeX/Y` est applique au blit final du canvas (section 3.3), donc tout
  bouge d'un bloc et le CRT masque les bords.
- Volontairement `math.random` (et pas `love.math.random`) : le shake est
  purement visuel et ne doit pas perturber le RNG de simulation deterministe.
- Respecte `G_Options.photosensitivity`.

Exemples d'appel (`actions.lua`) : `G_startScreenShakeTimeAndPower(0.5, 20 * volume)`
sur les impacts, `G_startScreenShakeTimeAndPower(2, 20)` sur les gros evenements.

### 6.3 Zoom (transition overworld <-> local)

Le `tile_screen_manager` gere un zoom par crossfade entre deux rendus du monde.
Constantes (`tile_screen_manager.lua` 22-25) :

```lua
local MIN_ZOOM = 0.5
local MAX_ZOOM = 2
local ZOOM_SPEED = 0.075
local ZOOM_ROT = 0
```

Pendant le zoom, `zoomFraction` va de 0 a 1 ; le scale du batch est interpole
(`tile_screen_manager.lua` 629-633) :

```lua
if self.isZoomingIn then
  scale = MIN_ZOOM + (1-MIN_ZOOM) * (self.zoomFraction)
elseif self.isZoomingOut then
  scale = 1 + MAX_ZOOM * (1-self.zoomFraction)
end
```

Et on superpose une copie de l'ancien rendu (`gBackupCanvas`) en alpha
`1 - zoomFraction`, agrandie/retrecie en sens inverse (section 3.4) => fondu
enchaine avec effet d'echelle, sans avoir a re-simuler les deux echelles.
`ZOOM_ROT` permettrait d'ajouter une rotation pendant la transition (a 0 ici).

### 6.4 Transition d'ecran en losanges (`main.lua` 1682-1705)

Le fondu entre etats n'est pas un simple fade alpha : c'est une grille de losanges
qui grossissent/retrecissent en vague diagonale.

```lua
function G_drawScreenTransitionEffect()
  if G_FadeType then
    love.graphics.setColor(G_FadeColour)
    local sq_sz = 40
    local sq_x = math.ceil(G_Globals.screenWidth / sq_sz)
    local sq_y = math.ceil(G_Globals.screenHeight / sq_sz)
    for y = 0, sq_y do
      for x = 0, sq_x do
        if (x + y) % 2 == 0 then
          local px = x * sq_sz
          local py = y * sq_sz
          local offset = (x+y)
          if G_FadeType == "from_black" then offset = (sq_x-x) + (sq_y-y) end
          local f = math.clamp((offset * -0.1) + (gFadeFraction*6.4))
          G_drawDiamond(px, py, sq_sz * f * 2)
        end
      end
    end
  end
  love.graphics.setColor(1,1,1,1)
end
```

`gFadeFraction` avance dans `gameUpdate` (`to_black` puis `from_black`). Le terme
`offset * -0.1` decale la phase selon la diagonale `(x+y)` => les losanges
s'ouvrent en balayage. `G_drawDiamond` est un simple polygone 4 points
(`main.lua` 1562-1565).

### 6.5 Lignes en tirets (game-feel de ciblage)

La visee a la manette dessine une ligne pointillee animee + un sprite 4-points qui
tourne (`state_game.lua` 4994-5000) :

```lua
local dash = 5
local gap = 15
local offset = math.floor(G_FixedFrame) % 20
tools.rawDashLine(sx, sy, ex, ey, dash, gap, offset)
love.graphics.draw(G_FourDotSprite, ex, ey, G_Frame / 20, 2, 2, 7, 7)
```

`G_Frame / 20` comme angle => le reticule tourne lentement et en continu.

---

## 7. UI / UX

### 7.1 Systeme de regions de souris (`mouse_handler.lua`)

L'UI est en **mode immediat** : a chaque frame, on (re)declare des "regions"
cliquables avec un label/sous-label et un rectangle, et on interroge leur etat.
API principale (signatures observees) :

```lua
mouse.addRegionWithLabelSubLabelAndRect(label, sub_label, rect)
mouse.isRegionWithLabelAndSubLabelClickedWithButton(label, sub_label, button)
mouse.isMouseOverRegionWithLabelAndSubLabel(label, sub_label)
mouse.getXYWithinRegionAsUnclampedFractions(label, sub_label)  -- pour sliders
mouse.killAllRegions()        -- appele a chaque changement d'ecran
mouse.isMouseOverButton()
mouse.drawMouseOver()
```

Le `fixedUpdate` souris tourne a 40 Hz (section 2.1). La conversion
ecran->virtuel utilise le scale/offset calcules en 3.2 :

```lua
function mouse.toVirtualX(x) -- voir mouse_handler.lua 27
function mouse.toVirtualY(y) --      mouse_handler.lua 31
```

Pattern de bouton (extrait condensé d'`G_drawExitButtonOnPanel`, `main.lua`
2018-2049) :

```lua
love.graphics.setColor(G_SecondaryColour)
love.graphics.draw(G_EscapeBackgroundIconTopRight, x, y)        -- fond teinte palette
love.graphics.setColor(0, 0, 0, 1)
love.graphics.setFont(G_Globals.mainFont)
tools.drawFormattedOutlinedText(cap, x + x_offset, y_offset + y, G_EdgeArcIconWidth, "center")
if G_MouseHandler.hasLabel(panel) then
  G_MouseHandler.addRegionWithLabelSubLabelAndRect(panel, "exit", {x1 = x, y1 = y, x2 = x + G_EdgeArcIconWidth, y2 = y + height})
end
```

L'icone de fond est teintee avec `G_SecondaryColour` => les boutons suivent
automatiquement la palette du biome courant. Le texte est dessine avec un contour
(`drawFormattedOutlinedText`).

### 7.2 Panneaux qui glissent

Les gros panneaux (inventaire, personnage, skill tree) ont une `fraction`
d'ouverture animee, utilisee a la fois pour le decalage du panneau ET pour
pousser la vue monde (section 6.1). C'est ce qui donne l'impression que l'UI
"ouvre" l'espace plutot que de le recouvrir. Le draw de `state_game` compose ces
panneaux apres le monde (`state_game.lua` 5101-5156) : `characterPanel:draw()`,
`skillTree:draw()`, `confirmBox:draw()`, `textInputBox:draw()`,
`numberInputBox:draw()`, `alertBox:draw()`, `slowTextDrawer:draw()`...

### 7.3 Texte riche et lisibilite

`CPrettyText` (section 4.5) gere les balises `{col1}...{white}` et le rendu
ombre+contour. Les couleurs de balise sont fixes (`textmacros`), mais `col1`,
`col2`, `col3` du shader pointent sur la palette dynamique => le texte
"mecanique" reste coherent avec l'ambiance. Toutes les valeurs chiffrees,
keywords et indices passent par ce systeme.

### 7.4 Polices

Plusieurs fontes bitmap chargees en `nearest`, plus une TTF pour les titres
(`main.lua` 1089-1200) :

```lua
G_Globals.beebTileFont       = love.graphics.newImageFont("assets/beeb_non_monospace.png", G_Globals.supportedCharacters)
G_Globals.atariMonospaceFont = love.graphics.newImageFont("assets/moonring_font.png", G_Globals.supportedCharacters)
G_Globals.atariFont          = love.graphics.newImageFont("assets/moonring_font_non_monospace.png", G_Globals.extendedsupportedCharacters)
G_Globals.titleFont          = love.graphics.newFont("assets/Fantasy One.ttf", 200)
G_Globals.gameOverFont       = love.graphics.newFont("assets/Fantasy One.ttf", 120)
```

Astuce notable : les **glyphes de boutons manette** sont injectes dans la fonte
en etendant la chaine de caracteres supportes avec des codepoints prives
(`0xe0+`), si bien qu'on peut ecrire un prompt "appuie sur [A]" directement dans
une string de texte (`main.lua` 1094-1101).

---

## 8. Audio (feedback)

### 8.1 Musique tracker (`library/music_handler.lua`)

La musique est en modules **`.xm` (43 fichiers) et `.it` (18 fichiers)** dans
`music/`, streamee (`love.audio.newSource(name, 'stream')`). Le handler gere un
**crossfade par volume** entre piste courante et piste demandee :

```lua
function musicHandler.update(dt)  
  local base_volume = musicHandler.baseVolume
  base_volume = musicHandler.easing(base_volume)
  if musicHandler.playingName ~= musicHandler.pendingName or musicHandler.forceRestart then
    musicHandler.forceRestart = false
    if musicHandler.volume > 0 then
      if musicHandler.fadeTime > 0 then
        musicHandler.volume = musicHandler.volume - (dt / musicHandler.fadeTime)
      else
        musicHandler.volume = 0
      end
    end
    if musicHandler.volume <= 0 then musicHandler.volume = 0; musicHandler.switch() end
  elseif musicHandler.volume < 1 then
    if musicHandler.fadeTime > 0 then
      musicHandler.volume = musicHandler.volume + (dt / musicHandler.fadeTime)
    else
      musicHandler.volume = 1
    end
  end
  if musicHandler.currentSource ~= nil then
    musicHandler.currentSource:setVolume(base_volume * musicHandler.volume)
  end
  if musicHandler.resumeName and musicHandler.currentSource and not musicHandler.currentSource:isPlaying() then
    musicHandler.resumeTrack()
  end
end

function musicHandler.easing(t)
  return math.sin((t - 1) * math.pi / 2) + 1   -- sineEaseOut sur le volume
end
```

Notes :
- Fonctions `play`, `playImmediately`, `interruptTrack` (joue puis **reprend** la
  piste precedente), `setResumeTrack`. C'est ce qui permet un stinger qui rend la
  main a l'ambiance.
- A la prise d'une nouvelle source, un **effet de reverb** est applique (sauf
  MP3/Switch), `music_handler.lua` 167-171 :

```lua
local filter_settings = {type = "lowpass", volume = 1, highgain = 0.3}
love.audio.setEffect("reverb", {type = "reverb", gain = 0.7, decaytime = 3.5})
source:setEffect("reverb", filter_settings)
```

### 8.2 SFX echantillonnes (`main.lua` 1755-1777)

Sons `.wav` (75 dans `assets/sound/`) charges en `SoundData`, mis en cache, joues
via TEsound. Un **anti-doublon** evite de jouer deux fois le meme son dans la
meme frame (`G_SoundLastPlayed`) :

```lua
function G_playSound(name, pitch, volume)
  if G_NoSound then return end
  if G_PlayerDeaf and not G_Globals.alwaysPlay[name] then return end
  if G_SoundLastPlayed ~= name then G_SoundLastPlayed = name else return end
  local sound_path = "assets/sound/" .. name .. ".wav"
  local sound = G_SoundCache[name]
  if sound == nil then
    sound = love.sound.newSoundData(sound_path)
    G_SoundCache[name] = sound
  end
  pitch = pitch or 1; volume = (volume or 1) * G_SoundVolume
  TEsound.play(sound, 1, volume, pitch)
end
```

### 8.3 SFX procedural (SFXR) (`main.lua` 1792-1845)

Beaucoup de sons sont **synthetises a la volee** par `library/sfxr.lua` a partir
de descripteurs (`assets/sound/*.lua`, 105 fichiers). Le resultat est mis en
cache, et le jeu recycle un anneau de 6 sources audio :

```lua
G_MaxSourceIndices = 6
function G_playSFXRSound(name, volume, tag)
  if G_NoSound then return end
  if G_PlayerDeaf and not G_Globals.alwaysPlay[name] then return end
  if volume == 0 then return end
  volume = (volume or 1) * G_SoundVolume
  if G_SoundLastPlayed ~= name then G_SoundLastPlayed = name else return end
  if tag and G_SFXRSoundsPlaying[tag] then return end   -- evite les sons "tag" en double (boucles)
  local sounddata = G_SFXRCache[name]
  if sounddata == nil then
    local sound = sfxr.newSound()
    local str = G_SFXRSounds[name]
    if str == nil then str = name end           -- on peut passer directement une table de params
    sound:loadString(str, 1)
    sounddata = sound:generateSoundData()
    G_SFXRCache[name] = sounddata
  end
  if G_SFXSources[G_SourceIndex] == nil then
    G_SFXSources[G_SourceIndex] = love.audio.newSource(sounddata)
  else
    G_SFXSources[G_SourceIndex]:release()
  end
  G_SourceIndex = G_SourceIndex + 1
  if G_SourceIndex > G_MaxSourceIndices then G_SourceIndex = 1 end
  local source = love.audio.newSource(sounddata)
  source:setVolume(volume)
  source:play()
  if tag then G_SFXRSoundsPlaying[tag] = source end
end
```

Le volume des sons spatialises est souvent calcule par distance
(`game:getVolumeOfSoundFromVector(...)`), par ex. dans la collision de
projectiles (`particle.lua` 222). Il existe aussi des variantes **retardees**
(`G_playDelayedSFXRSound`, `G_playDelayedSampledSound`) mises a jour dans
`gameUpdate`.

---

## 9. Ce qu'on vole pour The Pit

Liste priorisee de techniques directement transposables, avec un mini "comment
l'appliquer". Toutes respectent la frontiere SIM/PRESENTATION de The Pit : ce
sont des effets de presentation pilotes par des uniforms/parametres, jamais des
mutations de la simulation.

1. **Recolorisation par palette a 3 couleurs (shader recolour).**
   - *Vol* : `shaders/recolour.fs` + `G_set...Colours(HSL)`.
   - *Comment* : encoder les sprites en index-map (canal vert = zone : 0 noir / 1
     blanc / intermediaire = teinte ; canal rouge = clair/fonce). Envoyer 3
     `vec4` (`lightCol`/`darkCol`/`darkestCol`) generes en HSL a luminosites
     fixes (0.6/0.5/0.4) pour garantir la hierarchie de valeurs. On obtient un
     reskin complet par biome/faction/rarete en changeant 3 uniforms, et des
     flashs de degats en poussant temporairement une couleur. S'applique aussi au
     texte (`text_recolour.fs`, decision sur `color.g`).

2. **CRT minimal en une passe (scanlines + feather + grain).**
   - *Vol* : `shaders/crt_emulation.fs`, applique au blit final.
   - *Comment* : tout dessiner dans un canvas interne a resolution fixe, puis le
     blitter une fois avec ce shader. Scanlines = `mod(px.y,3)` en luminance ;
     vignette = double `smoothstep` sur `abs(uv)` ; grain = value-noise seede par
     `sin(iTime*0.03)`, melange a ~1%. Cout : une passe, aucune texture de masque.
     Optionnel : decommenter `distortionFactor` pour la courbure.

3. **Screen-shake applique au blit du canvas, pas au monde.**
   - *Vol* : `G_startScreenShakeTimeAndPower` + offset au `love.graphics.draw`
     final.
   - *Comment* : garder un `shakeX/shakeY` qui decroit lineairement
     (`power * timeLeft/totalTime`), genere avec `math.random` (PAS le RNG de
     sim), et l'ajouter a la position de dessin du canvas complet. "Le plus fort
     gagne" pour ne pas hacher les gros impacts. La vignette du CRT cache les
     bords decales. Respecter une option photosensibilite.

4. **Pipeline a canvas unique + buckets Y + pool de commandes.**
   - *Vol* : `tile_screen_manager.lua` (buckets, `_drawCommandPool`,
     `resetDrawCommands`).
   - *Comment* : composer monde + UI dans un canvas a resolution interne ; trier
     les sprites par tranche Y (bucket) avec un seul `table.sort` de cles ;
     reutiliser un pool de tables de commandes (reset des compteurs, pas de
     `table.remove`) pour zero alloc/frame. Trois SpriteBatch (alpha / additif /
     special) pour gerer les modes de blend sans changer d'etat trop souvent.

5. **Particules data-driven unifiees avec le rendu monde.**
   - *Vol* : `particle_data.lua` -> `particle_effect.lua` -> `particle.lua` ->
     `particle_manager.lua`.
   - *Comment* : decrire chaque effet comme une table (emission en arc via
     `spreadAngle`/`distanceRange`/`speedRange` en plages `{min,max}`, physique
     `gravity`/`bounceAmount`/`drag`, anim, `colours`+`colourSpeed`, `additive`,
     `chain`, `actionOnDeath`). Heritage par `baseParticle`, validation au
     `populate()`. Router les particules dans les **memes batches/shaders** que le
     reste pour une coherence gratuite. Pour un jeu non temps-reel, prevoir le
     flag `isStepTime` (avance seulement quand la sim "tourne", mais autorise le
     premier update).

6. **Fausse 3D par `verticalOffset`.**
   - *Vol* : `particle.lua:move()`.
   - *Comment* : pour des debris/etincelles/projectiles en vue 2D, stocker une
     "hauteur" comme un offset Y soustrait au dessin, avec gravite + rebond. Tres
     peu de code pour un feel de matiere qui retombe.

7. **Strobes : cycles de couleurs indexes par frame et par position ecran.**
   - *Vol* : `colour_list.lua` (`G_Strobes`, `G_getStrobeColour`).
   - *Comment* : definir des sequences d'indices de palette + un mode (phase
     selon X, Y, XY ou aleatoire). Lire la couleur par `frame % len`. Ideal pour
     du feu, des alertes "wanted/aggrieved", des sigils animes, des highlights de
     carte — sans assets supplementaires.

8. **Transition d'ecran en motif (losanges en vague diagonale).**
   - *Vol* : `G_drawScreenTransitionEffect`.
   - *Comment* : au lieu d'un fade alpha, dessiner une grille de formes dont la
     taille depend de `clamp(offset*-k + fraction*K)` avec `offset = x+y` =>
     ouverture/fermeture en balayage. Bien plus caracteristique qu'un fondu noir.

9. **Texte riche teinte + ombre/contour, branche sur la palette.**
   - *Vol* : `pretty_text.lua` + `text_recolour.fs`.
   - *Comment* : parser des balises `{col1}...{white}`, rendre via un `Text`
     object sous shader, et faire pointer `col1/2/3` sur la palette dynamique.
     L'ombre = 4 dessins decales en noir. Garantit que les keywords/valeurs
     restent lisibles dans toutes les ambiances.

10. **SFX procedural (SFXR) avec cache + anneau de sources + anti-doublon.**
    - *Vol* : `G_playSFXRSound`, `library/sfxr.lua`.
    - *Comment* : synthetiser les sons d'UI/combat a partir de descripteurs,
      mettre en cache le `SoundData`, recycler ~6 sources, et bloquer le meme son
      deux fois dans la meme frame (`G_SoundLastPlayed`) + les boucles via un
      `tag`. Variante musique : crossfade par volume avec `interruptTrack`/resume
      et reverb sur la source.

---

### Annexe — fichiers sources cles (pour qui aurait le code)

| Sujet | Fichier(s) |
|---|---|
| Config / boucle / post-process / audio | `main.lua` (conf 304, load 813, draw 1587-1668, run 2145, shake 1708, SFXR 1792) |
| Constantes resolution/tuiles/batch | `globals.lua` (492-499, 575-584, 1105-1107) |
| Shaders | `shaders/*.fs` |
| Rendu monde / buckets / recolour | `tile_screen_manager.lua` |
| Particules | `particle_data.lua`, `particle_effect.lua`, `particle.lua`, `particle_manager.lua` |
| Palette / strobes | `colour_list.lua`, `tools.HSL` dans `library/tools.lua` |
| Texte riche | `pretty_text.lua` |
| Etats | `library/gamestate.lua`, `state_game.lua`, `state_title_screen.lua`, `state_editor.lua` |
| Easing | `library/easing.lua` |
| Audio | `library/music_handler.lua`, `library/sfxr.lua`, `library/tesound.lua` |
| Souris / UI immediate | `mouse_handler.lua` |
```
