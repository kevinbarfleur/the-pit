# Arco — dissection visuelle LÖVE

> Tactical-RPG pixel-art en temps réel-tour-par-tour (les "planners" résolvent
> tous en simultané), grimdark western-désertique, sorti commercialement sur
> Steam/Switch. Là où Balatro nous apprend le juice de carte, Arco nous apprend
> le **rendu pixel-art d'un monde** : résolution interne + upscaling entier,
> caméra, parallaxe multi-couches, shader de nuit/lumières, ECS data-driven,
> screenshake + hitstop, et un système de tween graphique (`graphics_lerp`)
> extrêmement réutilisable pour du feedback hover/click/drag.

Sources lues verbatim (extraites du `.love`, lecture seule) : `conf.lua`,
`main.lua`, `src/main_loop.lua` (alias `lib/ferris/main_loop.lua`),
`src/display.lua`, `src/camera.lua`, `src/shaders.lua`, `src/screenshake.lua`,
`src/gamepause.lua`, `src/screen_transition.lua`, `src/graphics_lerp.lua`,
`src/soft_cursor.lua`, `src/9slice.lua`, `src/states/loading.lua`,
`src/states/game.lua`, `src/journey/layer_config.lua`,
`src/entities/parallax_sprite.lua`, `src/entities/particles.lua`,
`src/audio/init.lua`, `lib/ferris/init.lua`, `lib/ferris/ecs/kernel.lua`,
`lib/ferris/ecs/entity.lua`, `lib/ferris/ecs/systems/sprite_system.lua`,
`lib/ferris/ecs/systems/animation_system.lua`,
`lib/ferris/ecs/systems/text_system.lua`,
`lib/ferris/ecs/systems/behaviour_system.lua`,
`lib/ferris/util/screenshake.lua`, `lib/ferris/util/screen_overlay.lua`,
`lib/batteries/mathx.lua`, `lib/batteries/class.lua`.

Tous les chemins ci-dessous sont relatifs à la racine du `.love` d'Arco.

---

## 1. Fiche technique

| Élément | Valeur |
|---------|--------|
| Moteur | LÖVE **11.4** (`conf.lua` : `t.version = "11.4"`) |
| Langage | Lua 5.1 / LuaJIT — **mais le JIT est désactivé** (`require("jit").off()` en tête de `main.lua`, commentaire : "hurts performance but more stable") |
| Fenêtre "canon" | 1280×720, release en `fullscreen = "desktop"` |
| Fichiers Lua | ~2100 (gros projet de production) |
| Libs tierces | **`batteries`** (utilitaires Lua), **`ferris`** (ECS + boucle + input maison, même auteur que batteries) |
| Shaders | **6 shaders GLSL inline** dans `src/shaders.lua` (aucun `.glsl`/`.fs` séparé) |
| Architecture | ECS data-driven (`ferris.kernel` + systèmes) + machine à états de scènes |
| Rendu | **résolution interne fixe** rendue sur canvas, puis **scale entier** (pixel-art) pour la sim + scale fractionnaire pour la lettre-box ; séparation **world canvas / UI canvas** |
| Filtre global | `lg.setDefaultFilter("nearest", "nearest")` (net, pixellisé) |
| Déterminisme | tout passe par `love.math.random` (seedable), pas de `math.random` global en sim |

### 1.1 `conf.lua` (verbatim, l'essentiel)

```lua
function love.conf(t)
	t.version = "11.4"

	t.identity = "arco"
	t.window.title = "Arco"
	t.window.icon = "assets/icon.png"

	local dev_build = false

	--"canon" size
	t.window.width = 1280
	t.window.height = 720

	if dev_build then
		-- commandline output for windows
		t.console = true
		...
		t.window.resizable = true
	else
		t.window.fullscreen = "desktop"
	end
end
```

À retenir : la "taille canon" 1280×720 n'est qu'un **point de référence de
design** ; le vrai dimensionnement se fait à l'exécution (voir §3). Le bloc
`dev_build` contient une liste de résolutions de test (4K, 1080p, SteamDeck
800×1280…) qui documente la fourchette d'écrans visée.

### 1.2 Arbre des dossiers (commenté)

```
conf.lua                 -- config fenêtre (11.4, 1280x720, fullscreen desktop)
main.lua                 -- jit.off, require batteries+ferris, love.update/draw/quit, input
gamecontrollerdb.txt     -- mapping manettes SDL
lib/
  batteries/             -- "stdlib" Lua : class, vec2, mathx, tablex, functional,
                         --   timer, state_machine, colour, set, sequence, pubsub,
                         --   manual_gc, make_pooled, intersect, pathfind...
  ferris/                -- moteur maison (même auteur)
    init.lua             -- table d'export : kernel, entity, systems{}, util{}, input{}
    main_loop.lua        -- redéfinit love.run : pas de temps fixe + accumulateur
    ecs/
      kernel.lua         -- coordinateur systèmes + "tasks" (update/draw) ordonnées
      entity.lua         -- entité = sac de composants issus de systèmes
      systems/
        base.lua            -- helpers d'enregistrement/gestion différée
        sprite_system.lua   -- LE rendu : sprites, tri z, culling caméra, immediate-mode
        animation_system.lua-- animations frame-par-frame de sprites
        text_system.lua     -- texte love.graphics.newText aligné
        behaviour_system.lua-- "lazy" : composants avec update/draw ad-hoc (particules, IA…)
        event_system.lua    -- pub/sub d'événements de scène
        beat_system.lua     -- cadence/tempo
    util/
      screenshake.lua    -- secousse caméra (décroissance exponentielle)
      screen_overlay.lua -- flash/fade plein écran (lerp de couleur)
      profiler.lua       -- profiler hiérarchique (affiché en jeu via touche `)
      frequency_counter.lua, crossfade.lua, random_pool.lua, unique_mapping.lua
    input/
      keyboard.lua, mouse.lua, gamepad.lua -- abstraction d'entrée unifiée
src/
  display.lua            -- résolution interne, scale entier, canvases, fonts, print*
  camera.lua             -- caméra world<->screen<->ui, push/pop, culling AABB
  shaders.lua            -- 6 shaders GLSL inline + helpers night/void
  screenshake.lua        -- copie locale du screenshake ferris (+ scale réglage joueur)
  gamepause.lua          -- HITSTOP : gèle la sim N frames sur impact
  screen_transition.lua  -- wipe diagonal + fade entre scènes (machine à états)
  graphics_lerp.lua      -- TWEEN GRAPHIQUE empilable (offset/scale/angle) : tout le juice
  soft_cursor.lua        -- curseur logiciel animé (wiggle au clic via graphics_lerp)
  9slice.lua             -- rendu 9-slice d'une texture bordée
  main_loop.lua          -- alias require de ferris.main_loop
  states/                -- scènes : loading, title, journey (exploration), game (combat)…
  journey/
    layer_config.lua     -- DATA de parallaxe : couches par biome (z, factor, assets)
  entities/
    parallax_sprite.lua  -- entité ECS d'une couche de décor parallaxe
    particles.lua        -- usine à particules (sprites animés data-driven)
    player.lua, enemy_base.lua, boss_*.lua…
  actions/               -- "planners" et "actions" du combat (anticipation/impact)
  audio/
    init.lua             -- TOUT l'audio : mix channels, variations, play_now/positional
    music.lua, ambient.lua, sound_pool.lua, music_track.lua
  systems/               -- systèmes spécifiques Arco (arco_sprites, arco_physics, tags…)
assets/                  -- png/ogg/ttf : journey (parallaxe), entities, ui, fonts, audio
locale/                  -- i18n
```

### 1.3 Les deux libs et leur rôle

**`batteries`** (`lib/batteries/`) est la bibliothèque utilitaire de l'auteur
(Max Cahill / "1bardesign"). Importée par `require("lib.batteries"):export()`
dans `main.lua`, elle **injecte des fonctions dans les tables globales** (`math`,
`table`, `string`) et expose des globales : `class`, `vec2`, `vec3`, `colour`,
`functional`, `set`, `sequence`, `timer`, `state_machine`, `intersect`,
`manual_gc`, `mathx`… C'est ce qui explique les appels du style `math.lerp`,
`math.clamp01`, `table.back`, `vec2():pooled_copy()`, `functional.filter` partout
dans Arco sans `require` local. Modules clés réutilisés :

- `class.lua` : OOP minimaliste (héritage, mixins, `type()`).
- `vec2.lua` : vecteurs 2D **poolés** (`:pooled()` / `:release()`) pour éviter
  le GC dans les boucles chaudes — central pour le rendu et la physique.
- `mathx.lua` : **les courbes d'easing** (`identity`, `smoothstep`,
  `smootherstep`, `ease_in/out/inout`, `lerp`, `remap_range_clamped`) qui
  pilotent tout le game-feel.
- `state_machine.lua` : machines à états (scènes, transitions d'écran).
- `manual_gc.lua` : balayage incrémental du GC (`manual_gc(1e-3, 2048, true)` à
  chaque frame dans `main.lua`).

**`ferris`** (`lib/ferris/`) est le **moteur** : il fournit (a) une boucle
principale à pas de temps fixe qui **redéfinit `love.run`**, (b) un ECS léger
(kernel + entity + systèmes), (c) des utilitaires de feel (screenshake, overlay),
(d) une couche d'input. `main.lua` ne fait que :

```lua
require("lib.batteries"):export()
ferris = require("lib.ferris")
...
local main_loop = require("src.main_loop")()  -- = ferris.main_loop, redéfinit love.run
```

---

## 2. Architecture

### 2.1 Point d'entrée et boucle (`main.lua`, `lib/ferris/main_loop.lua`)

`main.lua` désactive le JIT, importe batteries+ferris, installe un error handler,
**instancie le main_loop (qui remplace `love.run`)**, puis configure les
sous-systèmes globaux dans l'ordre : locale, `lg` (alias `love.graphics`),
filtre `nearest`, save, `display`, métriques, `shared`, `input`, `soft_cursor`,
`profiler`, `audio`, `screen_transition`, et enfin l'état de jeu initial
(`src.states.loading`). Un facteur global accélère subtilement tout le jeu :

```lua
SPEEDUP_FACTOR = 1.15
...
local speedup_dt = dt * SPEEDUP_FACTOR
game_state:update(speedup_dt)
```

La boucle elle-même (`lib/ferris/main_loop.lua`) est un **pas de temps fixe avec
accumulateur** — la base de tout déterminisme et de toute stabilité d'animation :

```lua
function main_loop:new(interpolate_render)
	self.frametime = 1 / 60
	...
	function love.run()
		if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
		love.timer.step()
		local frametimer = 0
		return function()
			-- events…
			local dt = love.timer.step()
			-- fuzzy timing snapping : colle dt aux multiples 1/2,1,2 de la frame
			for _, v in ipairs {1/2, 1, 2} do
				v = self.frametime * v
				if math.abs(dt - v) < 0.002 then dt = v end
			end
			dt = math.clamp(dt, 0, 2 * self.frametime)
			frametimer = frametimer + dt
			frametimer = math.clamp(frametimer, 0, 8 * self.frametime)

			local ticked = false
			while frametimer > self.frametime do
				frametimer = frametimer - self.frametime
				love.update(self.frametime) -- dt CONSTANT
				ticked = true
				if IS_SWITCH() then break end
			end

			if love.graphics and love.graphics.isActive()
				and (ticked or self.interpolate_render) then
				love.graphics.origin()
				love.graphics.clear(love.graphics.getBackgroundColor())
				love.draw(frametimer / self.frametime) -- passe l'interpolant
				love.graphics.present()
			end

			if self.after_frame then self:after_frame()
			else manual_gc(1e-3); love.timer.sleep(0.001) end
		end
	end
end
```

Points remarquables à voler :
- **`love.update` reçoit toujours `1/60`**, jamais le vrai `dt` : la sim est
  parfaitement reproductible et insensible au framerate.
- **"fuzzy timing snapping"** : si le `dt` mesuré est à ±2 ms d'un multiple de la
  frame, on l'aligne exactement → élimine le micro-jitter sur écrans 60/120/144 Hz.
- **clamp de l'accumulateur** à 8 frames : empêche la "spirale de la mort" après
  un freeze (pas de rattrapage infini).
- `after_frame` (défini dans `main.lua`) gère le **GC manuel** par petits coups
  + un `love.timer.sleep(0.001)` pour rendre la main au CPU.

### 2.2 L'ECS `ferris` : kernel + entity + systèmes

L'unité d'orchestration est le **kernel** (`lib/ferris/ecs/kernel.lua`). Un
kernel possède des *systèmes* nommés et des *tâches* (`tasks`) ordonnées. Les
systèmes s'enregistrent eux-mêmes en ajoutant des tâches `update`/`draw` :

```lua
local k = kernel:new({ camera = cam })
	:add_system("event", ferris.systems.event_system())
	:add_system("behaviour", ferris.systems.behaviour_system())
	:add_system("animation", ferris.systems.animation_system())
	:add_system("sprite", require("src.systems.arco_sprites")({ camera = cam }))
-- puis :
k:update(dt)  -- = run_task("update", dt)
k:draw()      -- = run_task("draw")
```

Les tâches sont triées par `order` (constantes `order_early=-1e3`,
`order_normal=0`, `order_late=1e3`), ce qui donne un **pipeline draw déterministe
et insérable** (un système peut s'insérer "tôt" pour préparer un canvas, "tard"
pour le finaliser). Extrait clé :

```lua
function kernel:add_task(name, func, order)
	local tasks = self.tasks[name] or {}
	self.tasks[name] = tasks
	table.insert_sorted(tasks, {order or kernel.order_normal, func}, kernel._task_sort)
	return self
end
function kernel:run_task(name, ...)
	local tasks = self.tasks[name]
	if tasks then
		for _, task in ipairs(tasks) do
			local ret = task[2](self, ...)
			if ret then return ret end
		end
	end
end
```

Une **entité** (`lib/ferris/ecs/entity.lua`) n'est qu'un **sac de composants**
créés depuis les systèmes du kernel, avec destruction ordonnée et **différée** :

```lua
function entity:add_component(system, name, ...)
	local sys = self.systems[system]
	if sys == nil then error("system '"..system.."' not registered…") end
	if name == nil then name = generate_unique_name("__unnamed_component_") end
	local comp = sys:add(...)
	return self:add_existing_component(name, comp, sys, call_default_destructor)
end
function entity:c(name) return self.components[name] end  -- accès raccourci

-- destruction différée, vidée une fois par frame :
local entities_to_destroy = set()
function entity:destroy() self:_check_double_destroyed(); entities_to_destroy:add(self) end
function entity.flush_entities()
	while entities_to_destroy:size() > 0 do
		local old = entities_to_destroy
		entities_to_destroy = set()
		for _, e in old:ipairs() do e:destroy_now() end
	end
end
```

`main.lua` appelle `ferris.entity.flush_entities()` chaque frame après l'update :
les entités détruites pendant la frame (mort d'un ennemi, fin d'une particule)
ne disparaissent qu'à un point sûr — pas en plein milieu d'une itération.

Le `behaviour_system` (`lib/ferris/ecs/systems/behaviour_system.lua`) est la
**porte de sortie data-driven** : un "behaviour" est juste une table avec
éventuellement `update(self, dt)` / `draw(self)` / `order`. C'est ainsi que les
particules, les IA spécialisées et les couches de parallaxe se branchent sans
classe dédiée (voir §7). C'est l'équivalent "lazy component" : on n'écrit un vrai
système que quand un comportement devient assez fréquent pour mériter un batch.

### 2.3 Scènes / états

L'état global `game_state` est une machine à états de **scènes** (`src/states/`).
Les scènes notables : `loading` (chargement async des assets via coroutines),
`title`, `journey` (exploration latérale avec parallaxe), `game` (le combat
tactique). `main.lua` route les events système vers la scène courante :

```lua
function love.resize(w, h)
	display:set_window_size(w, h)
	local cur = game_state:current_state()
	if cur and cur.k then
		local e = cur.k.systems.event
		if e then e:publish("screen resize", display.width_scaled, display.height_scaled) end
	end
	if game_state:in_state("game") then
		require("src.shaders").void_shader:send("display_scale", display.scale)
	end
end
```

Chaque scène de combat possède en réalité **deux kernels** : un kernel "monde"
(`self.k`, avec caméra/culling) et un kernel "UI" (`self.ui_k`, sans caméra),
ce qui matérialise la frontière SIM/PRÉSENTATION (voir §3.4).

### 2.4 Diagramme texte de la frame

```
love.run (ferris)                    -- pas fixe + accumulateur
 ├─ while accumulateur > 1/60 :
 │   love.update(1/60)               -- (main.lua)
 │     ├─ save_data:update()
 │     ├─ input:update(dt)
 │     ├─ display:update()
 │     ├─ game_state:update(dt*1.15) -- scène courante → kernel:update → tasks "update"
 │     │     ├─ physics → behaviours → animation → (sprites: rien en update)
 │     │     └─ gamepause gèle la sim si :is_paused()
 │     ├─ screen_transition:update(dt)
 │     ├─ audio:update(dt)
 │     ├─ ferris.entity.flush_entities()  -- destructions différées
 │     └─ soft_cursor:update(dt)
 └─ love.draw(interp)                -- (main.lua)
      ├─ lg.clear(0,0,0,1)
      ├─ display:push()              -- setCanvas(current_frame), repère monde
      ├─ game_state:draw()           -- kernel:draw → tasks "draw" triées par order
      │     ├─ [order early] setCanvas(grey_canvas), night start, camera:push, void setup
      │     ├─ sprite_system:draw(camera)  -- tri z + culling + batch
      │     ├─ [order late]  night finalise (mix lumières), void reflections
      │     └─ ui_k:draw()           -- HUD, planners, overlay, screen_overlay
      ├─ display:start_ui()          -- bascule sur ui_frame (canvas séparé)
      ├─ screen_transition:draw()    -- wipe/fade par-dessus tout
      ├─ display:pop()               -- compose current_frame + ui_frame à l'écran (scale)
      ├─ soft_cursor:draw()          -- curseur logiciel
      └─ display:swap_buffers()
```

---

## 3. Pipeline de rendu & pixel-art

C'est le cœur de ce qu'on vient voler à Arco. Tout est dans `src/display.lua`,
`src/camera.lua` et `src/states/loading.lua` (`arco_newImage`).

### 3.1 Résolution interne + scale entier vs scale lettre-box

`display.lua` ne raisonne pas en pixels écran mais en **"résolution interne
cible"** choisie parmi une table, avec deux échelles distinctes par type de scène
(`journey` plus zoomé, `combat` moins) :

```lua
display.target_resolutions = {
	{ size = vec2(3840, 2160), scale = { journey = 12, combat = 8 } },
	{ size = vec2(1920, 1080), scale = { journey = 6,  combat = 4 } },
	{ size = vec2(1600,  900), scale = { journey = 5,  combat = 4 } },
	{ size = vec2(1280,  720), scale = { journey = 4,  combat = 3 } },
}
```

À chaque changement de fenêtre, `refresh_dimensions()` choisit la cible la plus
proche, puis calcule **deux facteurs** :

```lua
function display:refresh_dimensions()
	self:find_target_resolution(vec2(self.raw_width, self.raw_height))
	self.scale = self:get_target_scale(self.scale_type)   -- ENTIER : pixels d'art (3..12)

	-- facteur fractionnaire pour remplir l'écran réel sans déformer :
	local x_factor = self.raw_width  / self.target_resolution.size.x
	local y_factor = self.raw_height / self.target_resolution.size.y
	local scale_factor = math.min(x_factor, y_factor)
	self.canvas_scale = scale_factor                       -- FRACTIONNAIRE : letterbox

	self.width  = self.target_resolution.size.x            -- taille du canvas monde
	self.height = self.target_resolution.size.y

	-- centrage (barres noires)
	self.offset = vec2(self.width * self.canvas_scale, self.height * self.canvas_scale)
		:ssubi(self.raw_width, self.raw_height):smuli(-0.5)

	-- dimensions "logiques" pour le gameplay/UI = canvas / scale entier
	self.width_scaled, self.height_scaled = self.width / self.scale, self.height / self.scale
	self:setup_fonts()

	local function screen_cv()
		local cv = lg.newCanvas(self.width, self.height)
		cv:setFilter("linear", "linear")   -- l'upscale FINAL est lissé…
		return cv
	end
	self.current_frame = screen_cv()
	self.ui_frame      = screen_cv()
	self.last_frame    = screen_cv()
end
```

**La double échelle est l'astuce clé** :
1. `display.scale` (entier, ex. 4 ou 8) = combien de pixels écran par pixel d'art.
   Le monde est dessiné dans le canvas à cette échelle → **pixels nets, jamais de
   demi-pixel** dans l'art lui-même. Le filtre global est `nearest`.
2. `display.canvas_scale` (fractionnaire) = facteur d'upscale du canvas entier
   vers la fenêtre réelle, **avec filtre `linear`** et barres noires centrées
   (`offset`). Comme on lisse seulement la mise à l'échelle finale d'un canvas
   déjà net, on garde l'esthétique pixel sans imposer une fenêtre multiple exact.

Autrement dit : *art rendu en nearest à un multiple entier, image finale
posée en linear pour épouser n'importe quelle taille d'écran.* C'est la recette
"pixel-perfect mais plein écran" la plus pragmatique du lot.

### 3.2 Le `arco_newImage` : passage forcé par canvas

Toutes les images d'Arco passent par ce helper (`src/states/loading.lua`) :

```lua
SHOVE_THROUGH_CANVAS = true
function arco_newImage(filename)
	local i = lg.newImage(filename)
	if SHOVE_THROUGH_CANVAS then
		local w, h = i:getDimensions()
		local c = lg.newCanvas(w, h, { format = "rgba8" })
		lg.push("all")
		lg.setCanvas(c)
		lg.origin()
		lg.setBlendMode("replace", "premultiplied")
		lg.draw(i)
		lg.pop()
		i:release()          -- libère l'ImageData CPU
		i = c
	end
	return i
end
```

But : **dessiner l'image dans un canvas puis libérer l'`Image` d'origine** pour
laisser tomber la copie CPU de l'`ImageData` (économie mémoire sur un gros
projet), et homogénéiser tout le contenu en `rgba8` premultiplié. Détail de prod
souvent oublié — utile si The Pit charge des centaines de sprites générés.

### 3.3 Caméra (`src/camera.lua`)

Caméra minimaliste mais complète : elle applique `scale` (le scale entier) puis
centre, et fournit toutes les conversions d'espace. Le `push` est un simple
`lg.push/scale/translate` :

```lua
function camera:push()
	self:update_centre()
	lg.push("all")
	lg.scale(self.scale)
	lg.translate(self.screen_centre.x, self.screen_centre.y)
	lg.translate(-self.pos.x, -self.pos.y)
end
function camera:update_centre()
	self.screen_centre = vec2(display:dimensions()):sdivi(self.scale):sdivi(2)
end
```

Le culling se fait via `aabb_onscreen` (boîte caméra élargie ×3) consommé par le
`sprite_system` — voir §3.5. Les conversions `screen_to_world` / `world_to_ui` /
`ui_to_screen` chaînent `offset`, `canvas_scale` et `scale` pour transformer la
souris écran en coordonnées monde malgré la double échelle.

### 3.4 Deux canvas : monde + UI (`display:push/start_ui/pop`)

Le monde et l'UI sont rendus sur **deux canvas distincts** puis composés. Cela
permet à l'UI d'échapper aux shaders/teinte du monde (nuit, gris, void) et à la
transition d'écran de passer par-dessus tout :

```lua
function display:push()
	lg.push("all")
	lg.setCanvas{self.current_frame, stencil=true}
	lg.clear(lg.getBackgroundColor())
	self.has_ui = false
end
function display:start_ui()
	if self.has_ui then lg.setCanvas{self.ui_frame, stencil=true}; return end
	lg.pop(); lg.push("all")
	lg.setCanvas{self.ui_frame, stencil=true}
	lg.clear(0, 0, 0, 0)
	self.has_ui = true
end
function display:pop()
	lg.pop(); lg.push("all")
	for i, v in ipairs({ self.current_frame, self.has_ui and self.ui_frame }) do
		if v then
			lg.setBlendMode("alpha", "premultiplied")
			lg.draw(v, self.offset.x, self.offset.y, 0, self.canvas_scale) -- upscale linéaire final
		end
	end
	lg.pop()
end
```

`display:swap_buffers()` échange `current_frame`/`last_frame` : Arco garde la
frame précédente sous la main (utilisée par certains effets de feedback / shaders
de réflexion).

### 3.5 Tri de profondeur, batching et culling (`sprite_system.lua`)

`lib/ferris/ecs/systems/sprite_system.lua` est le renderer 2D. Chaque `sprite`
porte `pos, z, rot, scale, framesize, frame, colour, blend, shader, stencil`. Le
système fait, dans l'ordre, **cache des positions → tri → culling → exécution** :

```lua
function sprite_system:_draw_prepare()
	self:_cache_pos(self.sprites)                       -- pos écran (ou via transform_fn)
	if self.z_order then
		table.insertion_sort(self.sprites, self.sprite_order)  -- tri ADAPTATIF
	end
	self.sprites_to_render = functional.filter(self.sprites, self.filter_and_store)
	-- sprites "immediate mode" injectés ce frame, insérés au bon z puis vidés
	...
end
```

Trois finesses notables :

1. **Tri secondaire pour le batching.** L'ordre n'est pas seulement `z` : à `z`
   égal on trie par texture puis par shader, via un `unique_mapping` (numérote
   chaque texture/shader rencontré). Résultat : les draws de même texture se
   suivent → moins de changements d'état GPU.
   ```lua
   self.sprite_order = function(a, b)
   	local a_order, b_order = a.z, b.z
   	if not args.preserve_order and a_order == b_order then
   		a_order = _order:map(a.texture); b_order = _order:map(b.texture)
   		if a_order == b_order then
   			a_order = _order:map(a.shader or 0); b_order = _order:map(b.shader or 0)
   		end
   	end
   	return a_order < b_order
   end
   ```
2. **Tri par insertion adaptatif.** `table.insertion_sort` est O(n) quand la
   liste est déjà presque triée — ce qui est le cas frame après frame (le z d'un
   sprite bouge peu). Plus rapide qu'un quicksort sur ce profil de données.
3. **Culling AABB caméra** (`filter_sprite`) avec une marge dépendant de la
   rotation (`0.5 + |sin(rot*2)|*0.25`) pour ne pas couper un sprite tourné, et
   stockage de `on_screen` sur le sprite (réutilisé par l'animation : on
   n'avance pas forcément les anims hors écran).

Le tri **z-on-y** (un sprite plus bas à l'écran = plus proche = dessiné au-dessus)
est obtenu en mettant `sprite.z = pos.y` : voir les particules (§7) qui font
`self.sprite.z = (self.z_override or self.sprite.pos.y) + self.z_offset`.

### 3.6 Le sprite : quad d'atlas centré, flip, offset tourné

Le `draw` d'un sprite (verbatim, simplifié des branches stencil) montre la
convention : **origine au centre du frame**, scale = taille/framesize × flip,
offset tourné par la rotation avant ajout :

```lua
_sprite_draw_quad:setViewport(
	frame.x * framesize.x, frame.y * framesize.y,
	framesize.x, framesize.y, self.texture:getDimensions())

local scale_x = (size.x / framesize.x) * self.scale.x * (self.x_flipped and -1 or 1)
local scale_y = (size.y / framesize.y) * self.scale.y * (self.y_flipped and -1 or 1)

local transformed_offset = self.offset:pooled_copy()
	:vector_mul_inplace(self.scale):rotate_inplace(rot)
pos:vector_add_inplace(transformed_offset); transformed_offset:release()

love.graphics.setColor(self.colour[1], self.colour[2], self.colour[3], self.colour[4] or self.alpha)
love.graphics.setBlendMode(self.blend, self.alpha_blend)
love.graphics.draw(self.texture, _sprite_draw_quad, pos.x, pos.y, rot,
	scale_x, scale_y, 0.5 * framesize.x, 0.5 * framesize.y, 0, 0)
```

Tout passe par des `vec2` poolés (`:pooled_copy()` / `:release()`) : zéro
allocation dans la boucle de rendu, donc pas de pics GC.

---

## 4. Shaders

Arco n'a **aucun fichier `.glsl`/`.fs`** : ses 6 shaders sont des chaînes GLSL
**inline** dans `src/shaders.lua`, compilées au chargement du module via
`lg.newShader([[ … ]])`. Convention LÖVE 11 : la fonction d'entrée est
`vec4 effect(vec4 c, Image t, vec2 uv, vec2 px)` (couleur sommet, texture,
coord. texture, coord. pixel écran). Les voici **tous, intégralement**.

### 4.1 `discard_alpha` — découpe nette du pixel-art

```glsl
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	c = c * Texel(t, uv);
	if (c.a == 0.0) {
		discard;
	}
	return c;
}
```

Rôle : rejeter (`discard`) les pixels totalement transparents au lieu de les
blender. Utile quand on écrit dans un canvas avec stencil/depth : un pixel
transparent ne laisse aucune trace. Indispensable pour des sprites pixel-art
empilés où l'on veut un test "tout ou rien".

### 4.2 `just_outline_shader` / `add_outline_shader` — contour 1px

Détection de bord par comparaison de l'alpha avec les 4 voisins (haut/bas/
gauche/droite à ±1 texel). `just_outline` ne renvoie **que** le liseré ;
`add_outline` compose le liseré **par-dessus** la texture d'origine.

```glsl
// just_outline_shader
uniform vec2 res;
uniform vec4 col;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec2 invres = vec2(1.0) / res;
	float a_here  = Texel(t, uv).a;
	float a_up    = Texel(t, uv + vec2(0.0, -1.0) * invres).a;
	float a_down  = Texel(t, uv + vec2(0.0,  1.0) * invres).a;
	float a_left  = Texel(t, uv + vec2(-1.0, 0.0) * invres).a;
	float a_right = Texel(t, uv + vec2( 1.0, 0.0) * invres).a;
	float a_neighbour = max(max(a_up, a_down), max(a_left, a_right));
	vec4 o = vec4(vec3(1.0), (a_here == 0.0 && a_neighbour == 1.0) ? 1.0 : 0.0);
	return col * o;
}
```

```glsl
// add_outline_shader — même détection, mais on garde la texture dessous
uniform vec2 res;
uniform vec4 col;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec2 invres = vec2(1.0) / res;
	vec4 t_here = Texel(t, uv);
	float a_here  = t_here.a;
	float a_up    = Texel(t, uv + vec2(0.0, -1.0) * invres).a;
	float a_down  = Texel(t, uv + vec2(0.0,  1.0) * invres).a;
	float a_left  = Texel(t, uv + vec2(-1.0, 0.0) * invres).a;
	float a_right = Texel(t, uv + vec2( 1.0, 0.0) * invres).a;
	float a_neighbour = max(max(a_up, a_down), max(a_left, a_right));
	vec4 o = vec4(col.rgb, (a_here == 0.0 && a_neighbour == 1.0) ? col.a : 0.0);
	return vec4(mix(t_here.rgb, o.rgb, o.a), max(o.a, t_here.a));
}
```

**Application** : ces shaders ont besoin de connaître la taille de la texture
(`res`) pour que `invres` vaille bien 1 texel. On les utilise typiquement pour
mettre en surbrillance une unité survolée ou ciblable. Le `sprite_system` envoie
les uniforms par sprite via `s.shader` + `s.shader_uniforms` :

```lua
-- dans sprite_system:_draw_execute()
love.graphics.setShader(shader)
if s.shader_uniforms and shader then
	for _, v in ipairs(s.shader_uniforms) do shader:send(v[1], v[2]) end
end
```

**Comment reproduire dans The Pit** : pour un liseré de carte/monstre ciblé,
binder `add_outline_shader`, `:send("res", {tex:getWidth(), tex:getHeight()})`,
`:send("col", {r,g,b,a})`, dessiner le sprite. Pour un halo derrière, deux passes
`just_outline` à offset ±1px en couleur sombre.

### 4.3 `ignore_white_shader` — clé chroma blanche

```glsl
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec4 p = Texel(t, uv);
	if (p.rgb == vec3(1.0, 1.0, 1.0)) {
		p.a = 0.0;
	}
	return c * p;
}
```

Rend transparent tout pixel blanc pur (color-key). Pratique pour réutiliser des
textures "masque" autorées sur fond blanc.

### 4.4 `grey_shader` — désaturation pondérée

```glsl
uniform float amount;
vec3 factors = vec3(0.3, 0.59, 0.11);   // luminance perçue
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec4 p = Texel(t, uv);
	vec3 g = p.rgb * factors;
	float grey = (g.r + g.g + g.b);
	return mix(p, vec4(grey, grey, grey, p.a), amount);
}
```

`amount` interpole couleur ↔ niveaux de gris (facteurs de luminance standard).
Initialisé à 1 au chargement (`shaders.grey_shader:send("amount", 1)`). Usage :
griser le monde pendant une pause, un menu, un état "mort/KO". Combat l'envoie sur
un `grey_canvas` dédié.

### 4.5 `colour_flash` — flash de teinte (hit feedback)

```glsl
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec4 p = Texel(t, uv);
	p.rgb = mix(p.rgb, c.rgb, c.a);   // c = couleur sommet : rgb = teinte, a = force
	return p;
}
```

Le shader le plus simple et le plus rentable : il **teinte** la texture vers la
couleur du sommet (`setColor`) proportionnellement à l'alpha de cette couleur. En
pratique : sur impact, on dessine l'unité avec ce shader et `setColor(1,1,1,k)`
(blanc) où `k` décroît de 1→0 → le classique "white flash" de hit. Aucune
uniform à envoyer, on pilote tout par `setColor`.

**Comment reproduire** : sur un coup reçu, lancer un petit tween `k:1→0` (via
`graphics_lerp` ou un timer) et dessiner le sprite touché avec `colour_flash` +
`lg.setColor(1,1,1,k)`.

### 4.6 `night_shader` (+ helpers) — nuit teintée et lumières additives

Le plus riche. Il transforme une frame "jour" en "nuit" (désaturation + boost
froid + assombrissement), puis **rajoute la lumière** depuis un canvas de lumières
pré-rendu. GLSL complet :

```glsl
uniform float amount;
uniform float light_amount;
uniform float light_add_amount;
uniform Image light;

vec3 boost = vec3(1.1, 1.0, 1.4);  // teinte la nuit vers le bleu
float grey_amount = 0.65;          // quantité de désaturation
float scale_amount = 0.30;         // assombrissement global
vec3 factors = vec3(0.3, 0.59, 0.11);

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	c = Texel(t, uv);
	if (amount == 0.0) { return c; }
	vec4 night_c = c;
	vec3 scaled = (night_c.rgb * factors);
	float grey = (scaled.r + scaled.g + scaled.b);
	night_c.rgb = mix(night_c.rgb, vec3(grey), grey_amount) * boost * scale_amount;

	// "dé-nuiter" localement là où il y a de la lumière, puis ajouter la lumière
	vec4 l = Texel(light, uv);
	night_c.rgb = mix(night_c.rgb, c.rgb, l.rgb * light_amount) + l.rgb * light_add_amount;

	return mix(c, night_c, amount);
}
```

Le **canvas de lumières** est construit à part : chaque source dessine 3 cercles
concentriques additifs (blend `lighten`, premultiplié) pour un dégradé doux. Code
Lua d'orchestration (`shaders.night_shader_functions`) :

```lua
draw_lights = function(self, lights)
	lg.push("all")
	lg.setCanvas(self.light_canvas)
	lg.clear(0,0,0,0)
	for _, v in ipairs(lights) do
		local pos, light, radius = table.unpack3(v)
		local lr, lg_, lb = light, light, light
		if type(light) == "table" then lr, lg_, lb = table.unpack3(light) end
		radius = radius or 50
		local x, y = pos:unpack()
		for _, layer in ipairs({ {0.3, radius}, {0.6, radius/1.8}, {1, radius/2} }) do
			local a, r = table.unpack2(layer)
			lg.setColor(lr*a, lg_*a, lb*a, 1)
			lg.setBlendMode("lighten", "premultiplied")
			lg.circle("fill", x, y, r)
		end
	end
	lg.pop()
end,
finalise = function(self)
	lg.push("all")
	lg.setShader(self.night_shader)
	self.night_shader:send("light_amount", 1)
	self.night_shader:send("light_add_amount", 0.2)
	self.night_shader:send("light", self.light_canvas)
	lg.setBlendMode("alpha", "premultiplied")
	lg.draw(self.night_canvas)         -- applique la nuit + lumières en une passe
	self.night_shader:send("light_amount", 0) -- éteint pour le rendu de carte ensuite
	self.night_shader:send("light_add_amount", 0)
	lg.pop()
end,
```

Pipeline (vu dans `src/states/game.lua`) : `start()` redirige le monde sur
`night_canvas`, le combat collecte toutes les entités taguées `night_light`
(position, couleur, rayon), `draw_lights()` peuple `light_canvas`, `finalise()`
recompose. Les lumières sont **data-driven par composant** : une torche est juste
une entité avec un composant `night_light = {colour, radius}`.

### 4.7 `void_shader` — réflexions "miroir noir"

Effet signature de la zone "Void" : le sol réfléchit les entités. Le shader
échantillonne une `reflection_texture` (les entités redessinées à l'envers) en
espace caméra :

```glsl
uniform Image reflection_texture;
uniform vec2 display_dimensions;
uniform float display_scale;
uniform float time;
uniform vec2 camera_pos;
uniform vec2 camera_delta;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	c = Texel(t, uv);
	if (c.a < 1.0) { return vec4(0.0); }
	px /= display_scale;
	px -= camera_delta;
	px += camera_pos;
	vec2 puv = (px - camera_pos) * display_scale / display_dimensions;
	return Texel(reflection_texture, puv);
}
```

Côté Lua, `apply_void_reflections(entities)` re-dessine chaque entité **miroir**
(rotation +π autour de la position, `scale.y` inversé, couleur grisée) dans un
canvas, que le shader vient lire :

```lua
s.colour = {0.3,0.3,0.3,1.0}
s.rot = -s.rot
s.pos:rotate_around_inplace(math.pi, pos)  -- bascule sous les pieds
s.scale:smuli(1, -1)                        -- flip vertical
s:draw()
```

C'est l'illustration parfaite du **canvas comme texture d'entrée d'un shader** :
rendre une "scène secondaire" (le reflet) hors écran, puis l'échantillonner.

### 4.8 Tableau récapitulatif des shaders

| Shader | Uniforms | Rôle | Réutilisable pour The Pit |
|--------|----------|------|---------------------------|
| `discard_alpha` | — | rejette les pixels α=0 | masque net en rendu canvas/stencil |
| `just_outline_shader` | `res`, `col` | liseré 1px seul | halo de surbrillance ciblage |
| `add_outline_shader` | `res`, `col` | liseré 1px sur la texture | contour de carte/monstre survolé |
| `ignore_white_shader` | — | color-key blanc | réutiliser des masques fond blanc |
| `grey_shader` | `amount` | désaturation pondérée | pause / KO / écran de menu |
| `colour_flash` | (via `setColor`) | flash de teinte | **white-flash de hit** |
| `night_shader` | `amount`, `light*`, `light` | nuit + lumières additives | ambiance jour/nuit, torches data-driven |
| `void_shader` | `reflection_texture`, caméra… | réflexions sol | effets de sol "miroir" spéciaux |

---

## 5. Animation & game feel

Arco découple proprement **trois couches de mouvement** : (a) les courbes
d'easing pures (`batteries/mathx`), (b) un moteur de tween graphique empilable
(`graphics_lerp`), (c) les effets caméra/temps globaux (screenshake, hitstop,
overlay). Plus l'animation frame-par-frame de l'ECS (`animation_system`).

### 5.1 Les courbes d'easing (`lib/batteries/mathx.lua`)

Toutes les courbes prennent un facteur `f ∈ [0,1]` et renvoient un facteur remappé.
Verbatim :

```lua
function mathx.identity(f)    return f end
function mathx.smoothstep(f)  return f * f * (3 - 2 * f) end
function mathx.smootherstep(f) return f * f * f * (f * (f * 6 - 15) + 10) end
function mathx.pingpong(f)    return 1 - math.abs(1 - (f * 2) % 2) end
function mathx.ease_in(f)     return f * f end                       -- quadratique
function mathx.ease_out(f)    local o = (1 - f); return 1 - o * o end
function mathx.ease_inout(f)
	if f < 0.5 then return f * f * 2 end
	local o = (1 - f); return 1 - 2 * o * o
end
```

Plus les briques de base utilisées partout : `math.lerp(a,b,t)`,
`math.clamp01(v)`, `math.remap_range_clamped(v, in0,in1, out0,out1)`,
`math.random_lerp(min,max)` (aléatoire dans un intervalle, seedé). On retrouve ces
courbes passées **en argument** aux tweens : `math.smoothstep`, `math.ease_out`…

### 5.2 `graphics_lerp` — le moteur de juice empilable (`src/graphics_lerp.lua`)

C'est **la pièce maîtresse à voler**. Un `graphics_lerp` accumule une file de
tweens sur trois canaux (`offset` vec2, `scale` vec2, `angle` float), chacun avec
sa courbe, et expose un `push()`/`pop()` qui applique la transform LÖVE
correspondante. On l'attache à n'importe quel élément dessiné (curseur, carte,
bouton) pour lui donner du mouvement.

Cœur du système :

```lua
function graphics_lerp:add_lerp(time, wait, args, f)
	if wait == nil or wait == true then wait = table.back(self.lerps) end -- chaînage auto
	local lerp = { time=time, timer=0, factor=0, args=args, f=f, wait=wait }
	table.insert(self.lerps, lerp)
	return lerp
end

function graphics_lerp:lerp_scale(time, wait, target, curve)
	local from_scale = (wait and self.last_scale or self.scale):copy()
	self.last_scale:vset(target)
	return self:add_lerp(time, wait, { from_scale=from_scale, to_scale=target,
		curve = curve or math.identity }, function(self, factor, args)
		self.scale:vset(args.from_scale):lerpi(args.to_scale, args.curve(factor))
	end)
end  -- (lerp_offset / lerp_angle suivent le même patron)

function graphics_lerp:update(dt)
	local to_remove = {}
	for i, v in ipairs(self.lerps) do
		local needs_wait = v.wait and v.wait.factor < 1   -- attend la fin du précédent
		if not needs_wait then
			v.timer = v.timer + dt
			v.factor = math.clamp01(v.timer / v.time)
			v.f(self, v.factor, v.args)
			if v.factor == 1 then table.insert(to_remove, v) end
		end
	end
	for _, v in ipairs(to_remove) do table.remove_value(self.lerps, v) end
end

function graphics_lerp:push()
	lg.push()
	lg.translate(self.offset:unpack())
	local has_origin = self.origin:length_squared() > 0
	if has_origin then lg.translate(self.origin:unpack()) end
	lg.scale(self.scale:unpack())
	lg.rotate(self.angle)
	if has_origin and self.scale.x ~= 0 and self.scale.y ~= 0 then
		lg.translate(-self.origin.x, -self.origin.y)
	end
	return self
end
```

Le **chaînage par `wait`** est l'idée maline : `wait=true` fait démarrer un tween
seulement quand le précédent est fini (`factor==1`), ce qui permet de scripter
des séquences lisibles. Les presets prêts à l'emploi en disent long sur la grammaire
de feel du jeu :

```lua
function graphics_lerp:bounce_in(total_time, scale)
	total_time, scale = total_time or 0.1, scale or 1.2
	self:lerp_offset(total_time * 0.0, false, vec2(0, 1), math.identity)  -- pose initiale
	self:lerp_offset(total_time * 1.0, true,  vec2(0, 0), math.ease_out)  -- remonte
	self:lerp_scale (total_time * 0.0, false, vec2(0),      math.identity) -- part de 0
	self:lerp_scale (total_time * 0.3, true,  vec2(scale),  math.ease_out) -- overshoot
	self:lerp_scale (total_time * 0.7, true,  vec2(1),      math.smoothstep)-- retour à 1
	return self
end

function graphics_lerp:wiggle(total_time, distance)
	total_time, distance = total_time or 0.2, distance or 2
	self:lerp_offset(total_time * 0.3, true, vec2(0,  distance), math.ease_out)
	self:lerp_offset(total_time * 0.3, true, vec2(0, -distance), math.smoothstep)
	self:lerp_offset(total_time * 0.4, true, vec2(0, 0),        math.ease_in)
	self:lerp_scale (total_time * 0.3, true, vec2(1.2),         math.smoothstep)
	self:lerp_scale (total_time * 0.7, true, vec2(1),           math.smoothstep)
	return self
end

-- survol "vivant" sans état, juste à partir d'un temps de hover :
function graphics_lerp:hovered_wiggle(element)
	if element.hovered then
		local f = mathx.remap_range_clamped(element.hovered_time, 0, 0.2, 0, 1)
		lg.translate(0, -2 * f)
		lg.translate(0, f * math.sin(love.timer.getTime() * math.tau))
	end
	return self
end
```

Note l'**overshoot** systématique (`bounce_in` dépasse à 1.2 — et sa variante
`bounce_in_hard` à 1.5 — avant de revenir à 1) : c'est la signature d'un "pop"
satisfaisant. Et `dynamic_push()` met même à
jour le tween tout seul à partir de l'horloge murale (pratique pour un élément
dessiné hors boucle de scène, comme le curseur) :

```lua
function graphics_lerp:dynamic_push()
	local now = love.timer.getTime()
	local dt = now - (self._last_time or now)
	self._last_time = now
	self:update(dt * SPEEDUP_FACTOR)
	self:push()
	return self
end
```

### 5.3 Le curseur logiciel : application directe (`src/soft_cursor.lua`)

Le curseur d'Arco est un sprite logiciel (la souris système est cachée) qui **wiggle
au clic** via un `graphics_lerp`. C'est l'exemple minimal de feedback pointer-down :

```lua
function soft_cursor:clicked()
	local wiggle_time = 0.1
	self.glerp:clear()
	self.glerp:lerp_scale(wiggle_time * 0.3, true, vec2(1.2), math.smoothstep) -- gonfle
	self.glerp:lerp_scale(wiggle_time * 0.7, true, vec2(1),   math.smoothstep) -- dégonfle
end
-- au draw : self.glerp:dynamic_push(); self:draw_at(...); self.glerp:pop()
```

`soft_cursor:clicked()` est appelé depuis `love.mousepressed` dans `main.lua` —
**feedback immédiat au pointer-down**, exactement la règle UI de The Pit.

### 5.4 Screenshake (`src/screenshake.lua`, `lib/ferris/util/screenshake.lua`)

Secousse à **décroissance exponentielle** + clamp temporel. La version Arco ajoute
un réglage joueur (`screenshake:scale()` lu depuis la save, accessibilité). Verbatim :

```lua
function screenshake:new()
	self.amplitude = 0
	self.time = 1
	self.timer = 0
	self.decay_rate = 2  -- vitesse de décroissance
end
function screenshake:update(dt)
	self.timer = self.timer + dt
	self.amplitude = self.amplitude * math.exp(-self.decay_rate * dt) -- décroissance expo
end
function screenshake:amount()
	if self.time == 0 or self.timer > self.time then return 0 end
	return math.lerp(self.amplitude, 0, math.clamp01(self.timer / self.time))
end
local _av = vec2() -- caché pour éviter le GC
function screenshake:apply(camera_position)
	local am = self:amount()
	if am > 0 then
		_av:sset(love.math.random() * am, 0):rotatei(love.math.random() * math.tau)
		camera_position:vaddi(_av)   -- décale directement la position caméra ce frame
	end
end
function screenshake:trigger(amplitude, time)
	self.timer = 0
	self.time = time
	amplitude = amplitude * screenshake:scale()   -- réglage accessibilité
	self.amplitude = amplitude + love.math.random() * 0.1 * amplitude -- jitter d'amplitude
end
```

`apply()` est appelé sur `self.camera.pos` juste avant le rendu (`game.lua:3159`).
**Le shake module la position caméra, pas une transform à part** : il bénéficie
donc automatiquement de la double échelle et du culling.

Barème réel d'amplitudes (relevé dans `src/actions/*` et `src/entities/*`) — très
instructif pour calibrer :

| Événement | `trigger(ampl, temps)` |
|-----------|------------------------|
| Tir d'arme légère (gun/rifle/gatling) | `1.5, 0.1` |
| Coup de poing / petit impact | `2, 0.2` |
| Shotgun, saut atterri léger | `2, 0.2` |
| Mort d'un ennemi (sous gamepause) | `7, 0.6` ("très haut car la pause l'atténue") |
| Saut lourd / machine | `6–7, 0.25–1` |
| Boss / fin du monde | `8–10, 0.8–2` |

### 5.5 Hitstop / gamepause (`src/gamepause.lua`)

Le hitstop d'Arco **gèle la simulation** quelques frames sur impact (l'UI continue
de tourner). C'est minuscule mais c'est 50 % du "punch" :

```lua
function gamepause:update(dt)
	if self.paused then
		self.timer = self.timer - dt
		if self.timer <= 0 then self.paused = false; self.timer = 0 end
	end
end
function gamepause:pause(time)
	self.paused = true
	time = time * gamepause:scale()        -- réglage joueur
	time = math.max(self.timer, time)      -- ne raccourcit jamais une pause en cours
	self.pause_duration = time
	self.timer = time
end
```

Côté combat (`game.lua`), la sim n'avance **que si non-pausée** :

```lua
self.gamepause:update(dt)
if not self.gamepause:is_paused() then
	-- ... avance physics / behaviours / animation du monde ...
end
```

Durées réelles (toujours en **frames/60**, donc indépendant du framerate) :

| Événement | `gamepause:pause(time)` |
|-----------|--------------------------|
| Impact d'arme | `3/60` (~50 ms) |
| Gros coup joueur | `4/60` |
| Coup critique / exécution | `12/60`, `20/60` |

Le combo gagnant d'Arco sur un coup fort : `gamepause:pause(4/60)` **+**
`screenshake:trigger(5, 0.5)` **+** white-flash `colour_flash` **+** particules de
sang (§7) **+** SFX `damage_variation` (§8) — tout déclenché au même tick.

### 5.6 Anticipation & impact via animation frame-par-frame

L'`animation_system` (`lib/ferris/ecs/systems/animation_system.lua`) pilote les
sprites multi-frames. Une animation a un `fps`, des `frames` (paires `{x,y}` dans
l'atlas), et un `loops` qui peut être **une chaîne = animation de continuation** :

```lua
function animation:update(dt)
	local anim = self.anim
	if not anim then return end
	self.time = self.time + dt
	if self.time > anim.time then
		self.time = self.time - anim.time
		self.frame = self.frame + 1
		if self.frame > #anim.frames then
			self.finished = true
			if anim.loops then
				self.frame = 1
				if type(anim.loops) == "string" then self:set_anim(anim.loops) end -- enchaîne
			end
		end
		self:_set_frame()
	end
end
```

Le pattern d'attaque (anticipation → frappe → récupération) est exprimé comme une
suite d'animations qui se passent le relais via `loops = "nom_suivant"`, et les
"planners"/"actions" de `src/actions/` synchronisent l'impact (dégâts + shake +
hitstop + particule) sur la **frame clé** de la frappe. Exemple d'enchaînement
typique relevé : un saut joue `jump` (montée) → frappe → `screenshake:trigger(6,
0.25)` + `particles.jump_attack` + `gamepause` à l'atterrissage.

---

## 6. UI / UX

L'UI d'Arco vit sur un **kernel séparé** (`ui_k`) et son **canvas séparé**
(`ui_frame`, §3.4), donc elle échappe à la caméra, au shake et aux shaders de
monde. Les textes passent par un `text_system`, les panneaux par du 9-slice, le
feedback par `graphics_lerp`, les transitions de scène par `screen_transition`.

### 6.1 9-slice (`src/9slice.lua`) — recopié et expliqué

Le 9-slice étire une texture bordée (panneau, bouton, infobulle) à n'importe
quelle taille en gardant les coins intacts et en **tuilant** (pas en étirant) les
bords et le centre. Un seul `Quad` réutilisé, zéro allocation. Verbatim intégral :

```lua
-- 9slice rendering
local q = lg.newQuad(0,0,0,0,1,1)
return function(texture, border, pos, size)
	q:setViewport(0,0,0,0,texture:getDimensions())
	local tsize = vec2(texture:getDimensions())
	local inner_size   = size:fma(border, -2)   -- zone intérieure cible (size - 2*border)
	local inner_bounds = tsize:fma(border, -2)  -- zone intérieure source (texture - 2*border)
	--corners (taille fixe = border)
	q:setViewport(0, 0, border.x, border.y)
	lg.draw(texture, q, pos.x, pos.y)                                   -- topleft
	q:setViewport(tsize.x - border.x, 0, border.x, border.y)
	lg.draw(texture, q, pos.x + size.x - border.x, pos.y)               -- topright
	q:setViewport(0, tsize.y - border.y, border.x, border.y)
	lg.draw(texture, q, pos.x, pos.y + size.y - border.y)              -- bottomleft
	q:setViewport(tsize.x - border.x, tsize.y - border.y, border.x, border.y)
	lg.draw(texture, q, pos.x + size.x - border.x, pos.y + size.y - border.y) -- bottomright
	--sides (tuilés le long de inner_bounds)
	for sx = 0, inner_size.x, inner_bounds.x do
		local w = math.min(inner_bounds.x, inner_size.x - sx)
		q:setViewport(border.x, 0, w, border.y)                         -- top
		lg.draw(texture, q, pos.x + border.x + sx, pos.y)
		q:setViewport(border.x, tsize.y - border.y, w, border.y)        -- bottom
		lg.draw(texture, q, pos.x + border.x + sx, pos.y + size.y - border.y)
	end
	for sy = 0, inner_size.y, inner_bounds.y do
		local h = math.min(inner_bounds.y, inner_size.y - sy)
		q:setViewport(0, border.y, border.x, h)                         -- left
		lg.draw(texture, q, pos.x, pos.y + border.y + sy)
		q:setViewport(tsize.x - border.x, border.y, border.x, h)        -- right
		lg.draw(texture, q, pos.x + size.x - border.x, pos.y + border.y + sy)
	end
	--center (tuilé en grille)
	for sx = 0, inner_size.x, inner_bounds.x do
		local w = math.min(inner_bounds.x, inner_size.x - sx)
		for sy = 0, inner_size.y, inner_bounds.y do
			local h = math.min(inner_bounds.y, inner_size.y - sy)
			q:setViewport(border.x, border.y, w, h)
			lg.draw(texture, q, pos.x + border.x + sx, pos.y + border.y + sy)
		end
	end
end
```

Détails qui comptent :
- **`border` est un `vec2`** : bord horizontal et vertical indépendants.
- Les bords et le centre sont **tuilés** par boucle `for … step inner_bounds`
  avec un `math.min` pour le dernier morceau partiel. Conséquence : une texture
  de bord avec un motif (rivets, gravure de pierre) se **répète** proprement au
  lieu d'être étirée et floue. C'est exactement ce qu'il faut pour le style
  "pierre gravée / runes" de The Pit.
- Un seul `Quad` module-local réutilisé pour tous les appels.

**Comment reproduire** : `nineslice(panel_tex, vec2(8,8), vec2(x,y), vec2(w,h))`.
Pour un panneau dont le centre doit être **étiré** (et non tuilé), il suffit de
fournir une texture dont la bande centrale fait 1px.

### 6.2 Texte (`lib/ferris/ecs/systems/text_system.lua` + `display:print*`)

Deux voies coexistent :

1. **`text_system`** (ECS) : composant `text_component` qui possède un
   `love.graphics.newText` (texte mis en cache GPU), avec alignement h/v calculé
   par décalage de l'origine, et **arrondi au pixel** au draw :
   ```lua
   love.graphics.draw(self.text, math.floor(x), math.floor(y)) -- net, pas de demi-pixel
   ```
2. **Helpers `display`** pour le texte immédiat, dont deux primitives de lisibilité
   très utiles : ombre portée et **contour 8 directions** (purement CPU, par
   surimpression — pas de shader) :
   ```lua
   function display:print_shadowed(txt, x, y, w, align, shadow_offset, shadow_colour)
   	-- dessine le texte décalé en noir, puis par-dessus en couleur
   end
   local outline_macro = { {0xff000000, vec2(-1,0)}, {0xff000000, vec2(1,0)},
   	{0xff000000, vec2(0,-1)}, {0xff000000, vec2(0,1)},
   	-- + 4 diagonales normalisées, puis le remplissage couleur :
   	{0xffffffff, vec2(0,0)} }
   function display:print_outlined(txt, x, y, w, align, outline_offset)
   	-- imprime le texte 8 fois en noir autour, puis 1 fois au centre en couleur
   end
   ```

La police principale (`Silver.ttf`) est chargée en `nearest` avec un cache
multi-tailles/multi-faces/multi-langues (`display:get_font_raw`), et un système de
**fallbacks** par langue (cyrillique, CJK) — détail i18n mais qui montre que la
résolution de police suit le `print_scale` (donc le scale entier de la scène).

### 6.3 Feedback hover / click

- **Hover** : `graphics_lerp:hovered_wiggle(element)` (§5.2) anime n'importe quel
  élément qui expose `hovered` + `hovered_time` — léger soulèvement + oscillation
  sinusoïdale, **sans machine à états**, juste à partir du temps de survol remappé.
- **Click / pointer-down** : `soft_cursor:clicked()` (wiggle d'échelle) déclenché
  immédiatement dans `love.mousepressed`, et les éléments UI lancent un
  `bounce_in`/`wiggle` sur leur propre `graphics_lerp`. La règle est : **réaction
  visuelle au down, action possiblement résolue plus tard**.
- **Sons d'UI** : `audio:play_now("ui_select")`, `"ui_buzz"` (refus),
  `"ui_character_selection"`… déclenchés au même endroit que le feedback visuel
  (voir §8), sur le canal `ui`.

### 6.4 Transitions de scène (`src/screen_transition.lua`)

Transition signature : un **wipe diagonal** (cisaillement) avec une frange douce,
ou un fade, le tout piloté par une **machine à états** (`batteries/state_machine`)
à six états (`ready, wipe_out, fade_out, wait, wipe_in, fade_in`) ; un wipe
enchaîne `ready → wipe_out → wait → wipe_in → ready` (idem pour `fade_*`). Le
dessin du wipe :

```lua
local function _draw_wipe(f)
	local shear_amount = -0.5
	local w, h = display:dimensions()
	local tw = w * (1 + math.abs(shear_amount))
	local fringe_size = 100
	lg.push("all")
	lg.shear(shear_amount, 0)                     -- diagonale
	local a = math.clamp01((1 - math.abs(f)) * 2)
	lg.setColor(0, 0, 0, a)
	lg.rectangle("fill", f * tw, 0, tw, h)        -- bande noire qui balaie
	lg.setColor(0, 0, 0, a * 0.5)
	lg.rectangle("fill", f * tw - fringe_size, 0, tw + fringe_size * 2, h) -- frange douce
	lg.pop()
end
```

L'API est asynchrone à callbacks : `screen_transition:wipe_out(cb)` joue le balayage
puis appelle `cb` au moment "écran couvert" (état `wait`) — c'est **là** qu'on
change réellement de scène, puis `wipe_in` révèle la nouvelle. Le `screen_transition`
est dessiné **sur le canvas UI** (`display:start_ui()` avant `screen_transition:draw()`
dans `main.lua`) pour rester au-dessus de tout, monde comme HUD.

### 6.5 Overlay plein écran (`lib/ferris/util/screen_overlay.lua`)

Pour les **flashs et fondus de couleur** (dégâts, mort, éclair) : un overlay qui
interpole une couleur de `old_colour` vers `colour` sur un `timer`. `flash()` part
d'une couleur opaque et fond vers alpha 0 :

```lua
function screen_overlay:flash(colour, time)
	colour = self:_decode_colour(colour)
	self.colour = table.copy(colour); self.old_colour = table.copy(colour)
	colour[4] = 0            -- cible : transparent
	self:fade(colour, time)
end
function screen_overlay:current_colour()
	local r1,g1,b1,a1 = table.unpack4(self.old_colour)
	local r2,g2,b2,a2 = table.unpack4(self.colour)
	local t = self.timer:progress()
	return math.lerp(r1,r2,t), math.lerp(g1,g2,t), math.lerp(b1,b2,t), math.lerp(a1,a2,t)
end
```

Le combat possède son overlay (`self.overlay = ferris.screen_overlay()`) dessiné en
`order = 100` (tout en haut de l'UI), redimensionné chaque frame à la taille écran.

---

## 7. Particules & effets

**Arco n'utilise PAS `love.graphics.newParticleSystem`.** Toutes les particules
sont des **entités ECS** (sprite animé + behaviour d'intégration physique), ce qui
leur donne gratuitement le tri z-on-y, le culling, le batching par texture et la
destruction différée. Tout est dans `src/entities/particles.lua` (1055 lignes,
entièrement data-driven).

### 7.1 Anatomie d'une particule

Une particule = entité avec un `sprite`, une `animation`, et un behaviour
`particle` dont l'`update` intègre vitesse/accélération/friction puis **se détruit
à la fin de l'animation** :

```lua
local function particle_update(self, dt)
	self.vel:fmai(self.acc, dt)                          -- v += a*dt
	self.vel:apply_friction_xy_inplace(self.friction.x, self.friction.y, dt)
	if self.physics then
		self.vel:vmuli(self.physics.inv_world_scale)
		self.sprite.pos:fmai(self.vel, dt)               -- p += v*dt (espace monde)
		self.vel:vmuli(self.physics.world_scale)
	else
		self.sprite.pos:fmai(self.vel, dt)
	end
	self.sprite.z = (self.z_override or self.sprite.pos.y) + self.z_offset  -- z-on-y
	self.tick = self.tick + 1
	if self.animation:done() and not self.entity._destroyed then
		self.entity:destroy()                            -- meurt à la fin de l'anim
	end
end
```

L'usine `particles.core(systems, config)` assemble le sprite (texture + `layout`
de l'atlas), génère les frames (`animation:generate_frames_ordered_1d`), choisit un
`fps` **aléatoire dans un intervalle** (`fps = {8,15}` → variété), et branche
éventuellement un behaviour `bounce` secondaire (rebond + spin) :

```lua
local fps = type(config.fps) == "table"
	and math.lerp(config.fps[1], config.fps[2], love.math.random())
	or config.fps
```

### 7.2 Configs data-driven & collections

Tous les types de particules sont déclarés dans des **tables**, mappées sur les
lignes d'un même atlas (`assets/entities/particles/particles.png`, layout 11×42),
et regroupés en **collections** dans lesquelles on pioche au hasard :

```lua
local particle_core_common = {
	sprite_size = vec2(16),
	sprite_layout = vec2(11, 42),
	sprite_texture = arco_newImage("assets/entities/particles/particles.png"),
}
-- déclaration : nom, nb de frames, fps, collection
{"blood_dark",  { frame_count = 5, fps = {8, 15}, collection = "blood" }},
{"blood_light", { frame_count = 5, fps = {8, 15}, collection = "blood" }},
{"dust_med_1",  { frame_count = 7, fps = {8, 10}, collection = "dust"  }},
{"explosion_circle_fire", { frame_count = 7, fps = {8, 15}, collection = "explosion" }},
{"gun_smoke_1", { frame_count = 7, fps = {8, 12}, collection = "gun_smoke" }},
```

On instancie ensuite par **nom** ou en **piochant dans une collection** :

```lua
function particles.create_named(systems, config_name, config)
	table.overlay(config, particles.configs[config_name]); return particles.core(systems, config)
end
function particles.create_from_collection(systems, collection_name, config)
	local cfg = table.pick_random(particles.collections[collection_name])
	table.overlay(config, cfg); return particles.core(systems, config)
end
```

### 7.3 "Splash" : gerbes de particules avec dispersion

Le helper `splash` instancie `count` particules avec **dispersion de position et
de vitesse** (échantillonnage disque uniforme via `sqrt(random)`), base de tous
les effets d'éclaboussure :

```lua
function particles.splash(systems, splash_config, particle_config)
	for i = 1, splash_config.count or 1 do
		local pos = splash_config.pos:copy()
		if splash_config.pos_spread then
			local offset = vec2:pooled()
				:sset(0, math.sqrt(love.math.random()) * splash_config.pos_spread)
				:rotatei(love.math.random() * math.tau)
			pos:vaddi(offset); offset:release()
		end
		local vel = vec2(splash_config.vel)
		if splash_config.vel_spread then
			vel:saddi(mathx.rotate(0, math.sqrt(love.math.random()) * splash_config.vel_spread,
				love.math.random() * math.tau))
		end
		table.overlay(particle_config, { pos=pos, vel=vel, acc=splash_config.acc,
			z_override = splash_config.z_override })
		particles.core(systems, particle_config)
	end
end
```

Le sang met tout bout à bout — une **éclaboussure animée** + une **tache au sol
persistante** (map_debris) dont la frame dépend de la magnitude :

```lua
function particles.blood_splat(systems, pos, count, supress_fleck)
	if not supress_fleck then particles.blood_fleck(systems, pos:vmul(WORLD_SCALE), count/20) end
	particles.splash_from_collection(systems, "blood", {
		count = count or 5, pos = pos, pos_spread = 4,
		vel = vec2(0, -30), vel_spread = 40,           -- gicle vers le haut
	}, { acc = vec2(0, 40), z_offset = particles.blood_offset }) -- retombe (gravité)
end
```

### 7.4 Effets "always animate" (couche au-dessus, animée même en pause-plan)

Certains effets (cast de sort, buff reçu, téléport, poison, stun) doivent
continuer à s'animer même pendant la **phase de planification** où la sim du monde
est figée. Arco les route vers des systèmes "always" et un système de sprite
d'overlay dédié :

```lua
function particles.always_animate(systems, config)
	systems = {
		animation = systems.animation_always or systems.animation,
		behaviour = systems.behaviour_always or systems.behaviour,
		sprite    = systems.overlay_sprite   or systems.sprite,
	}
	return particles.core(systems, config)
end
```

Chaque effet "scénarisé" (cast, jump_fx, stab, spin_attack, teleport, stun…) est
un petit bloc `do … end` qui charge son atlas, déduit le layout
(`vec2(tex:getDimensions()):vdivi(size)`) et expose une fonction
`particles.<nom>(systems, pos[, dir])`. Exemple du stab (orienté par direction) :

```lua
do
	local texture = arco_newImage("assets/entities/particles/melee_fx/stab_01.png")
	local size = vec2(32, 32)
	local layout = vec2(texture:getDimensions()):vdivi(size)
	particles.configs.stab = { sprite_size=size, sprite_layout=layout, sprite_texture=texture,
		frame_start=vec2(0,0), frame_count=layout.x, fps={15,25}, offset=vec2(16,16), z_offset=1 }
	function particles.stab(systems, pos, dir)
		return particles.core(systems, table.overlay({
			pos = pos:vadd(particles.configs.stab.offset:vector_mul(dir)),
			dir = dir,                                   -- oriente le sprite : sprite.rot = dir:angle()
		}, particles.configs.stab))
	end
end
```

### 7.5 Parallaxe (`src/journey/layer_config.lua`, `src/entities/parallax_sprite.lua`)

Le décor d'exploration ("journey") est un **empilement de couches data-driven**.
Chaque biome est une liste de couches `{z, factor, y, x_offset, assets/backgrounds}`
où **`factor` est le coefficient de parallaxe** (1 = collé à la caméra, 0.25 =
lointain, **valeurs négatives = premier plan qui dépasse la caméra**). Extrait du
désert :

```lua
layer_config.biome.desert = {
	{ z=10, y=55, factor=1,    single_sprite=true,  backgrounds = { arco_newImage(".../sky/sky.png") } },
	{ z=20, y=-10, factor=0.925, assets = { ... horizon3_1..3.png, spacing = {0.5,1} } },
	{ z=40, y=-10, factor=0.85,  assets = { ... dune_horizon1_1..7.png, spacing = {0.3,0.5} } },
	{ z=60, y=-6,  factor=0.55,  assets = { ... dune_bg2_1..5.png } },
	{ z=70, y=-6,  factor=0.25,  assets = { ... dune_bg1_1..4.png } },
	{ z=100, y=60, factor=0.90,  assets = { ... sky/frontgradient.png } }, -- voile de premier plan
}
```

Le rendu d'une couche est une **entité parallaxe** minimaliste : un sprite dont
l'`offset` est recalculé chaque frame en multipliant la position caméra par
`factor` (`src/entities/parallax_sprite.lua`, verbatim intégral) :

```lua
local function update_parallax(self, dt)
	local delta = self.cam.pos:pooled_copy()
		:scalar_mul_inplace(self.fac)
		:scalar_mul_inplace(self.sprite.x_flipped and -1 or 1, 1)
	self.sprite.offset:vset(delta)
	delta:release()
end
return function(systems, args)
	local asset = args.asset
	if not asset then return nil end
	local e = ferris.entity(systems)
	local s = e:add_component("sprite", "sprite", {
		texture = asset, size = vec2(asset:getDimensions()),
		pos = vec2(args.pos), z = args.z, x_flipped = args.flip })
	e:add_component("behaviour", "parallax_thing", {
		sprite = s, cam = args.camera, fac = args.parallax_factor, update = update_parallax })
	return e
end
```

Donc : **`offset = camera.pos * factor`**. Une couche à `factor=1` se déplace avec
la caméra (immobile à l'écran = ciel) ; `factor=0.25` traîne (lointain) ;
`factor<0` part dans l'autre sens (premier plan exagéré). Le `z` ordonne les
couches dans le même `sprite_system` que les entités gameplay, et les listes
`assets` portent un `spacing` pour disperser/répéter les éléments le long de
l'horizon. Plus de **30 biomes** (désert, deepdesert, saltpan, drylands jour/nuit/
aube, red_desert…) sont définis purement en données dans ce fichier de ~4700 lignes.

---

## 8. Audio (feedback)

Tout l'audio tient dans `src/audio/init.lua` (~9300 lignes, mais surtout des
**données**). Le moteur réel fait ~200 lignes. La philosophie : **un son n'est
jamais joué brut**, il passe par un canal de mix + une "variation" (pitch/volume/
offset aléatoires) + une priorité, ce qui suffit à rendre un même sample vivant.

### 8.1 Canaux de mix

Cinq canaux hiérarchiques avec volumes persistés dans la save (réglages joueur) :

```lua
local default_mix_channels = {
	master  = { volume = 0.9 },   -- headroom pour le mixage
	music   = { volume = 0.8 },
	ambient = { volume = 0.3 },
	sfx     = { volume = 0.9 },
	ui      = { volume = 1.0 },
}
```

Chaque son déclare son canal et un multiplicateur : `mix = {"sfx", 0.7}`. Le
volume effectif = `mix_channel.volume * extra_volume` (`audio:_get_config_volume`).

### 8.2 Variations — le secret de la vivacité

Une "variation" randomise pitch, volume et point de départ. Profils typés (gun,
footstep, damage, general, dialogue) :

```lua
local gun_variation = {
	pitch  = {0.8, 1.2},   -- 0.5 = octave bas, 2 = octave haut
	volume = {0.9, 1.00},
	offset = {0.0, 0.0},
	effects = true,        -- autorise reverb/echo selon la zone
	priority = audio.priority_high,
}
local footstep_variation = { pitch = {0.7, 1.3}, volume = {0.8, 0.9}, ... priority = priority_low }
local damage_variation   = { pitch = {0.7, 1.3}, volume = {0.9, 1.0}, ... priority = priority_high }
```

Application au moment du play (verbatim) :

```lua
function audio:apply_variation(cfg, source, variation)
	source:setPitch(math.random_lerp(table.unpack2(variation.pitch)))
	local volume = audio:_get_config_volume(cfg) * math.random_lerp(table.unpack2(variation.volume))
	source:setVolume(volume)
	local offset = math.random_lerp(table.unpack2(variation.offset))
	if offset > 0 then source:seek(offset * source:getDuration(), "seconds") end
	if variation.effects then self:apply_effects(source) end
end
```

**Le détail qui change tout** : un même bruit de pas joué avec
`pitch ∈ [0.7,1.3]` cesse d'être répétitif. C'est l'équivalent audio de l'`fps`
aléatoire des particules. Et les variantes numérotées (`player_footsteps_01..08`,
`stab_attack_01..04`) sont des **bundles** dans lesquels on pioche au hasard, en
plus de la variation de pitch.

### 8.3 Déclenchement sur événements

Le point d'entrée est `audio:play_now(filename, override_variation)` : il stoppe
la source partagée, applique la variation, gère le mono/relatif, joue, et
enregistre la priorité :

```lua
function audio:play_now(filename, override_variation)
	local cfg = self:get_config(filename)
	local s = cfg.source
	s:stop()
	self:apply_variation(cfg, s, override_variation or cfg.variation)
	if s:getChannelCount() == 1 then s:setRelative(true) end
	s:play()
	local priority = cfg.priority or (override_variation and override_variation.priority)
		or cfg.variation.priority
	if priority then self:add_prioritised_source(s, priority) end
	return s
end
```

Les events de gameplay l'appellent directement, **au même tick que le feedback
visuel** : `boss_moth_scream`, `boss_void_death`, `ui_select`, `ui_buzz` (refus),
`character_falling`, `dialogue_pop_up`… L'UI joue ses sons exactement où elle joue
ses tweens (§6.3) — visuel et son sont co-localisés dans le code.

### 8.4 Audio positionnel (clone par source)

Pour le son spatialisé, `play_positional` **clone** la source (afin de pouvoir en
jouer plusieurs simultanées), et mappe la position monde sur l'espace audio :

```lua
function audio:play_positional(filename, position, override_variation)
	local cfg = self:get_config(filename)
	local s = cfg.source:clone()           -- clone : plusieurs instances en vol
	s:stop(); self:apply_variation(cfg, s, override_variation or cfg.variation)
	self:set_positional(s, position); s:play()
	...
end
function audio:set_positional(source, position)
	if source:getChannelCount() == 1 then
		source:setPosition(position.x / position_scale, position.y / position_scale, position_distance_ahead)
		source:setRelative(false)
		source:setAttenuationDistances(position_distance_ahead, position_distance_ahead * 5)
		return true
	end
	return false
end
```

### 8.5 Plafond de voix par priorité

Pour ne pas saturer la carte son, Arco plafonne le nombre de sources prioritaires
simultanées (`max_prioritised_sources = 8`) et **évince la source la moins
prioritaire/la plus ancienne** quand c'est plein (`add_prioritised_source`).
Score d'éviction : `priority + time/1000` (priorité d'abord, ancienneté pour
départager). Une nuée d'ennemis qui tirent ne fera donc jamais "craquer" le mix.

### 8.6 Effets de zone

Des effets DSP LÖVE (`reverb`, `echo_void`, `flanger_void`) sont définis une fois
et **activés par zone** (`audio:set_effects(set)`), puis appliqués à la source si
sa variation a `effects = true`. La zone "Void" gagne ainsi son echo/flanger
caractéristique sans toucher au reste.

---

## 9. Ce qu'on vole pour The Pit

Arco et The Pit ne sont pas le même jeu (action temps réel vs autobattler
asynchrone), mais le **socle de présentation** est transposable presque tel quel.
Par ordre de rentabilité :

1. **La double échelle pixel-perfect (`display.lua`).** Rendre le monde/les cartes
   dans un canvas à un **scale entier** (`nearest`), puis poser ce canvas à
   l'écran avec un **scale fractionnaire** (`linear`) + letterbox centrée. On
   garde des pixels d'art nets sur n'importe quelle résolution sans imposer de
   fenêtre multiple. *Appliquer* : un module `display` avec `target_resolutions`,
   `scale` (entier) et `canvas_scale` (fractionnaire), deux canvas monde+UI.

2. **`graphics_lerp` — le moteur de juice empilable (`src/graphics_lerp.lua`).**
   Le plus gros gain. Un tween offset/scale/angle chaînable (`wait`), avec presets
   `bounce_in`/`wiggle`/`hovered_wiggle` et `dynamic_push`. *Appliquer* : attacher
   un `graphics_lerp` à chaque carte de monstre, bouton, chip de keyword ; lancer
   `bounce_in` à l'apparition, `wiggle` au clic, `hovered_wiggle` au survol.
   L'overshoot (passer par 1.2/1.5 avant 1) est ce qui rend le "pop" satisfaisant.

3. **Le combo d'impact : hitstop + shake + white-flash + particules + SFX, au même
   tick.** `gamepause:pause(4/60)` gèle la sim, `screenshake:trigger(5,0.5)` secoue
   la position caméra (décroissance expo), `colour_flash` blanchit le sprite touché
   (`setColor(1,1,1,k)`, k:1→0), `particles.blood_splat`, `play_now(damage)`.
   *Appliquer* : même si The Pit est asynchrone, un coup résolu en combat auto peut
   déclencher exactement ce paquet sur la frame de l'impact. Les barèmes d'Arco
   (§5.4/§5.5) sont un point de départ calibré.

4. **9-slice qui tuile (`src/9slice.lua`).** ~110 lignes, un seul `Quad`, bords et
   centre **tuilés** (pas étirés) → parfait pour le chrome "pierre gravée/runes".
   *Appliquer* : remplacer tout panneau dessiné "à la main" par
   `nineslice(tex, vec2(b), pos, size)`. Pour un centre lisse, bande centrale 1px.

5. **Particules = entités ECS data-driven, pas `ParticleSystem`
   (`src/entities/particles.lua`).** Atlas + `layout`, `fps` aléatoire dans un
   intervalle, configs en tables, **collections** où l'on pioche, helper `splash`
   avec dispersion disque uniforme (`sqrt(random)`). Bénéfice gratuit : tri z-on-y,
   culling, batching, destruction différée. *Appliquer* : une usine
   `particles.create_from_collection(systems, "impact", {pos=...})` pour les FX de
   combat, avec `z = pos.y + z_offset`.

6. **Le shader de teinte le plus rentable : `colour_flash`.** Aucune uniform,
   piloté par `setColor`. C'est le white-flash de hit en 4 lignes de GLSL.
   *Appliquer* : binder sur le sprite touché pendant un court tween d'alpha.
   Garder aussi `add_outline_shader` (liseré 1px, `res`+`col`) pour la
   surbrillance de ciblage/hover de carte.

7. **Lumières additives data-driven (`night_shader` + `draw_lights`).** Un canvas
   de lumières peuplé de cercles concentriques additifs (blend `lighten`), lu par
   un shader qui désature/assombrit puis ré-éclaire. Les sources sont de simples
   composants `{colour, radius}`. *Appliquer* : pour des ambiances de plateau
   (braseros, runes qui pulsent) sans coder chaque lumière en dur.

8. **Boucle à pas fixe + `dt` constant (`ferris/main_loop.lua`).** `love.update`
   reçoit toujours `1/60`, accumulateur clampé à 8 frames, "fuzzy snapping" du dt.
   Déterminisme et animations stables — ce que la frontière SIM de The Pit exige.
   *Appliquer* : redéfinir `love.run` sur ce modèle ; ne jamais passer le vrai dt
   à la sim.

9. **Transition d'écran à machine à états + callback "écran couvert"
   (`screen_transition.lua`).** Wipe diagonal (`lg.shear`) avec frange douce,
   dessiné sur le canvas UI. Le changement de scène réel se fait dans le callback
   `wait`. *Appliquer* : masquer les chargements/changements d'écran (build→combat
   →bilan) derrière un wipe, et faire la bascule d'état au moment couvert.

10. **Variations audio (pitch/volume aléatoires) + bundles numérotés
    (`audio/init.lua`).** `pitch ∈ [0.8,1.2]` + pioche dans `son_01..0N` tue la
    répétitivité ; canaux de mix persistés ; plafond de voix par priorité.
    *Appliquer* : un `audio:play(name, variation)` qui randomise pitch/volume, et
    des bundles pour les sons fréquents (hover, impact, pose de carte). Co-localiser
    l'appel son avec le feedback visuel.

**Méta-leçon Arco** : presque tout le "feel" vient de **données + petites courbes
réutilisables**, pas de code spécial par effet. Un `graphics_lerp`, un atlas de
particules en table, une variation audio, un shader de 4 lignes — composés au bon
tick — suffisent à faire un jeu qui respire. C'est exactement le budget que The
Pit peut se permettre.

