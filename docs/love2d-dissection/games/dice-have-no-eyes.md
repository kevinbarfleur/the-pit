# Dissection technique : *Dice Have No Eyes*

> Document de référence pour reproduire les techniques de rendu et de **juice** de
> *Dice Have No Eyes* (autobattler/roguelike de dés en LÖVE, réputé pour son feedback
> visuel extrême) dans un autre projet LÖVE — **sans accès au code source d'origine**.
>
> Toutes les sources sont citées par chemin relatif depuis la racine du jeu décompilé
> (`dice/`). Le code et le GLSL sont recopiés **verbatim**. La prose est en français ;
> les identifiants, chemins et shaders restent en version originale.
>
> Build étudié : `BUILD_ID = "Demo 2026.05.29 2ed8f1f"`, `t.version = "11.5"`.

---

## Table des matières

1. [Fiche technique](#1-fiche-technique)
2. [Architecture](#2-architecture)
3. [Pipeline de rendu & post-processing](#3-pipeline-de-rendu--post-processing)
4. [Shaders (catalogue complet)](#4-shaders-catalogue-complet)
5. [Game feel / juice](#5-game-feel--juice)
6. [UI / UX](#6-ui--ux)
7. [Particules](#7-particules)
8. [Audio (feedback)](#8-audio-feedback)
9. [Ce qu'on vole pour The Pit](#9-ce-quon-vole-pour-the-pit)

---

## 1. Fiche technique

### 1.1 Version LÖVE et configuration fenêtre

`conf.lua` (verbatim, l'essentiel) :

```lua
function love.conf(t)
	t.version = "11.5"
	t.identity = "dice_have_no_eyes"
	BUILD_ID = "Demo 2026.05.29 2ed8f1f"
	t.window.title = "Dice Have No Eyes "..BUILD_ID
	DEMO = true
	--"canon" size
	t.window.width = 960*2
	t.window.height = 540*2
	--support highdpi on mac
	t.window.highdpi = true
	local ffi = require("ffi")
	if ffi then
		if ffi.os == "Windows" then
			ffi.cdef[[
				int SetProcessDpiAwareness(int value);
			]]
			if not pcall(function()
				if ffi.C.SetProcessDpiAwareness(2) ~= 0 then
					if ffi.C.SetProcessDpiAwareness(1) ~= 0 then
						error()
					end
				end
			end) then
				print("missing or failed SetProcessDpiAwareness, running with system dpi settings")
			end
		end
	end
	if dev_build then
		t.console = true
		t.window.resizable = true
		t.window.fullscreen = "desktop"
		DEBUG = true
	else
		t.window.fullscreen = "desktop"
	end
end
```

Points notables :

- **Taille « canon » 1920×1080** (`960*2 × 540*2`). Le jeu raisonne en **demi-résolution
  logique 960×540** (voir §3) et n'opère qu'en plein écran *desktop*.
- **High-DPI activé** sur Mac (`t.window.highdpi`) et **forcé sur Windows** via un appel
  FFI direct à `SetProcessDpiAwareness` (essaie `PROCESS_PER_MONITOR_DPI_AWARE` = 2, puis
  `SYSTEM_DPI_AWARE` = 1). À reprendre tel quel si on veut un rendu net sur écrans HiDPI.

### 1.2 Résolution interne et scaling

La logique est centralisée dans `src/display.lua`. Cible unique :

```lua
display.target_resolutions = {
	{
		size = vec2(1920, 1080),
		scale = { normal = 2 },
	},
}
```

- Le jeu rend tout dans des **canvases de 1920×1080** (`self.width/height`), mais avec un
  facteur d'échelle logique `scale = 2`, donc la **résolution de dessin "scaled"** est
  `width_scaled, height_scaled = 960, 540`. Tout le gameplay/UI est positionné dans cet
  espace 960×540 ; le ×2 donne la finesse pixel.
- Le canvas final est ensuite **étiré (`canvas_scale`) pour remplir la fenêtre** en
  conservant le ratio, avec un offset de letterbox calculé dans `refresh_dimensions()`.
- Filtre global `nearest` (`main.lua` : `lg.setDefaultFilter("nearest", "nearest")`) pour
  un rendu pixel-art net, **mais les canvases plein écran sont passés en `linear`**
  (`screen_cv()` → `cv:setFilter("linear", "linear")`) pour que l'étirement final et les
  shaders d'aberration/bulge restent doux.

### 1.3 Bibliothèques et usage

Deux dépendances, chargées en tête de `main.lua` :

```lua
require("lib.batteries"):export()
soup = require("lib.soup")
```

| Lib | Rôle | Modules réellement utilisés ici |
|-----|------|---------------------------------|
| **`lib/batteries`** | Boîte à outils Lua (1ManStudio). `:export()` injecte des **globals** : `class`, `vec2`, `vec3`, `sequence`, `functional`, `table.*` (tablex), `math.*` (mathx), `colour`, `timer`, `async`, `pubsub`, `set`, `state_machine`, `stringx`, `manual_gc`, `ripairs`. | `class`, `vec2`, `mathx` (easings), `state_machine`, `sequence`, `functional`, `colour` (pack/unpack ARGB), `timer`, `pubsub`, `set`, `manual_gc` |
| **`lib/soup`** | Micro-ECS + boucle + input (auteur du jeu). | `kernel`, `entity` (ECS), `input`/`keyboard`/`mouse`/`gamepad`, `main_loop` (fixed timestep), `profiler`, `frequency_counter` |

Les **easings de `batteries/mathx`** sont le carburant de tout le tween du jeu
(`src/graphics_lerp.lua`). Recopie-les si tu n'as pas d'équivalent —
`lib/batteries/mathx.lua` :

```lua
function mathx.identity(f) return f end
function mathx.smoothstep(f) return f * f * (3 - 2 * f) end
function mathx.smootherstep(f) return f * f * f * (f * (f * 6 - 15) + 10) end
function mathx.pingpong(f) return 1 - math.abs(1 - (f * 2) % 2) end
function mathx.ease_in(f) return f * f end
function mathx.ease_out(f) local oneminus = (1 - f); return 1 - oneminus * oneminus end
function mathx.ease_inout(f)
	if f < 0.5 then return f * f * 2 end
	local oneminus = (1 - f); return 1 - 2 * oneminus * oneminus
end
function mathx.random_lerp(min, max, rng) return mathx.lerp(min, max, _random(rng)) end
function mathx.remap_range_clamped(v, in_min, in_max, out_min, out_max) --[[ … ]] end
```

> ⚠️ Note déterminisme (important pour The Pit) : DHNE utilise `love.math.random` **partout**
> dans les effets (particules, screenshake, blink). C'est volontaire — ce sont des effets de
> *présentation*. Pour The Pit, il faut **garder ces appels strictement côté présentation** et
> ne jamais les laisser remonter dans la SIM.

### 1.4 Arbre des dossiers (commenté)

```
dice/
├── conf.lua                 # version, fenêtre, DPI
├── main.lua                 # point d'entrée, love.update/draw, chaîne de post-process
├── lib/
│   ├── batteries/           # utilitaires (class, vec2, mathx, state_machine, …)
│   └── soup/                # ECS maison : kernel, entity, input, main_loop, profiler
└── src/
    ├── display.lua          # ★ canvases, scaling, fontes, composite() multi-passes
    ├── camera.lua           # caméra world/ui + application screenshake
    ├── screenshake.lua      # ★ module de tremblement
    ├── graphics_lerp.lua    # ★ système de tween (bounce/slide/wiggle/…)
    ├── screen_transition.lua# ★ wipe diagonal / fade / blink (machine à états)
    ├── screen_overlay.lua   # flash plein écran fade-out
    ├── coloured_text.lua    # coloration auto des mots-clés mécaniques
    ├── soft_cursor.lua      # ★ curseur logiciel ultra-juicé
    ├── tweaks.lua           # constantes de tuning + shader_default_amounts
    ├── game_state.lua       # state_machine racine de tous les écrans
    ├── shaders/             # ★★ tous les wrappers Lua + GLSL inline
    │   ├── snippets.lua       # prélude GLSL partagé (rotate, oklab, PI/TAU)
    │   ├── bloom.lua  blur.lua  bulge.lua  chromab.lua  vignette.lua
    │   ├── scanlines.lua  sharpen.lua  dark_mode.lua  displacement.lua
    │   ├── spell.lua  void.lua  colour_remap.lua  colour_rotation.lua
    │   └── old_world_shader.lua
    ├── systems/             # systèmes ECS : sprite, animation, ui, async, physics, tags
    ├── behaviours/          # sprite.lua (rendu d'un quad), glitter.lua (scintillement)
    ├── entities/            # ★ fabriques d'entités (effets + objets de jeu)
    │   ├── particle.lua       # système de particules maison
    │   ├── explosion.lua  ripple.lua  star.lua  charge.lua  coin.lua
    │   ├── random_sparklies.lua  water_sparklies.lua  unlock_sparklies.lua
    │   ├── wipe_spotlight.lua  scrolling_background.lua  float_up_text.lua
    │   ├── announce_img.lua  dice.lua (1900 l.)  die_baby.lua  pickup.lua
    │   ├── buttons_clump.lua  choice_pick.lua  dice_pick.lua  power_ui.lua
    │   └── …
    ├── ui/                  # tooltip, item_hover, dark_background, character_body, …
    ├── audio/              # init (mix), music, ambient, sound_pool, loading_thread
    └── states/              # game.lua, title.lua, intro_*, ending_*, unlock, options
```

---

## 2. Architecture

### 2.1 Point d'entrée (`main.lua`)

`main.lua` enchaîne : deps → globals utilitaires → save → `display` → `screen_transition`
→ `audio` → `soft_cursor` → `main_loop` → état `load`. Extrait :

```lua
display = require("src.display")
lg.setDefaultFilter("nearest", "nearest")
lg.setBackgroundColor(0.0, 0.0, 0.0, 1.0)
display:init_resolution()

screen_transition = require("src.screen_transition")({ wipe_time = 0.25, fade_time = 0.3 })
audio = require("src.audio")
soft_cursor = require("src.soft_cursor")()

main_loop = soup.main_loop({ profiler = profiler, input = input, garbage_time = 1.5e-3 })
function TIME() return main_loop.time end
function TICKTIME() return main_loop.ticktime end

game_state = require("src.states.load")
```

`TIME()` est l'horloge globale (temps de jeu accumulé, scalable). **Quasi tous les effets
de juice pulsent sur `TIME()`** via des `math.sin(TIME() * math.tau * f)`.

### 2.2 Boucle principale à pas fixe (`lib/soup/main_loop.lua`)

Le jeu **redéfinit `love.run`** pour un *fixed timestep* à 60 Hz avec accumulateur,
snapping de dt, clamping, GC manuel et sleep adaptatif. Cœur :

```lua
self.frametime = args.frametime or 1 / 60
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
	love.timer.step()
	local frametimer = 0
	return function()
		local start_of_loop = love.timer.getTime()
		-- events …
		local raw_dt = love.timer.step()
		local dt = raw_dt * self.timescale
		self.time = self.time + dt
		-- fuzzy timing snapping (colle dt aux multiples de frametime à 2ms près)
		for _, v in ipairs {0.5, 1, 2} do
			v = self.frametime * v
			if math.abs(dt - v) < 0.002 then dt = v end
		end
		dt = math.clamp(dt, 0, 2 * self.frametime)
		frametimer = frametimer + dt
		frametimer = math.clamp(frametimer, 0, 8 * self.frametime)
		local ticked = false
		while frametimer > self.frametime do
			self.ticktime = self.ticktime + self.frametime
			frametimer = frametimer - self.frametime
			love.update(self.frametime)         -- dt CONSTANT passé à l'update
			ticked = true
		end
		if love.graphics and love.graphics.isActive() and (ticked or self.interpolate_render) then
			love.graphics.origin(); love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw(frametimer / self.frametime)  -- interpolant passé à draw
			love.graphics.present()
		end
		-- GC manuel borné en temps + sleep proportionnel au temps libre
		manual_gc(self.garbage_time)
		local time_until_now = love.timer.getTime() - start_of_loop
		local sleep_f = math.clamp01((time_until_now * 1.2) / self.frametime)
		local sleep_time = math.lerp(self.frametime / 2, 0, sleep_f)
		if sleep_time > 0 then love.timer.sleep(sleep_time) end
	end
end
```

À retenir : **update toujours appelé avec `dt = 1/60` constant** (déterminisme des anims),
le rendu reçoit un interpolant. `timescale` permet le mode "fast anim" d'accessibilité
(`main.lua` : `main_loop.timescale = SAVE.accessibility.fast_anim and 2 or 1`).

### 2.3 Machine à états des écrans (`src/states/`, `src/game_state.lua`)

`game_state.lua` est un `state_machine` (de batteries) listant **tous** les écrans :

```lua
return state_machine({
	intro = require("src.states.intro"),
	title = require("src.states.title"),
	game_setup = require("src.states.game_setup"),
	game  = require("src.states.game"),
	unlock = require("src.states.unlock"),
	options = require("src.states.options"),
	ending = require("src.states.ending"),
	-- … intros / trailers / showcase
}, "(none)")
```

`lib/batteries/state_machine.lua` : chaque état est soit une table
`{enter, exit, update, draw}`, soit une fonction. **Retourner un nom d'état valide depuis
`enter`/`update` déclenche une transition** (`_call_and_transition`). Les états sont
imbricables (un state_machine peut être un état d'un autre via `enter(parent)`).

### 2.4 Modèle d'entités / behaviours (`lib/soup/kernel.lua`, `entity.lua`)

Micro-ECS volontairement minimal. **Un "behaviour" = une table Lua nue** avec
éventuellement `update(self, dt)`, `draw(self)`, `order`/`draw_order`, `pos`, `enabled`,
`visible`. Le `kernel` :

- range les behaviours dans `all`, `with_update`, `with_draw` ;
- **trie `with_update` par `order`** et **`with_draw` par `draw_order`/`order`** à chaque
  frame (insertion sort, stable et rapide sur listes quasi-triées) ;
- avant `:draw()`, **applique `lg.translate(pos.x, pos.y)`** si le behaviour a un `pos`,
  puis `push/pop` autour ;
- gère un **add/remove/defer différé** (`flush`) pour ne jamais muter les listes pendant
  l'itération.

```lua
function kernel:draw()
	table.insertion_sort(self.with_draw, entity.draw_less)
	for _, v in ipairs(self.with_draw) do
		if v.visible ~= false and v.enabled ~= false then
			lg.push("all")
			if v.pos then lg.translate(v.pos.x, v.pos.y) end
			v:draw()
			lg.pop()
		end
	end
end
```

L'`entity` regroupe des behaviours (`:add`, `:add_named`, `:add_from_system`), proxy les
events (`pubsub`) et **détruit proprement** tous ses behaviours + souscriptions via
`:destroy()` (différé). Le `__index` d'une entité expose ses behaviours nommés comme des
champs (`e.sprite`, `e.dice`, `e.animation`).

Les **systèmes** (`kernel:add_system(name, system)`) sont eux-mêmes des behaviours
(updatés/dessinés dans l'ordre) ET des fabriques : `entity:add_from_system("sprite", args)`
appelle `system:create(args)`. Systèmes présents : `sprite`, `animation`, `ui`, `async`,
`physics`, `tags`.

**Diagramme texte :**

```
love.run (pas fixe 60Hz)
  └─ love.update(dt=1/60)
       ├─ display:update     input:update
       ├─ game_state:update ──► state courant (ex: states/game.lua)
       │      └─ kernel:update ─► tri par .order ─► v:update(dt) pour chaque behaviour
       │            (systèmes ui/sprite/animation/async/physics traités comme behaviours)
       ├─ screen_transition:update     audio:update     soft_cursor:update
  └─ love.draw(interpolant)
       ├─ display:push()  → canvas current_frame (monde)
       ├─ game_state:draw → kernel:draw (tri par draw_order, translate pos, push/pop)
       │       └─ ui_system:draw bascule sur canvas ui_frame (display:start_ui)
       ├─ screen_transition:draw (sur ui_frame)
       ├─ soft_cursor:draw
       └─ display:composite(world_passes, ui_passes, post_passes)  → final_frame
            puis display:draw() étire final_frame à l'écran
```

---

## 3. Pipeline de rendu & post-processing

C'est l'épine dorsale du look du jeu. Tout est dans `src/display.lua` (canvases +
`composite()`) et orchestré dans `main.lua/love.draw`.

### 3.1 Les canvases (`display:refresh_dimensions`)

```lua
local function screen_cv()
	local cv = lg.newCanvas(self.width, self.height)   -- 1920×1080
	cv:setFilter("linear", "linear")
	return cv
end
self.last_frame     = screen_cv()   -- frame N-1 (feedback : shader spell, etc.)
self.current_frame  = screen_cv()   -- le MONDE est dessiné ici
self.ui_frame       = screen_cv()   -- l'UI est dessinée ici (séparée pour post distinct)
self.composite_frame= screen_cv()   -- résultat monde+ui fusionné
self.final_frame    = screen_cv()   -- résultat final post-processé
self.temp_frames    = {}            -- pool de canvas temporaires (ping-pong)
```

À chaque frame, `display:swap_buffers()` échange `current_frame` et `last_frame` →
le shader `spell` peut lire la frame précédente pour un **feedback de traînée**.

### 3.2 Ordre de dessin (`main.lua / love.draw`)

```lua
function love.draw()
	if not display:resize_if_needed() then return end
	lg.clear(0, 0, 0, 1)
	display:set_font("ui", 4)
	display:push()                 -- ► canvas monde

	lg.push("all"); game_state:draw(); lg.pop()   -- monde + (l'UI bascule sur ui_frame)

	display:start_ui()             -- s'assure d'être sur le canvas UI
	lg.push("all"); screen_transition:draw(); lg.pop()
	soft_cursor:draw()

	display:pop()

	-- uniforms partagés à tous les shaders
	local _default_uniforms = { time = TIME(), dark_mode = display.dark_mode and 1 or 0 }
	local function uniforms(t) return table.overlay({}, _default_uniforms, t) end

	display:composite(
		--world shaders
		{
			{shader = require("src.shaders.dark_mode"), uniforms = uniforms{}},
			((display.world_blur or 0) > 0) and {shader = require("src.shaders.blur"), uniforms = uniforms{
				blur_steps = 2, blur_strength = display.world_blur or 0,
				blur_step_size = display.world_blur_size or 1,
				texture_size = {display:dimensions()}, gaussian = true }},
		},
		--ui shaders
		{
			{shader = require("src.shaders.dark_mode"), uniforms = uniforms{
				dark_mode = HACK_NO_UI_DARK_MODE and 0 or display.dark_mode and 0.5 or 0 }},
		},
		--final composite
		{
			{ shader = require("src.shaders.displacement").shader,
			  uniforms = uniforms{ displacement_map = require("src.shaders.displacement"):canvas(),
			                       dimensions = {display:dimensions_scaled()} },
			  setup = function() require("src.shaders.displacement"):update() end },
			((display.screen_blur or 0) > 0) and {shader = require("src.shaders.blur"), uniforms = uniforms{
				blur_steps = 2, blur_strength = display.screen_blur or 0,
				blur_step_size = display.screen_blur_size or 1,
				texture_size = {display:dimensions()}, gaussian = true }},
			{shader = require("src.shaders.vignette"), uniforms = uniforms{
				strength = 1.0, vignette_colour = display.vignette_colour or {0.1, 0.0, 0.2, 1.0} }},
			{ shader = require("src.shaders.chromab").shader,
			  uniforms = uniforms{
			      chromab_scale = (function()
			          local s = game_state and game_state.current_state and game_state:current_state()
			          local c = s and s.camera
			          local shake = c and c.screenshake
			          local amount = shake and shake:amount()
			          return (amount or 0) * 0.2     -- ★ l'aberration suit le screenshake
			      end)(),
			      accessibility_scale = SAVE.accessibility.chromab or require("src.tweaks").shader_default_amounts.chromab },
			  setup = function() require("src.shaders.chromab"):flush_masks() end },
			{shader = require("src.shaders.sharpen"), uniforms = uniforms{
				strength = 0.1, sample_distance = 2.0, texture_size = {display:dimensions()}, gaussian = true }},
			{shader = require("src.shaders.scanlines"), uniforms = uniforms{
				scanlines_scale = SAVE.accessibility.scanlines or require("src.tweaks").shader_default_amounts.scanlines }},
			{shader = require("src.shaders.bulge"), uniforms = uniforms{
				bulge_scale = SAVE.accessibility.bulge or require("src.tweaks").shader_default_amounts.bulge }},
			{shader = require("src.shaders.bloom"), uniforms = uniforms{}},
		}
	)
	lg.setCanvas()
	display:draw()                 -- étire final_frame à l'écran
	display:swap_buffers()
end
```

**Ordre exact de la chaîne finale de post-process** (capital pour reproduire le look) :

```
monde ─dark_mode→ [blur?] ─┐
                            ├─► composite_frame ─┐
ui   ─dark_mode(0.5) ───────┘                    │
                                                  ▼
composite_frame ─► displacement ─► [blur écran?] ─► vignette ─► chromatic aberration
                ─► sharpen ─► scanlines ─► bulge ─► bloom ─► final_frame ─► écran
```

Idée clé : **le monde et l'UI ont leur propre passe `dark_mode`** (l'UI moins assombrie,
`0.5`), puis sont fusionnés, puis la **chaîne CRT/lentille s'applique à l'ensemble**.
L'aberration chromatique est **pilotée par l'amplitude de screenshake** → chaque secousse
"déchire" légèrement les couleurs.

### 3.3 Le moteur multi-passes : `display:composite()`

Le mécanisme générique qui exécute une liste de passes shader en **ping-pong** entre deux
canvases. C'est ce qui rend la chaîne ci-dessus si compacte. Verbatim :

```lua
function display:composite(world_passes, ui_passes, post_passes)
	lg.push("all")
	self._composite_rendered_offset = false
	for _, cfg in ipairs({
		{ source = self.current_frame,  target = self.composite_frame, passes = world_passes },
		{ source = self.ui_frame,       target = self.composite_frame, passes = ui_passes },
		{ source = self.composite_frame,target = self.final_frame, render_offset = true, clear = true, passes = post_passes },
	}) do
		local t, s = nil, cfg.source
		--filtre les passes "false" pour pouvoir les désactiver dynamiquement
		functional.filter_inplace(cfg.passes, function(v) return v end)
		for i, pass in ipairs(cfg.passes) do
			lg.push("all")
			if i == #cfg.passes then
				lg.setBlendMode("alpha", "premultiplied")   -- dernière passe → canvas cible
				if cfg.target == true then lg.setCanvas() else lg.setCanvas(cfg.target) end
			else
				if not t then t = display:_get_temp_canvas(s) end
				lg.setBlendMode("replace")                  -- passes intermédiaires → temp
				lg.setCanvas(t)
			end
			if pass.uniforms then
				for k, v in pairs(pass.uniforms) do
					if pass.shader:hasUniform(k) then
						-- envoi typé : couleur / tableau / scalaire
						if type(v) == "table" then
							if v.colour or v.color then
								if v.array then pass.shader:sendColor(k, unpack(v)) else pass.shader:sendColor(k, v) end
							elseif v.array then pass.shader:send(k, unpack(v))
							else pass.shader:send(k, v) end
						else pass.shader:send(k, v) end
					end
				end
			end
			lg.setShader(pass.shader)
			lg.origin()
			if cfg.clear then lg.clear() end
			if pass.setup then pass.setup() end   -- hook avant draw (ex: flush masks)
			lg.draw(s)
			lg.pop()
			t, s = s, t                            -- swap ping-pong
		end
	end
	lg.pop()
end
```

Détails reproductibles :

- **Ping-pong** entre `s` (source) et `t` (un canvas temporaire issu d'un pool indexé par
  dimensions, `_get_temp_canvas`). Chaque passe lit `s`, écrit dans `t`, puis on échange.
- **Passes intermédiaires en `setBlendMode("replace")`** (on écrase, pas de blending),
  **dernière passe en `("alpha","premultiplied")`** vers le canvas cible.
- **Passes `false` ignorées** : `((display.world_blur or 0) > 0) and {…}` renvoie `false`
  si désactivé, filtré par `filter_inplace`. Permet d'activer/couper un effet sans toucher
  la structure.
- **Hook `setup`** par passe : ex. `displacement:update()` (fade de la carte) ou
  `chromab:flush_masks()` (envoi des masques accumulés pendant le draw UI).
- L'envoi d'uniforms vérifie `shader:hasUniform(k)` → on peut partager un même dictionnaire
  d'uniforms entre shaders qui n'en utilisent qu'une partie.

### 3.4 Présentation finale et letterbox

```lua
function display:draw()
	self.final_frame:setFilter("linear")
	lg.draw(self.final_frame, self.offset.x, self.offset.y, 0, self.canvas_scale)
end
```

`canvas_scale = min(rawW/1920, rawH/1080)` et `offset` centre l'image (barres noires si le
ratio diffère). `display:set_print_scale` + le système de fontes gèrent un rendu de texte
net à l'échelle voulue (cache de fontes par famille/taille, `y_adjust` par police).

---

## 4. Shaders (catalogue complet)

Tous les shaders sont dans `src/shaders/`. **Pattern commun** : un fichier renvoie soit
directement `lg.newShader(...)`, soit une **table** `{shader=…, méthodes…}` quand il a un
état (masques, canvas). La plupart **préfixent leur GLSL avec `snippets.lua`** (concaténation
de strings).

> Le dossier complet : `snippets.lua`, `bloom.lua`, `blur.lua`, `bulge.lua`, `chromab.lua`,
> `colour_remap.lua`, `colour_rotation.lua`, `dark_mode.lua`, `displacement.lua`,
> `old_world_shader.lua`, `scanlines.lua`, `sharpen.lua`, `spell.lua`, `vignette.lua`,
> `void.lua`. **Tous documentés ci-dessous.**

### 4.0 `snippets.lua` — prélude GLSL partagé

Rôle : fonctions GLSL réutilisées (rotations 2D/euler, conversions oklab pour manipuler la
teinte dans un espace perceptuel, constantes `PI`/`TAU`). Concaténé devant les autres shaders.

```glsl
//constants
const float PI = 3.14159;
const float TAU = PI * 2.0;

//rotations
vec2 rotate(vec2 v, float t) {
	float s = sin(t);
	float c = cos(t);
	return vec2(
		v.x * c + v.y * -s,
		v.x * s + v.y * c
	);
}

vec3 rotate_euler(vec3 v, vec3 e) {
	v.yz = rotate(v.yz, e.x);
	v.xz = rotate(v.xz, e.y);
	v.xy = rotate(v.xy, e.z);
	return v;
}

//oklab stuff, from https://gist.github.com/akella/059d9877b90f966c9181ffa2bc5ffd65
float fixedpow(float a, float x) { return pow(abs(a), x) * sign(a); }
float cbrt(float a) { return fixedpow(a, 0.3333333333); }

vec3 lsrgb2oklab(vec3 c) {
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
    float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
    float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
    float l_ = cbrt(l); float m_ = cbrt(m); float s_ = cbrt(s);
    return vec3(
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    );
}
vec3 oklab2lsrgb(vec3 c) {
    float l_ = c.r + 0.3963377774 * c.g + 0.2158037573 * c.b;
    float m_ = c.r - 0.1055613458 * c.g - 0.0638541728 * c.b;
    float s_ = c.r - 0.0894841775 * c.g - 1.2914855480 * c.b;
    float l = l_ * l_ * l_; float m = m_ * m_ * m_; float s = s_ * s_ * s_;
    return vec3(
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );
}
```

Le wrapper Lua est trivial : `return [[ … ]]` (une string). Les autres shaders font
`lg.newShader(require("src.shaders.snippets")..[[ … ]])`.

**Comment reproduire :** garde un fichier `snippets` séparé et concatène-le. `oklab` permet
les rotations de teinte propres (utilisé par `colour_rotation` sur le fond).

### 4.1 `bloom.lua` — bloom additif léger

Rôle : ajoute une lueur additive échantillonnée en croix (5 taps). Dernière passe de la
chaîne, donc tout brille un peu.

```glsl
uniform float time;
// bloom
float bloom_strength = 0.2;
float bloom_radius = 2.5;

vec4 bloomSample(Image t, vec2 uv, vec2 pxsize) {
    vec4 s = Texel(t, uv);
    s += Texel(t, uv + pxsize * bloom_radius);
    s += Texel(t, uv - pxsize * bloom_radius);
    s += Texel(t, uv + vec2(pxsize.y, -pxsize.x) * bloom_radius);
    s += Texel(t, uv + vec2(-pxsize.y, pxsize.x) * bloom_radius);
    return s / 5.0;
}

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
    vec2 pxsize = vec2(1.0 / love_ScreenSize.x, 1.0 / love_ScreenSize.y);
    vec4 bloom = bloomSample(t, uv, pxsize);
    // always additive
    c *= Texel(t, uv);
    c.rgb += bloom.rgb * bloom_strength;
    return c;
}
```

Lua : `return lg.newShader(require("src.shaders.snippets")..[[ … ]])`. Aucun uniform à
piloter (constantes en dur). **Reproduire :** un seul tap-croix + add à 0.2 suffit pour un
bloom "discret partout" sans seuil de luminance — pas cher, très lisible.

### 4.2 `blur.lua` — flou boîte/gaussien paramétrable

Rôle : flou monde (`world_blur`) ou plein écran (`screen_blur`), activé dynamiquement.

```glsl
uniform int blur_steps = 1;
uniform float blur_step_size = 1;
uniform float blur_strength = 1.0;
uniform vec2 texture_size = vec2(1.0, 1.0);
uniform bool gaussian = true;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
    vec4 colour = vec4(0.0);
    vec4 current = Texel(t, uv);
    float total = 0.0;
    for (float ox = -blur_steps; ox <= blur_steps; ox++) {
        for (float oy = -blur_steps; oy <= blur_steps; oy++) {
            float a = 1.0;
            vec2 o = vec2(ox, oy) * blur_step_size;
            if (gaussian) {
                a = clamp(length(o) / (blur_steps * blur_step_size + 1.0), 0.0, 1.0);
            }
            if (a > 0) {
                o /= texture_size;
                colour += Texel(t, uv + o) * a;
                total += a;
            }
        }
    }
    return c * mix(current, (colour / total), blur_strength);
}
```

Application (depuis `love.draw`) : `blur_steps=2`, `texture_size = {display:dimensions()}`,
`blur_strength` = `display.world_blur`/`display.screen_blur`. **Reproduire :** flou non
séparé (O(n²)) mais avec `steps=2` c'est 25 taps, acceptable ; `blur_strength` permet un
fondu progressif (mix avec l'original).

### 4.3 `bulge.lua` — distorsion lentille (barrel)

Rôle : bombe l'image vers l'extérieur façon écran cathodique. Avant-dernière passe.

```glsl
uniform float bulge_scale;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec2 center = love_ScreenSize.xy * 0.5;
	vec2 px_offset = px - center;
	vec2 normalized = px_offset / love_ScreenSize.xy; // -0.5 to 0.5 range
	normalized = normalized * length(px_offset);
	vec2 disp = normalized * bulge_scale;
	float bulge_comp = bulge_scale * 0.5;
	uv = vec2(
		mix(bulge_comp, 1.0 - bulge_comp, uv.x),
		mix(bulge_comp, 1.0 - bulge_comp, uv.y)
	) + disp / love_ScreenSize.xy;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return c * Texel(t, uv);
}
```

`bulge_scale` par défaut `0.05` (`tweaks.shader_default_amounts.bulge`), réglable en
accessibilité. **Reproduire :** le déplacement croît avec la distance au centre × cette
même distance (`length(px_offset)`) → bombement quadratique ; on **recompense** les bords
en remappant l'UV vers l'intérieur (`bulge_comp`) pour ne pas exposer du vide.

### 4.4 `chromab.lua` — aberration chromatique radiale, rotative, **masquée**

Le shader le plus sophistiqué de la chaîne. Rôle : sépare R/G/B radialement, la séparation
**tourne dans le temps**, **s'intensifie avec le screenshake**, **s'atténue aux bords** et
**peut être annulée localement par des masques** (rectangles/cercles) — utilisé pour ne pas
déchirer le texte des tooltips/cartes.

C'est une **table** avec gestion de masques. Wrapper Lua intégral :

```lua
return {
    masks = sequence(),
    add_rect_mask = function(self, args)
        self.masks:push({ pos = args.pos, size = args.halfsize and args.halfsize * 2 or args.size })
    end,
    add_circle_mask = function(self, args)
        self.masks:push({ pos = args.pos, size = vec2(args.radius, -1) })
    end,
    flush_masks = function(self)
        self.shader:send("mask_count", #self.masks)
        if #self.masks > 0 then
            self.shader:send("mask_position", unpack(self.masks:map_field("pos"):map_call("pack")))
            self.shader:send("mask_size", unpack(self.masks:map_field("size"):map_call("pack")))
        end
        self.masks:clear()
    end,
    shader = lg.newShader(require("src.shaders.snippets")..[[
        uniform float time;
        uniform float chromab_scale;
        uniform float accessibility_scale;

        const int MASK_MAX = 4;
        uniform int mask_count = 0;
        uniform vec2 mask_position[MASK_MAX];
        uniform vec2 mask_size[MASK_MAX]; //if negative on y then its a circle

        vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
            float chromab = (1.0 / 320.0) * (1.0 + chromab_scale * 18.0);
            float chromab_offset = 0.1;
            float chromab_rotate_speed = 0.15;

            vec2 centre_offset = uv - vec2(0.5, 0.5);
            float centre_distance = length(centre_offset);

            //(reduce amount at the edges to avoid sampling outside the screen)
            float edge_size = 100.0;
            float edge_distance_scale = clamp(min(
                min(uv.x, 1.0 - uv.x) * love_ScreenSize.x,
                min(uv.y, 1.0 - uv.y) * love_ScreenSize.y
            ) / edge_size, 0.0, 1.0);

            float dither = (mod(px.x + px.y, 2.0) - 1.0) / 128.0;

            //masking
            float mask_scale = 1.0;
            for (int i = 0; i < mask_count; i++) {
                vec2 mpos = mask_position[i];
                vec2 msize = mask_size[i];
                vec2 d = mpos - px;
                float mask_amount = 0.0;
                float border = 25.0;
                if (msize.y < 0.0) {
                    float edge = length(d) - msize.x;
                    mask_amount = edge < 0.0 ? 1.0 : (border - edge) / border; //circle
                } else {
                    vec2 edge = abs(d) - (msize * 0.5); //aabb
                    mask_amount = (edge.x < 0.0 && edge.y < 0.0)
                        ? 1.0 : (border - max(edge.x, edge.y)) / border;
                }
                mask_amount = max(0.0, mask_amount);
                mask_scale = clamp(min(mask_scale, 1.0 - mask_amount), 0.0, 1.0);
            }

            float chromab_amount = max(0.0, (centre_distance - chromab_offset) * chromab);
            chromab_amount *= edge_distance_scale * mask_scale * accessibility_scale;

            float tau = 3.14159 * 2.0;
            float rotation = (time + dither) * tau * chromab_rotate_speed;

            vec2 a_uv = uv + rotate(vec2(sin(rotation), cos(rotation * 2)), 0) * chromab_amount;
            vec2 b_uv = uv + rotate(vec2(sin(rotation * 1.15), cos(rotation)), tau * 0.33) * chromab_amount;
            vec2 c_uv = uv + rotate(vec2(sin(rotation), cos(rotation * 0.97)), tau * 0.66) * chromab_amount;

            float h = 0.9;
            float l = (1.0 - h) / 2.0;
            vec3 a_mask = vec3(h, l, l);
            vec3 b_mask = vec3(l, h, l);
            vec3 c_mask = vec3(l, l, h);

            c *= vec4(
                Texel(t, a_uv).rgb * a_mask +
                Texel(t, b_uv).rgb * b_mask +
                Texel(t, c_uv).rgb * c_mask,
                Texel(t, uv).a
            );
            return c;
        }
    ]]),
}
```

Application (`love.draw`) : `chromab_scale = screenshake:amount() * 0.2`,
`accessibility_scale` par défaut `1`, `setup = chromab:flush_masks`. **Les masques sont
poussés pendant le dessin de l'UI** : `src/ui/tooltip.lua` et `src/ui/item_hover.lua` font
`require("src.shaders.chromab"):add_rect_mask{ pos = vec2(lg.transformPoint(...)), size = … }`
pour que la tooltip reste nette malgré l'aberration globale.

**Comment reproduire :** trois échantillons R/G/B décalés sur des vecteurs **tournants**
(évite le banding directionnel fixe) ; la quantité = `(distance_centre - offset) * scale`
× falloff bords × masques. Les masques sont un petit tableau d'uniforms (max 4) ; `y<0`
encode un cercle. C'est la technique qui rend l'aberration "vivante" plutôt que statique.

### 4.5 `vignette.lua` — vignette qui respire

Rôle : assombrit/teinte les bords, avec un **léger flottement temporel** (wiggle) et du
dithering pour éviter le banding.

```glsl
uniform float time;
float wiggle_speed = 1.0 / 10.0;
float wiggle_amount = 1.0 / 20.0;
uniform float strength;
uniform vec4 vignette_colour;
float vignette = 0.6;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec2 centre_offset = uv - vec2(0.5, 0.5);
	float wiggle = mix(
		sin(time * PI * wiggle_speed),
		sin(time * PI * (wiggle_speed + 0.13)),
		(cos(time * PI * (wiggle_speed - 0.077)) + 1.0) / 2.0
	) * wiggle_amount;
	float centre_distance = length(centre_offset) + wiggle;
	float dither = (mod(px.x + px.y, 2.0) - 1.0) / 128.0;
	float vignette_amount = clamp(
		mix(0.0, 3.0, (centre_distance * (centre_distance - 0.1))) * vignette * strength + dither,
		0.0, 1.0
	);
	c *= Texel(t, uv);
	c.rgb = mix(c.rgb, vignette_colour.rgb, vignette_amount);
	return c;
}
```

`vignette_colour` vient du board courant (ex. `{0.1, 0.0, 0.2, 1.0}` violet sombre, posé par
`scrolling_background.lua`). **Reproduire :** mélange vers une **couleur** (pas juste du
noir) ; le `wiggle` triple-sinus désynchronisé rend la vignette organique.

### 4.6 `scanlines.lua` — lignes CRT

```glsl
uniform float time;
uniform float scanlines_scale;
float intensity = 0.2;
float spacing = 6.0;
float sharpness = 3.0;
float speed = 0;
vec3 gap_tint = vec3(0.0, 0.02, 0.05); // blue tint added to dark gaps

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	float scan = mod(px.y + time * speed, spacing) / spacing;
	float scan_f = 1.0 - abs(1.0 - mod((scan * 2.0), 2.0)); //pingpong
	scan_f = clamp(mix(-sharpness, sharpness + 1.0, scan_f), 0.0, 1.0); //sharpen
	float dither = (mod(px.x + px.y, 2.0) - 1.0) / 128.0; //dither
	scan_f += dither;
	scan_f *= scanlines_scale;
	float scanline = mix(scan_f, 1.0, 1.0 - intensity);
	c *= Texel(t, uv);
	c.rgb *= scanline;
	c.rgb += (1.0 - scan_f) * gap_tint;   // teinte bleue dans les creux
	return c;
}
```

`scanlines_scale` défaut `0.7`. **Reproduire :** pingpong + sharpen donne des lignes douces
mais marquées ; **ajouter une teinte dans les creux** (`gap_tint`) au lieu de juste
assombrir donne le côté phosphore.

### 4.7 `sharpen.lua` — masque flou (unsharp)

```glsl
uniform int sample_distance = 1;
uniform float strength = 1.0;
uniform vec2 texture_size = vec2(1.0, 1.0);
uniform bool gaussian = true;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
    vec4 colour = vec4(0.0);
    vec4 current = Texel(t, uv);
    float total = 0.0;
    for (float ox = -sample_distance; ox <= sample_distance; ox++) {
        for (float oy = -sample_distance; oy <= sample_distance; oy++) {
            if (ox == 0 && oy == 0) continue;
            float a = 1.0;
            vec2 o = vec2(ox, oy);
            if (gaussian) { a = clamp(length(o) / (sample_distance + 1.0), 0.0, 1.0); }
            if (a > 0) {
                o /= texture_size;
                vec4 difference = current - Texel(t, uv + o);
                colour += difference * a;
                total += a;
            }
        }
    }
    return c * (current + (colour / total) * strength);
}
```

Appliqué après le bulge/blur pour **récupérer du croquant** perdu par l'étirement linéaire.
`strength=0.1`, `sample_distance=2`. **Reproduire :** ajoute la différence pondérée au pixel
courant ; `strength` faible évite les halos.

### 4.8 `dark_mode.lua` — passage "clair de lune"

Rôle : désature vers un gris bleuté nocturne (mode sombre du jeu). Appliqué séparément au
monde (`1.0`) et à l'UI (`0.5`).

```glsl
uniform float dark_mode;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
    c *= Texel(t, uv);
    if (dark_mode > 0.0) {
        float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        vec3 moon_grey = vec3(luma * 0.88, luma * 0.93, luma * 1.12);
        vec3 desat = mix(c.rgb, moon_grey, 0.45);
        vec3 blue_shift = desat * vec3(0.78, 0.85, 1.05);
        blue_shift = pow(blue_shift, vec3(1.12));
        c.rgb = mix(c.rgb, blue_shift, dark_mode);
    }
    return c;
}
```

**Reproduire :** désature vers un gris **biaisé bleu** (le bleu > 1.0), recolore, remonte le
gamma (`pow 1.12`) pour creuser les ombres, puis `mix` par l'intensité. Excellent pour un
toggle jour/nuit sans changer les assets.

### 4.9 `displacement.lua` — ★ la carte de déplacement (cœur du juice physique)

C'est l'**effet signature** : tous les "coups" (clic, impact de dé, explosion, scroll,
maintien clic droit) déforment localement l'écran. Mécanisme : un **canvas `rg32f`** (deux
floats signés par pixel = vecteur de déplacement) dans lequel on dessine des bosses/ondes
additives ; il **se vide progressivement chaque frame** ; le shader final lit ce canvas et
décale l'UV en conséquence.

Wrapper Lua intégral (table avec canvas + sous-shaders bump/ripple/noise) :

```lua
return {
	shader = lg.newShader(require("src.shaders.snippets")..[[
		uniform Image displacement_map;
		uniform vec2 dimensions;
		vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
			vec4 disp = Texel(displacement_map, uv);
			uv += disp.xy / dimensions;
			return c * Texel(t, uv);
		}
		]]),
	canvas = function(self)
		local w, h = display:dimensions_scaled()
		if self._old_dims then
			if self._old_dims[1] ~= w or self._old_dims[2] ~= h then self._old_dims = nil end
		end
		if not self._old_dims then self._old_dims = {w, h}; self._cv = nil end
		if not self._cv then
			self._cv = lg.newCanvas(w, h, { format = "rg32f" })
			self._cv:setFilter("linear")
		end
		return self._cv
	end,
	push = function(self) local cv = self:canvas(); lg.push("all"); lg.setCanvas(cv); lg.origin() end,
	pop = function(self) lg.pop() end,
	update = function(self)
		self:push()
		lg.setColor(0, 0, 0, 0.1)
		lg.setBlendMode("alpha", "alphamultiply")
		lg.rectangle("fill", 0, 0, display:dimensions_scaled())   -- ★ fade de la carte (10%/frame)
		self:pop()
	end,

	pixel = lg.newImage(love.image.newImageData(1, 1)),   -- 1px blanc, étiré pour dessiner les bumps

	bump_shader = lg.newShader([[
		uniform float amount;
		vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
			vec2 d = vec2(0.5) - uv;
			if (length(d) > 0.5) { return vec4(0.0); }
			float f = amount * max(0.0, 1.0 - length(d) * 2.0);
			return vec4(d * f, 1.0, 1.0);
		}
	]]),
	bump = function(self, args)
		self:push()
		local pos = assert:some(args.pos)
		local radius = assert:some(args.radius)
		local amount = args.amount or 1
		local scale = args.scale or vec2(1, 1)
		lg.setBlendMode("add", "alphamultiply")
		lg.setColor(1, 1, 1, 1)
		self.bump_shader:send("amount", amount)
		lg.setShader(self.bump_shader)
		lg.draw(self.pixel, pos.x, pos.y, 0, radius * 2.0 * scale.x, radius * 2.0 * scale.y, 0.5, 0.5)
		self:pop()
	end,

	ripple_shader = lg.newShader([[
		uniform float amount;
		uniform float start_offset;
		vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
			vec2 d = vec2(0.5) - uv;
			if (length(d) > 0.5) { return vec4(0.0); }
			d *= 2.0;                               //scale to 0-1
			float f = max(0.0, length(d) - start_offset);
			f *= 1.0 / (1.0 - start_offset);
			f = sin(f * 3.14159);                   //sin bump
			f *= f;                                 //square → edges smooth
			d = normalize(d);                       //direction only
			return vec4(d * amount * f, 1.0, 1.0);
		}
	]]),
	ripple = function(self, args)
		self:push()
		-- … (idem bump : draw du pixel étiré avec ripple_shader, amount/start_offset)
		self.ripple_shader:send("amount", args.amount or 1)
		self.ripple_shader:send("start_offset", args.offset or 0.5)
		lg.setShader(self.ripple_shader)
		lg.draw(self.pixel, args.pos.x, args.pos.y, 0, args.radius*2, args.radius*2, 0.5, 0.5)
		self:pop()
	end,

	noise = (function()   --champ de distorsion noisé pré-calculé (512²)
		local i = love.image.newImageData(512, 512)
		i:mapPixel(function(x, y)
			return love.math.noise(x + 0.1, y + 0.1),
			       love.math.noise(x + 110.3, y + 0.3),
			       love.math.noise(x + 0.03, y + 97.17), 1
		end)
		local img = lg.newImage(i); img:setFilter("linear"); return img
	end)(),
	noise_bump_shader = lg.newShader(require("src.shaders.snippets")..[[
		uniform Image noise; uniform float noise_scale; uniform vec2 noise_offset;
		uniform float noise_amount; uniform float amount;
		vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
			vec2 d = vec2(0.5) - uv;
			if (length(d) > 0.5) { return vec4(0.0); }
			float f = amount * max(0.0, 1.0 - length(d) * 2.0);
			vec3 n = Texel(noise, (uv * noise_scale) + noise_offset).rgb;
			n *= 2.0; n -= vec3(1.0); n *= noise_amount;
			d.x += n.x; d.y += n.y; d = rotate(d, n.z);
			return vec4(d * f, 1.0, 1.0);
		}
	]]),
	-- noise_bump = function(self, args) … end,
}
```

Le shader appliqué dans la chaîne finale (`displacement.shader`) lit `displacement_map`
(via `:canvas()`) et fait `uv += disp.xy / dimensions`. Le `setup` de cette passe appelle
`displacement:update()` qui **estompe la carte de 10 % par frame** (rectangle noir alpha 0.1
en `alphamultiply`) → les ondes s'éteignent en douceur.

**Déclencheurs réels (`grep displacement:bump|ripple`)** :
- `soft_cursor.lua` : `bump`+`ripple` au clic gauche ; `bump` continu en maintien molette
  (déforme proportionnellement au scroll) ; `bump` doux quand clic G+D (effet aimant) ;
  burst au relâchement clic droit proportionnel à la durée du maintien.
- `dice.lua` `impact_pulse` : `bump{radius=80, amount=strength*40}` à chaque rebond/impact.
- `explosion.lua` : un `bump` immédiat **+ une onde animée** (`ripple` dans une coroutine
  `async`, rayon croissant `t*400`, amount décroissant `(1-t)*15` sur 0.6 s).
- `pickup.lua` (étoiles) : `bump` au ramassage.
- `states/title.lua`, `endings/*`, `options.lua` : bumps décoratifs.

**Comment reproduire :** crée un canvas `rg32f` (deux composantes float signées) de la
résolution logique. Pour "frapper" l'écran à un endroit, dessine un quad (un sprite 1px
étiré) avec un petit shader qui écrit `vec2 direction * falloff` dans R,G. Blend **`add`**.
Chaque frame, dessine un rectangle noir alpha~0.1 dessus (fade). Dans la passe finale, lis la
carte et `uv += disp/dimensions`. Tu obtiens des chocs/ondes localisés qui se propagent et
s'éteignent — **réutilisable pour tout** (impacts, clics, sorts).

### 4.10 `spell.lua` — contour magique + feedback de traînée

Rôle : appliqué en **shader de sprite** sur les items "sort" (`src/entities/item.lua:77`,
`src/entities/shop.lua:1061`). Calcule un contour à partir de la distance au bord de l'alpha,
y ajoute un **glow**, et **mélange la frame précédente** (`previous_frame = display.last_frame`)
modulée par un échantillonnage de texture "magique" pour un effet d'aura ondulante.

```glsl
uniform float time;
uniform vec2 texture_size = vec2(1.0, 1.0);
uniform vec2 feedback_offset;
uniform Image previous_frame;
uniform vec2 previous_frame_size;
uniform Image magic_texture;
uniform vec2 magic_scale;
const float _thresh = 0.1;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	c *= Texel(t, uv);
	float _time = time * TAU / 20.0;

	//overlay magic texture on itself (3 nappes animées)
	const int magic_offset_count = 3;
	vec2 magic_offset[magic_offset_count];
	magic_offset[0] = vec2(0.5 + sin(_time) * 0.5, 0.5 + cos(_time*0.997) * 0.5);
	magic_offset[1] = vec2(mod(_time * 1.013, 1.0), mod(_time * 0.01, 1.0));
	magic_offset[2] = vec2(mod(_time * 0.011 + 0.3, 1.0), mod(_time * 0.913 + 0.1, 1.0));
	float magic_sample = 0.0;
	for (int i = 0; i < magic_offset_count; i++) {
		magic_sample += Texel(magic_texture, px / magic_scale + magic_offset[i]).r * 2.0 - 1.0;
	}
	magic_sample /= float(magic_offset_count);
	magic_sample = sqrt(abs(magic_sample)) * sign(magic_sample);

	bool solid = c.a > _thresh;
	if (solid) {
		//distance au bord (recherche radiale)
		float distance_check = 4.0;
		float distance = distance_check;
		for (int i = 1; i < distance_check; i++) {
			float sample_amount = max(4.0, i * 2.0);
			for (int samples = 0; samples < sample_amount; samples++) {
				vec2 uv2 = uv + rotate(vec2(i, 0), samples / sample_amount * TAU) / texture_size;
				if (Texel(t, uv2).a < _thresh) { distance = i; break; }
			}
			if (distance < distance_check) { break; }
		}
		//feedback (mélange la frame précédente)
		vec4 pf = Texel(previous_frame, (px + feedback_offset) / previous_frame_size);
		c = mix(c, pf, magic_sample);
		//effets selon la distance au bord
		float distance_spike = max(0.75, 2.0 / (distance + (magic_sample * 2.0 - 1.0) * 0.6));
		float distance_glow = max(0.0, 0.5 / distance - (1.0 - magic_sample));
		c.rgb = c.rgb * distance_spike + vec3(distance_glow);
		c.a = min(max((2.0 / distance) + magic_sample * 0.5, 0.0), 1.0);
		c.rgb *= 0.5 + c.a * 0.5;   //premultiply
	}
	return c;
}
```

Uniforms injectés chaque frame depuis `item.lua` (extrait) :

```lua
s.shader = require("src.shaders.spell")
-- dans draw :
s.uniforms = {
	texture_size = s.texture_size:pack(),
	feedback_offset = vec2:polar(1, self.time * math.tau * self.feedback_scroll_rate):pack(),
	previous_frame = display.last_frame,
	previous_frame_size = vec2(display.last_frame:getDimensions()):pack(),
	magic_texture = assets.shader_data_spiral,
	magic_scale = vec2(assets.shader_data_spiral:getDimensions()):smuli(2):pack(),
	time = TIME(),
}
```

**Comment reproduire :** le truc malin est le **feedback** (`display.last_frame`, échangé
chaque frame via `swap_buffers`) combiné à une recherche de distance au contour. Pour un
simple halo animé sans feedback, garde juste la boucle de distance + `distance_glow`.

### 4.11 `void.lua` — remplir le noir par une texture défilante

Rôle (sur les personnages "void", `ui/character_body.lua`) : là où le sprite est **noir pur
mais opaque**, remplace par une texture qui défile → effet de "trou dans la réalité".

```glsl
uniform Image void_texture;
uniform vec2 void_texture_size;
uniform float time;
uniform float display_scale;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
    vec4 p = Texel(t, uv);
    if (p.rgb == vec3(0.0) && p.a > 0) {
        vec2 void_uv = (px / display_scale / void_texture_size) + vec2(time * 0.07, 0.0);
        p.rgb = Texel(void_texture, void_uv).rgb;
    }
    return c * p;
}
```

Envoi : `void_shader:send("display_scale", display.scale * self.scale)`, `void_texture`,
`void_texture_size`, `time`. **Reproduire :** color-key sur le noir + sample d'une texture
en coordonnées écran (pas UV du sprite) pour que le motif "reste fixe dans le monde".

### 4.12 `colour_rotation.lua` — rotation de teinte oklab

Rôle : utilisé comme **shader de sprite sur le fond** (ciel/nuages/terre dans
`scrolling_background.lua`) pour varier la couleur d'ambiance par niveau.

```glsl
uniform float amount = 0.0;
uniform float vibrance = 1.0;
uniform float boost = 1.0;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec4 tex = Texel(t, uv);
	vec3 o = lsrgb2oklab(tex.rgb);
	o.yz = rotate(o.yz, amount * 3.14159) * vibrance;  //rotation teinte + saturation
	o.x *= boost;                                       //luminosité
	return c * vec4(oklab2lsrgb(o), tex.a);
}
```

**Reproduire :** convertis en oklab, fais tourner le plan (a,b) = teinte, scale = vibrance,
`L *= boost`. Bien plus propre qu'une rotation HSV.

### 4.13 `colour_remap.lua` — LUT 3D (color grading)

Rôle : applique une **table de correspondance couleur 3D** (`VolumeImage`) — color grading
cinéma. Peut **blender entre deux cubes**. Le wrapper sait charger un cube depuis une image
"strip" ou "square".

```glsl
uniform float amount = 1.0;
uniform VolumeImage colourmap;
uniform float blend_amount = 0.0;
uniform VolumeImage colourmap_blend;
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	vec4 original = Texel(t, uv);
	vec3 map_xyz = original.rgb;
	vec3 mapped = Texel(colourmap, map_xyz).rgb;
	if (blend_amount > 0.0) {
		mapped = mix(mapped, Texel(colourmap_blend, map_xyz).rgb, blend_amount);
	}
	return c * vec4(mix(original.rgb, mapped.rgb, amount), original.a);
}
```

Côté Lua : `load_cube(img, "strip"|"square")` découpe l'image en couches et fait
`love.graphics.newVolumeImage(layers)`. (Présent mais commenté dans la chaîne finale de
`main.lua` — disponible pour du grading dynamique.)

### 4.14 `old_world_shader.lua` — transformée 3D héritée (non utilisée en prod)

Shader vertex+pixel avec `model/camera/projection` `mat4` (projection orthographique,
inclinaison `WORLD_TILT = pi/4`). C'est un **vestige** d'un ancien moteur "world 3D" ; le jeu
final dessine en 2D. Documenté pour exhaustivité, mais **pas une référence active**.

```glsl
uniform mat4 model_transform; uniform mat4 camera_transform; uniform mat4 projection_transform;
#ifdef VERTEX
vec4 position( mat4 transform, vec4 pos) {
	pos = model_transform * pos; pos = camera_transform * pos; pos = projection_transform * pos;
	return pos;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	c *= Texel(t, uv);
	if (c.a == 0.0) { discard; }
	return c;
}
#endif
```

### 4.15 Le shader du dé (`src/entities/dice.lua`, GLSL inline)

Pas dans `src/shaders/` mais **central pour le look** : color-keying par face + motifs
défilants + contour + ombre multipliée. Permet de **recolorer** chaque face du dé (effets
poison/burn/…) sans nouveaux assets, et d'**animer un motif** par face.

```glsl
uniform Image shadow;
#define SIDE_MAX 8
uniform vec4 colour_key[SIDE_MAX];   // couleurs "clé" dans la texture source
uniform vec4 colour_out1[SIDE_MAX];  // → remplacées par un dégradé out1→out2
uniform vec4 colour_out2[SIDE_MAX];
uniform int pattern_out[SIDE_MAX];   // index de motif (ArrayImage)
uniform ArrayImage patterns;
uniform vec2 pattern_res; uniform float pattern_scale; uniform float pattern_scroll_rate;
uniform vec2 pattern_offset; uniform vec2 pattern_pos;
uniform vec4 outline_colour;
uniform float time;
uniform float ghost_wavy;

vec4 effect(vec4 c, Image t, vec2 uv, vec2 px) {
	if (ghost_wavy > 0.0) {            // ondulation pour les dés fantômes
		float freq = 30.0; float amp = 0.006 * ghost_wavy; float speed = 0.05;
		uv.x += sin((uv.y + time * speed) * freq) * amp;
	}
	vec4 tex_c = Texel(t, uv);
	if (length(tex_c.rgb - vec3(1, 0, 1)) <= 1.0 / 200.0 ) {   // magenta = contour
		tex_c.rgb = outline_colour.rgb;
	} else {
		for(int i = 0; i < SIDE_MAX; i++) {
			if (tex_c == colour_key[i]) {                       // face détectée
				vec2 scroll = vec2(time / 9.71, time) * pattern_scroll_rate + pattern_offset - pattern_pos;
				float p = Texel(patterns, vec3((px + scroll) / pattern_res / pattern_scale, pattern_out[i])).r;
				tex_c = mix(colour_out1[i], colour_out2[i], p);  // dégradé piloté par le motif
				break;
			}
		}
	}
	vec4 s = Texel(shadow, uv);
	tex_c.rgb = mix(tex_c.rgb, tex_c.rgb * s.rgb, s.a);          // ombre par multiplication
	tex_c.rgba *= c.rgba;
	tex_c.rgb *= tex_c.a;                                        // premultiplied
	return tex_c;
}
```

**Reproduire :** une palette indexée par color-key (`if tex == key[i]`) + un `ArrayImage` de
motifs scrollés en coords écran. C'est la même idée que The Pit veut pour recolorer les
créatures par affliction/rang sans multiplier les sprites.

---

## 5. Game feel / juice

### 5.1 Screenshake (`src/screenshake.lua`) — intégral

Amplitude qui **décroît linéairement** sur une durée ; déplacement = point aléatoire dans un
disque ; `trigger` **fusionne** avec une secousse en cours (ne reset pas brutalement).

```lua
local screenshake = class({ name = "screenshake" })
screenshake.scale_save_key = "screenshake_scale"
function screenshake:scale() return SAVE.accessibility[screenshake.scale_save_key] end

function screenshake:new()
	self.amplitude = 0
	self.time = 1
	self.timer = 0
	self.decay_rate = 2
end
function screenshake:update(dt) self.timer = self.timer + dt end
function screenshake:amount()
	if self.time == 0 or self.timer > self.time then return 0 end
	return math.lerp(self.amplitude, 0, math.clamp01(self.timer / self.time))
end
function screenshake:displacement()
	return vec2:polar(
		math.sqrt(love.math.random()) * self:amount(),   -- sqrt → distribution uniforme dans le disque
		love.math.random() * math.tau
	)
end
function screenshake:apply(camera_position)
	if self:amount() > 0 then camera_position:vaddi(self:displacement()) end
end
function screenshake:trigger(amplitude, time)
	local old_amount = self:amount()
	local remaining = math.max(0, self.time - self.timer)
	self.timer = 0
	self.time = math.max(remaining, time)
	self.amplitude = math.random_lerp(1, 1.1) * amplitude
		* (self:scale() or require("src.tweaks").shader_default_amounts.screenshake) + old_amount
end
```

**Application caméra** (`src/camera.lua`) — la subtilité : le shake **tourne** la vue en plus
de la translater (donne un punch plus organique qu'une simple translation) :

```lua
function camera:push()
	local now = TIME()
	if not self._dynamic_time then self._dynamic_time = now end
	local dt = math.clamp(now - self._dynamic_time, 1 / 1000, 1 / 30)
	self._dynamic_time = now
	self.screenshake:update(dt)
	self:update_centre()
	lg.push("all")
	lg.scale(self.world_scale * display.scale)
	lg.translate(self.screen_centre.x, self.screen_centre.y)
	lg.translate(-self.pos.x, -self.pos.y)
	local shake_by_rotating = true
	if shake_by_rotating then
		local amount = self.screenshake:amount()
		if amount > 0 then
			local rotation = math.random_lerp(-1, 1) * amount * math.tau / 1000
			lg.rotate(rotation)
			local shake = self.screenshake:displacement()
			lg.translate(shake.x, shake.y)
		end
	else
		local shake = self.screenshake:displacement()
		lg.translate(shake.x, shake.y)
	end
end
```

**Déclencheurs typiques :** `impact_pulse` (0.1, 0.1), prise d'étoile (0.5, 0.3), dégât de dé
(2, 0.3), explosion (15×strength, 0.5). Et **le screenshake pilote l'aberration chromatique**
(§3.2) → secousse = déchirure couleur synchronisée.

### 5.2 Tweens : `src/graphics_lerp.lua` — intégral

Système de tween léger : une pile de "lerps" qui modifient `offset/scale/angle`, avec
**enchaînement par attente** (`wait` = le lerp précédent doit finir) et **courbe** par lerp.
`push()` applique offset+scale+angle autour d'un origin (pour scaler depuis un pivot).

```lua
local graphics_lerp = class()
function graphics_lerp:new(e) self.origin = vec2(); self:clear() end

function graphics_lerp:add_lerp(time, wait, args, f)
	if wait == nil or wait == true then wait = table.back(self.lerps) end
	local lerp = { time = time, timer = 0, factor = 0, args = args, f = f, wait = wait }
	table.insert(self.lerps, lerp)
	return lerp
end

function graphics_lerp:lerp_offset(time, wait, target, curve)
	local from_offset = (wait and self.last_offset or self.offset):copy()
	self.last_offset:vset(target)
	return self:add_lerp(time, wait, { from_offset = from_offset, to_offset = target, curve = curve or math.identity },
		function(self, factor, args)
			self.offset:vset(args.from_offset):lerpi(args.to_offset, args.curve(factor))
		end)
end
-- lerp_scale / lerp_angle : même schéma sur self.scale / self.angle

function graphics_lerp:update(dt)
	local to_remove = {}
	for i, v in ipairs(self.lerps) do
		local needs_wait = false
		if v.wait then if v.wait.factor < 1 then needs_wait = true end end   -- chaînage
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
	if has_origin and (self.scale.x ~= 0 and self.scale.y ~= 0) then
		lg.translate(-self.origin.x, -self.origin.y)
	end
	return self
end
function graphics_lerp:pop() lg.pop(); return self end

-- ★ pratique : avance le tween tout seul avec l'horloge globale puis push
function graphics_lerp:dynamic_push()
	local now = TIME()
	local dt = now - (self._last_time or now)
	self._last_time = now
	self:update(dt)
	self:push()
	return self
end
```

**Presets** (recopiés — ce sont les "recettes" de juice prêtes à l'emploi) :

```lua
function graphics_lerp:bounce_in_hard(total_time)
	total_time = total_time or 0.3
	self:lerp_offset(total_time * 0.0, false, vec2(0, 2), math.identity)
	self:lerp_offset(total_time * 1.0, true,  vec2(0, 0), math.ease_out)
	self:lerp_scale(total_time * 0.0, false, vec2(0),   math.identity)
	self:lerp_scale(total_time * 0.3, true,  vec2(1.5), math.ease_out)
	self:lerp_scale(total_time * 0.7, true,  vec2(1),   math.smoothstep)
	return self
end
function graphics_lerp:bounce_in(total_time, scale)
	total_time = total_time or 0.1; scale = scale or 1.2
	self:lerp_offset(total_time * 0.0, false, vec2(0, 1), math.identity)
	self:lerp_offset(total_time * 1.0, true,  vec2(0, 0), math.ease_out)
	self:lerp_scale(total_time * 0.0, false, vec2(0),     math.identity)
	self:lerp_scale(total_time * 0.3, true,  vec2(scale), math.ease_out)
	self:lerp_scale(total_time * 0.7, true,  vec2(1),     math.smoothstep)
	return self
end
function graphics_lerp:bounce_out(total_time) --[[ scale 1.2→0.6→0 + slide ]] end
function graphics_lerp:ease_in(total_time)  --[[ scale 0→1 ease_in ]] end
function graphics_lerp:ease_out(total_time) --[[ scale 1→0 ease_out ]] end
function graphics_lerp:slide(total_time, x_from, y_from, x_to, y_to) --[[ offset linéaire ]] end
function graphics_lerp:wiggle(total_time, distance)
	total_time = total_time or 0.2; distance = distance or 2
	self:lerp_scale(total_time * 0.3, true, vec2(1.2), math.smoothstep)
	self:lerp_scale(total_time * 0.7, true, vec2(1),   math.smoothstep)
	return self
end
-- bobbing au survol, sans tween (lit element.hovered_time) :
function graphics_lerp:hovered_wiggle(element)
	if element.hovered then
		local f = mathx.remap_range_clamped(element.hovered_time, 0, 0.2, 0, 1)
		lg.translate(0, -2 * f)
		lg.translate(0, f * math.sin(TIME() * math.tau))
	end
	return self
end
```

**Usage typique** (bouton qui apparaît + réagit au clic) :
`glerp = require("src.graphics_lerp")():bounce_in()` puis dans `draw` `self.glerp:dynamic_push()`
… `self.glerp:pop()`, et au clic `self.glerp:clear(); self.glerp:wiggle()`.

### 5.3 Transitions d'écran (`src/screen_transition.lua`) — intégral des dessins

Machine à états avec trois styles : **wipe diagonal cisaillé**, **fade**, **blink** (paupière
triangulée). Chaque transition a deux phases (out → wait → in) avec callbacks `waiting`/`ready`.
Configuré dans `main.lua` : `{ wipe_time = 0.25, fade_time = 0.3 }`.

```lua
local function _draw_wipe(f)
	local shear_amount = -0.5
	local w, h = display:dimensions()
	tw = w * (1 + math.abs(shear_amount))
	local fringe_size = 100
	lg.push("all")
	lg.shear(shear_amount, 0)                 -- ★ cisaillement = diagonale
	local a = math.clamp01((1 - math.abs(f)) * 2)
	lg.setColor(0, 0, 0, a)
	lg.rectangle("fill", f * tw, 0, tw, h)
	lg.setColor(0, 0, 0, a * 0.5)             -- frange semi-transparente devant
	lg.rectangle("fill", f * tw - fringe_size, 0, tw + fringe_size * 2, h)
	lg.pop()
end

local function _draw_fade(f)
	local w, h = display:dimensions()
	lg.push("all"); lg.setColor(0, 0, 0, f); lg.rectangle("fill", 0, 0, w, h); lg.pop()
end

local function _draw_blink(f)
	f = math.ease_inout(math.clamp01(math.lerp(-0.5, 1.2, f)))
	local w, h = display:dimensions()
	lg.push()
	lg.setColor(0.03, 0, 0, math.clamp01(math.lerp(1.3, 0, f)))
	lg.translate(0, h/2)
	local shift_out = 1000 * f
	local polys = sequence{
		sequence{ vec2(-shift_out, h * 2), vec2(-shift_out, 0) },
		sequence{},
		sequence{ vec2(shift_out + w, 0), vec2(shift_out + w, h * 2) }
	}
	local res = 50
	for i = 1, res-1 do
		local p_f = math.ease_inout(i / res)
		local e_f = math.pingpong(p_f)
		e_f = math.ease_out(e_f)
		local v = vec2(math.lerp(-shift_out, shift_out + w, p_f), math.lerp(0, h * f, e_f))
		polys[2]:push(v)
	end
	polys = love.math.triangulate(polys:collapse():map_call("pack"):collapse())
	for y = -1, 1, 2 do                       -- miroir haut/bas = paupière
		lg.push(); lg.scale(1, y)
		for _, v in ipairs(polys) do lg.polygon("fill", v) end
		lg.pop()
	end
	lg.pop()
end
```

La machine (`state_machine`) : `wipe_out → wait → wipe_in → ready`, idem fade/blink. API
publique : `wipe_out(cb)`, `wipe_in(cb)`, `fade_out/in`, `blink_out/in`, `sudden_black(cb)`.
`done()` = état `ready`/`waiting`. **Reproduire :** le wipe diagonal = un rectangle noir
plein écran **avec `lg.shear`** qui glisse de `f*tw` ; la frange à 50 % d'alpha adoucit le
front. Le blink triangule une "paupière" qui se ferme avec un profil `pingpong+ease`.

### 5.4 `wipe_spotlight.lua` — projecteur dramatique sur les dés

Quand un événement "wipe" menace, le jeu **assombrit tout**, **grise les dés non concernés**,
**cache l'UID** et fait apparaître des **bandes letterbox** en `smoothstep`.

```lua
local function set_dim(dimmed)
	for _, entry in ipairs(to_dim) do
		entry.sprite.colour = dimmed and {0.25, 0.25, 0.25, 1} or entry.original
	end
end
set_dim(true)
-- cache toute l'UI : v.enabled = false (et restaure dans e.remove)
e:add({ draw_order = -120, draw = function(self)
	lg.push("all"); lg.origin(); lg.setBlendMode("alpha", "alphamultiply")
	lg.setColor(0, 0, 0, 0.75)
	local w, h = love.graphics.getDimensions()
	lg.rectangle("fill", 0, 0, w * 3, h * 3)
	lg.pop()
end })
e:add({ draw_order = 20000,
	update = function(self, dt)
		if leaving then leave_t = math.clamp01(leave_t + dt / bar_duration); if leave_t >= 1 then e:destroy() end
		else bar_timer = math.clamp01(bar_timer + dt / bar_duration) end
	end,
	draw = function(self)
		local w, h = display.width_scaled, display.height_scaled
		local bar_h = h * 0.2
		local t = leaving and leave_t or bar_timer
		local ease = t * t * (3 - 2 * t)                  -- smoothstep
		local p = leaving and (1 - ease) or ease
		lg.setColor(0, 0, 0, 1)
		lg.rectangle("fill", 0, math.lerp(-bar_h, 0, p), w, bar_h)
		lg.rectangle("fill", 0, math.lerp(h, h - bar_h, p), w, bar_h)
	end })
```

### 5.5 `ripple.lua` — onde d'eau (impact sur l'eau)

Joue un son de goutte, dessine une **ellipse qui grandit et s'efface**, et émet
sporadiquement des paillettes d'eau additives en bord d'onde.

```lua
return function(k, pos)
	audio:play_now(table.pick_random({"water_drop", "water_drop_2", "water_drop_3"}))
	local ghost = k:entity()
	ghost:add({
		fade_speed = love.math.random(4, 12) / 100,
		pos = pos:copy(), radius = 5, alpha = 0.2, draw_order = -991,
		update = function(g, dt)
			g.radius = g.radius + 20 * dt
			g.alpha = g.alpha - g.fade_speed * dt
			if g.alpha <= 0 then ghost:destroy() end
			if love.math.random() < 0.03 then
				-- … émet 1 particle water_sparkle additive en bord d'ellipse
			end
		end,
		draw = function(g)
			lg.setColor(1, 1, 1, g.alpha * 1.2)
			lg.ellipse("line", 0, 0, g.radius * 1.65, g.radius * 1.01)
			lg.setColor(0, 0, 0, g.alpha)
			lg.ellipse("line", 0, 0, g.radius * 1.6, g.radius)
		end,
	})
end
```

Astuce de lisibilité : **deux ellipses** (une claire légèrement plus grande, une sombre)
créent un liseré qui se lit même sur fond chargé.

### 5.6 `explosion.lua` — le combo "tout en même temps"

L'effet de référence : screenshake + repousse/saute les dés + particules étoiles + flash
plein écran + bump displacement + onde displacement animée + cercle de flash additif +
faisceau optionnel. Verbatim (extraits clés) :

```lua
return function(k, args)
	local pos = args.pos
	local strength = args.strength or 1
	local screenshake_base = args.screenshake ~= nil and args.screenshake or 15
	-- … flash/hop/push/beam bases
	local uipos = k.camera:world_to_ui(pos)

	if screenshake_base > 0 then k.camera.screenshake:trigger(screenshake_base * strength, 0.5) end

	-- hop and push dice (avec falloff radial)
	if k.state and k.state.player_dice then
		k.state.player_dice:foreach(function(v)
			if not v.dice then return end
			local offset = v.dice.pos:vsub(pos); local dist = offset:length()
			local falloff = math.clamp01(1 - dist / (300 * strength))
			if falloff > 0 then
				if hop_base > 0 then v.dice:hop(hop_base * strength * falloff) end
				if push_base > 0 then
					local dir = dist > 0 and offset:normalise() or vec2:polar(1, love.math.random() * math.tau)
					v.dice.vel:fmai(dir, push_base * strength * falloff)
				end
			end
		end)
	end

	-- particules étoiles + glitter
	local splashed = particle.splash(k, {
		count = math.floor(20 * strength), base = particle.configs.star,
		config = { pos = pos:copy(), pos_offset = {20 * strength}, vel = {500 * strength, vec2(0, 0)}, acc = vec2(0, 400) },
	})
	splashed:foreach(function(p)
		p.sprite.colour = { math.random_lerp(0.5, 1), math.random_lerp(0.5, 1), math.random_lerp(0.5, 1), 1 }
		p.sprite.blendmode = {"add", "alphamultiply"}
		p:add(require("src.behaviours.glitter")({ particle = p.particle, sprite = p.sprite, rgb_range = {0.5, 1.0}, alpha_range = {1, 1} }))
	end)

	-- flash plein écran (UI) qui fond
	local overlay_e = k:entity()
	overlay_e:add_from_system("ui", { timer = 0, duration = 0.3, order = 9999,
		update = function(self, dt) self.timer = self.timer + dt; if self.timer >= self.duration then overlay_e:destroy() end end,
		draw = function(self)
			local t = math.clamp01(self.timer / self.duration)
			lg.setColor(1, 1, 1, (1 - t) * flash_base * strength)
			lg.rectangle("fill", 0, 0, display:dimensions_scaled())
		end })

	-- displacement : bump immédiat + onde animée via coroutine async
	displacement:bump({ pos = uipos, radius = 150 * strength, amount = 100 * strength })
	k.systems.async:call(function()
		local duration = 0.6; local start = TIME()
		while true do
			local t = math.clamp01((TIME() - start) / duration)
			displacement:ripple({ pos = uipos, radius = t * 400 * strength, scale = vec2(1, 1), amount = (1 - t) * 15 * strength, offset = 0.7 })
			if t >= 1 then break end
			async.stall()
		end
	end)

	-- cercle blanc additif qui grandit (ralentit à la fin)
	local flash = k:entity()
	flash:add({ pos = pos:copy(), timer = 0, duration = 0.2, radius = 100 * strength, draw_order = 9000,
		update = function(self, dt) self.timer = self.timer + dt; if self.timer >= self.duration then flash:destroy() end end,
		draw = function(self)
			local t = math.clamp01(self.timer / self.duration)
			local alpha = (1 - t) * (1 - t)        -- ease-out alpha
			local r = self.radius * (t * 0.7)
			lg.setBlendMode("add", "alphamultiply")
			lg.setColor(1, 1, 1, alpha); lg.circle("fill", 0, 0, r)
			lg.setBlendMode("alpha", "premultiplied")
		end })
	-- + beam optionnel (rectangle additif vertical)
end
```

**Leçon de juice :** un seul "événement" déclenche **7 effets simultanés** sur des durées et
courbes différentes (0.2 à 0.6 s), tous **proportionnels à `strength`** et **avec falloff
radial** sur les voisins. C'est ce stacking qui donne l'impression de puissance.

### 5.7 La micro-vie du dé (`src/entities/dice.lua`)

Même au repos, un dé n'est jamais figé. Dans son `update` (extrait) :

```lua
-- breathing : respiration permanente
local breathing_speed = self.impatient and 1 or 0.25
local breathing = 1 + math.sin(TIME() * math.tau * breathing_speed) * 0.02

-- movement stretch : étirement selon la vitesse (squash & stretch)
local sensitivity = 0.0003
local stretch_x = math.abs(self.vel.x) * sensitivity
local stretch_y = math.abs(self.vel.y) * sensitivity
local stretch_z = math.abs(self.z_vel) * sensitivity
stretch_x = math.clamp(stretch_x, 0, 0.5); stretch_y = math.clamp(stretch_y, 0, 0.5); stretch_z = math.clamp(stretch_z, 0, 0.5)
local scale_x = breathing + stretch_x - (stretch_y + stretch_z) * 0.8   -- conservation de volume
local scale_y = breathing + (stretch_y + stretch_z) - stretch_x * 0.8
self.sprite.scale:sset(scale_x, scale_y)
self.sprite.scale:vmuli(self.sprite_scale_extra or vec2(1.2))

-- impact bop (pulse additif, décroît vite)
local pulse = self.pulse_scale or 0
self.sprite.scale:saddi(pulse, pulse)

-- hover scale (lerp doux quand survolé)
local hover_target = e.click_toggle.hovered and 0.08 or 0
self._hover_scale = math.lerp(self._hover_scale or 0, hover_target, 40 * dt)
self.sprite.scale:saddi(self._hover_scale, self._hover_scale)

-- lift quand sélectionné + rebond
if self.selected and not self.rolling then
	self.sprite.pos:saddi(0, -math.abs(math.sin(TIME() * math.tau)) * 3)
	self.sprite.scale:saddi(0.05, 0.05)
else
	self.sprite.pos:saddi(0, -math.abs(math.sin(TIME() * math.tau * 0.25)) * 2)  -- petit bob permanent
end
```

`impact_pulse` (déclenché à chaque rebond/impact) cumule **3 effets** : pulse de scale +
micro-screenshake + bump de displacement :

```lua
impact_pulse = function(self, strength)
	self.pulse_scale = strength or 0.3
	k.camera.screenshake:trigger(0.1, 0.1)
	local uipos = k.camera:world_to_ui(self.sprite.pos)
	require("src.shaders.displacement"):bump({ pos = uipos, radius = 80, amount = (strength or 0.3) * 40 })
end,
hop = function(self, z_vel)
	audio:play_now(table.pick_random({"hop_1", "hop_2"}))
	self.sprite.angle = self.sprite.angle + math.random_lerp(-0.1, 0.1)
	self.z_vel = z_vel or 500
	self:impact_pulse((self.z_vel / 500)^2 * 0.3)
end,
```

`text_pop` = un nombre flottant jaune qui monte et fond (pattern réutilisé partout) :

```lua
text_pop = function(self, txt)
	local ghost = k:entity()
	ghost:add({ pos = self.sprite.pos:copy(), alpha = 1, draw_order = 1000,
		update = function(g, dt) g.pos.y = g.pos.y - 40 * dt; g.alpha = g.alpha - 2 * dt; if g.alpha <= 0 then ghost:destroy() end end,
		draw = function(g)
			lg.setColor(1,1,0,g.alpha); display:set_font("ui",14)
			display:print_shadowed(txt, -150, 0, 300, "center")
		end })
end,
```

`select` joue un son **dont le pitch monte** avec le nombre de dés déjà sélectionnés
(`pitch = 1 + selected_count * 0.1`) → feedback musical de combo. Effets d'état additionnels
(non exhaustif) : auras pulsantes pour "impatient"/"cycle"/"multi-score" (ellipses sin),
**jitter nerveux** quand impatient (`self.sprite.pos:saddi(random, random)`), réflexion au sol
(sprite miroir avec alpha fading selon z), ombre qui rétrécit avec l'altitude.

### 5.8 `coloured_text.lua` — coloration auto des mots-clés

Parse une string et **colorie automatiquement** les mots mécaniques (`bust`→rouge,
`points`→cyan, `coins`→jaune, …), peut colorier le **nombre qui précède** (`number_before`),
et supporte des **balises `$couleur`** inline. Squelette :

```lua
local colours = require("src.game_colours").text_colours
local special_words = {}
special_words["bust"]   = { colour = colours.red, number_before = true }
special_words["points"] = { colour = colours.cyan, number_before = true }
special_words["coins"]  = { colour = colours.yellow, number_before = true }
special_words["power"]  = { colour = colours.green }
special_words["shield"] = { colour = colours.light_blue, word_before = {"bust"} }
-- … (≈30 mots-clés)

function coloured_text(text)
	local current_colour = {lg.getColor()}
	local previous, previous_number = false, false
	text = sequence(text:split("\n")):stitch(function(line)
		line = sequence(line:split(" ")):map(function(v)
			if v:starts_with("$") then                       -- balise couleur explicite
				local lookup = v:sub(2)
				current_colour = lookup == "clear" and {lg.getColor()} or colours[lookup]
				return {current_colour}
			end
			local word = v:match("[^%p]+") or v
			local match = special_words[word:lower()]
			local result = {match and match.colour or table.copy(current_colour), v}
			table.push(result, " ")
			if match and match.number_before and previous_number then previous_number[1] = result[1] end
			-- … (word_before, suivi du nombre courant)
			previous_number = false
			if v:match("[+-]?[%d%.%-]+") then previous_number = result end
			previous = result
			return result
		end):collapse()
		line:push("\n"); return line
	end)
	text:pop()
	return text   -- table {color, string, color, string, …} → consommable par lg.print
end
```

Le résultat est une **table colorée** que LÖVE sait imprimer (`lg.print({color, str, …})`).
Combiné à `display:print_shadowed` / `print_outlined`, ça donne des descriptions d'items où
chaque mot-clé a sa couleur **sans markup manuel**.

---

## 6. UI / UX

### 6.1 Le système d'interaction (`src/systems/ui.lua`)

Un `ui_system` (behaviour-système) gère une `set` d'`ui_element`. Chaque élément a un
`click_type` (`aabb`/`rect`/`circle`/`flood`/`custom`), un `pos`, et des callbacks
`hover/unhover/click/unclick`. Points de feel notables :

- **Détection par ordre de dessin inverse** (le plus au-dessus capte d'abord) ;
  `break` sur le premier non-`noclip` → pas de clic à travers.
- **`press_started`** : un clic n'est validé que si le *press* a commencé **sur** l'élément
  (`just_pressed(1)` pose `press_started`, `just_released(1)` + `press_started` → `clicked`).
  ⇒ **glisser depuis l'extérieur sur un bouton ne le déclenche jamais.**
- **Sons automatiques** : au survol → `audio:play_now(v.hover_sound or "hover")` ; au clic →
  `"select"` ; et un `"click"` global sur tout `just_pressed(1)`.
- **`hover_anim`** standard = bob sinusoïdal :

```lua
function ui_element:hover_anim(args)
	if self.hovered then
		lg.translate(0, 1 + math.sin(TIME() * math.tau * 2))
		-- (+ déplacement du curseur soft en mode manette)
	end
end
```

- Navigation **manette** complète (focus + liens `nav_left/right/up/down`, dessin des glyphes
  de boutons A/B/X/Y/start/back en vectoriel).

Extrait de la boucle de hover/clic (desktop) :

```lua
for i, v in ripairs(self.all:values_readonly()) do
	if v.visible and v.click_type and v:mouse_over(mouse_pos) then
		v.hovered = true; v.hovered_time = v.hovered_time + dt
		v.mouse_pos:vset(mouse_pos)
		if v.pos then v.mouse_delta:vset(mouse_pos):vsubi(v.pos) end
		if input.mouse:just_pressed(1) then v.press_started = true end
		if input.mouse:just_released(1) and v.press_started then v.clicked = true end
		self.any_hovered = true
		if not v.noclip then
			if v.has_click and not v.suppress_sound then self.hovered_with_audio = true end
			self.hovered = true; break
		end
	end
end
```

### 6.2 Boutons (`src/entities/buttons_clump.lua`)

Les boutons Score/Roll illustrent le pattern complet : **état logique → couleur**,
**scale lerp au press**, **glerp bounce au clic**, **taille de police qui grossit au press**,
tooltip contextuelle, et même un **affichage de probabilité de bust** au survol du bouton Roll.

```lua
e:add_named_from_system("ui", "roll_button", {
	click_type = "aabb",
	pos = …, halfsize = button_halfsize:copy(), order = 100,
	glerp = require("src.graphics_lerp")():bounce_in(),   -- apparition
	scale = 1,
	update = function(self, dt)
		-- calcule roll_state ("selected"/"blank"/"all"/"inactive") depuis l'état du jeu
		if input.keyboard:just_pressed("r") then self:click() end
	end,
	draw = function(self)
		local active = self.roll_state ~= "inactive"
		local is_pressed = active and self.hovered and input.mouse:pressed(1)
		local target_scale = is_pressed and 1.1 or 1
		self.scale = math.lerp(self.scale, target_scale, 0.1)     -- lerp doux vers la cible
		self.glerp:dynamic_push()
		if self.hovered and active then self:hover_anim() end
		lg.scale(self.scale)
		lg.setColor(colour.unpack_argb(active and 0xFFFF42AA or 0xff1a3a45))
		lg.rectangle("fill", -hw, -hh, hw*2, hh*2, 4, 4)
		local font_size = is_pressed and 17 or 15                  -- police qui grossit au press
		display:set_font("ui", font_size)
		display:print_shadowed(label, -hw, -font_size/2, hw*2, "center")
		-- warn_bust : liseré rouge qui clignote (sin) si risque
		self.glerp:pop()
		-- tooltip + panneau de probas au survol
	end,
	click = function(self)
		self.glerp:clear(); self.glerp:wiggle()                    -- punch au clic
		-- … applique le roll
	end,
})
```

Couleurs **par état** (`0xff50D3F2` score prêt, `0xff2A8FAA` "select all", `0xffAA8F2A`
"deselect", `0xff1a3a45` inactif) : la **couleur encode l'action disponible**, jamais juste
décorative.

### 6.3 Tooltips et cartes d'item (`src/ui/tooltip.lua`, `src/ui/item_hover.lua`)

`tooltip.post(k, text, x, y)` convertit le point local courant en espace UI absolu via
`lg.transformPoint` puis publie un event `tip` ; un élément dédié les dessine en fin de frame
(ordre 5000). **Détail clé** : la tooltip **enregistre un masque d'aberration chromatique**
sur sa propre zone pour rester lisible :

```lua
local sx, sy = lg.transformPoint(x + w/2, y + h/2)
require("src.shaders.chromab"):add_rect_mask({ pos = vec2(sx, sy), size = vec2(w, h) * 2 })
```

`item_hover.draw` fait pareil et utilise `coloured_text(desc)` + `print_outlined` pour le
titre (contour 8 directions) — voir §6.5.

### 6.4 Pickers modaux (`choice_pick.lua`, `dice_pick.lua`, `power_ui.lua`)

`choice_pick` (boutique) et `dice_pick` (échange de dés) instancient un fond sombre
(`ui.dark_background`) + une grille de boutons `aabb` qui publient un event au clic. Les dés à
échanger sont de **vrais dés animés** (sprite "tumble" en boucle) dessinés dans le bouton.

`power_ui` montre un pattern d'**indicateur de charge** : des cercles verts/rouges qui
s'illuminent uniquement sur les charges qui seraient dépensées au survol :

```lua
local hover_lit = hovered and i <= used and i > used - charge_cost
local fill_charged
if hover_lit and available then fill_charged = {0.7, 1, 0.7, 1}
elseif hover_lit and not enough_charge then fill_charged = {1, 0.2, 0.2, 0.9}
else fill_charged = {0.40, 1.00, 0.40, 0.75} end
```

### 6.5 Texte stylé : titres "annonce" (`src/entities/announce_img.lua`)

Le titre d'annonce (ex. "WIPE", "LAST TURN") superpose un **contour 8 directions** puis une
**pile de 3 couches colorées décalées** (ombre violette / rose / crème) — donne ce relief
"affiche" lisible :

```lua
display:set_font("title", font_size); lg.getFont():setFilter("linear", "linear")
-- contour : 8 offsets, couleur violet sombre
for _, off in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{1,-1},{-1,1},{1,1}}) do
	lg.setColor(0.16, 0.06, 0.38, self.alpha)
	display:printf(self.text, tx + off[1], ty + off[2], tw, "center")
end
-- 3 couches décalées en Y
for _, cfg in ipairs({ {0xff2a1060, 4}, {0xffdd4499, 2}, {0xfff0c09e, 0} }) do
	local cr, cg, cb = colour.unpack_argb(cfg[1])
	lg.setColor(cr, cg, cb, self.alpha)
	display:printf(self.text, tx, ty + cfg[2], tw, "center")
end
```

`display:print_outlined` (dans `display.lua`) généralise ce contour 8 directions (4 cardinaux
+ 4 diagonales normalisées) ; `display:print_shadowed` fait l'ombre portée standard. **Le jeu
n'imprime quasiment jamais de texte "plat"** — toujours ombré ou contouré.

L'**alpha de l'annonce s'éteint en `^5`** (`local lerp = (self.timer/self.time)^5`) → reste
plein longtemps puis disparaît vite. Pattern récurrent pour "lire puis dégager".

---

## 7. Particules

Le jeu **n'utilise pas `love.graphics.newParticleSystem`** : il a son propre système
(`src/entities/particle.lua`) où **chaque particule est une entité** avec un sprite animé +
physique simple. Avantages : contrôle total (rebond, scale, glitter, fake-roll), même pipeline
de tri/draw que le reste.

### 7.1 Configs et fabrique

```lua
particle.configs = {
	speck  = { texture = assets.particle_speck,  layout = vec2(5, 1), start_frame = vec2(0,0), frames = 5, time = {0.2, 1} },
	star   = { texture = assets.particle_star,   layout = vec2(7, 1), start_frame = vec2(0,0), frames = 7, time = {0.2, 1} },
	star_cyan / star_pink / eye / speck_purple / speck_green / water_sparkle / line = { … },
	dice_gib = { texture = assets.dice_gibs, layout = vec2(8, 5),
		start_frame = function() return vec2(love.math.random(0,7), love.math.random(0,4)) end,
		frames = 1, time = {2, 10}, bounce = true, bounce_random_frame = true, scale_over_time = true, fake_roll = true },
}
```

`particle.raw(k, args)` crée l'entité, calcule un **vecteur initial circulaire**
(`circular_vector` = point dans un disque via `sqrt(random)`), pose un sprite + une animation
non bouclée, et un behaviour `particle` qui **intègre vel/acc** et expire au bout de `time` :

```lua
update = function(self, dt)
	self.vel:fmai(self.acc, dt)         -- v += a·dt
	self.pos:fmai(self.vel, dt)         -- p += v·dt
	self.sprite.pos:vset(self.pos)
	self.sprite.order = self.draw_order or self.sprite.pos.y
	if self.time then
		self.timer = self.timer + dt
		if self.timer >= self.time then e:destroy() end
	end
end,
time_factor = function(self) return math.clamp01(self.timer / self.time) end,
```

Modificateurs optionnels (composables via `args`) :
- **`scale_over_time`** : `scale = ease_out(1 - lerp(0,2,time_factor))` (grossit puis rétrécit).
- **`fake_roll`** : `angle += direction * dt * vel:length()` (tourne proportionnellement à la
  vitesse → illusion de roulis).
- **`bounce`** : physique de hauteur `z` avec gravité, restitution `0.5`, **arrêt plastique**
  sous 10 u/s, et changement de frame aléatoire au rebond (gibs).

`particle.splash(k, {count, base, config})` = boucle qui overlaye `config` sur `base` pour
émettre `count` particules.

### 7.2 Le scintillement (`src/behaviours/glitter.lua`)

Behaviour ajouté à une particule pour la faire **scintiller** (couleurs random vives) puis
**se calmer** vers une plage en fondu. Donne le côté "magie pailletée".

```lua
return function(args)
	return {
		p = args.particle, s = args.sprite, glitter = not args.particle,
		rgb_range = args.rgb_range or {0.5, 1.0}, alpha_range = args.alpha_range or {0.2, 0.5},
		update = function(self, dt)
			if self.p then
				local tf = self.p:time_factor()
				if tf > 0.75 then self.glitter = false                        -- s'éteint en fin de vie
				elseif tf < 0.4 and love.math.random() < 0.01 then self.glitter = not self.glitter end  -- "pop" aléatoire
			end
			if self.glitter then
				for i = 1, 3 do self.s.colour[i] = math.random_lerp(0.2, 1) end
				self.s.colour[4] = love.math.random() < 0.9 and 0.2 or 1
			else
				local change_rate = math.clamp01((self.particle and self.particle.vel:length() or 1.0) * 0.1 * dt)
				for i = 1, 3 do self.s.colour[i] = math.lerp(self.s.colour[i], math.random_lerp(table.unpack2(self.rgb_range)), change_rate) end
				self.s.colour[4] = math.lerp(self.s.colour[4], math.random_lerp(table.unpack2(self.alpha_range)), change_rate)
			end
		end,
	}
end
```

### 7.3 Émetteurs ambiants

`random_sparklies.lua`, `water_sparklies.lua`, `unlock_sparklies.lua` : un behaviour qui, à
chaque frame, **émet une particule avec probabilité `spawn_rate`** (≈0.1) à une position
aléatoire de l'écran, en blend additif, avec glitter. Différences : direction (montée pour
"unlock", chute pour l'eau), couleurs, durée de vie. Tous suivent le même squelette :

```lua
update = function(self, dt)
	if love.math.random() < self.spawn_rate then
		local p = particle.raw(k, table.overlay({}, particle.configs.speck, {
			pos = vec2(math.random_lerp(-1,1)*0.5, math.random_lerp(-1,1)*0.5):smuli(display:dimensions_scaled()),
			pos_offset = {20}, vel = {200}, acc = vec2(0, math.random_lerp(1,-1)*20), time = {5, 10},
		}))
		p.sprite.colour = { math.random_lerp(0.5,1), math.random_lerp(0.5,1), math.random_lerp(0.5,1), math.random_lerp(0.2,0.5) }
		p.sprite.blendmode = {"add", "alphamultiply"}
		p:add(require("src.behaviours.glitter")({ particle = p.particle, sprite = p.sprite, rgb_range = {0.5,1.0}, alpha_range = {0.2,0.5} }))
	end
end
```

### 7.4 Le sprite de base (`src/behaviours/sprite.lua`)

Toutes les particules (et dés, pickups…) dessinent via ce behaviour : un quad dans une
spritesheet (`frame`×`framesize`), **blend mode par défaut `{"alpha","premultiplied"}`**,
support shader+uniforms, pivot/offset/angle/scale. Dessin centré sur la frame :

```lua
lg.draw(self.texture, _q,
	self.offset.x + self.pivot.x, self.offset.y + self.pivot.y, self.angle,
	self.scale.x, self.scale.y,
	self.framesize.x / 2 + self.pivot.x, self.framesize.y / 2 + self.pivot.y)
```

---

## 8. Audio (feedback)

`src/audio/init.lua` est un mixer maison au-dessus des `Source` LÖVE. Concepts clés pour le
feedback :

### 8.1 Canaux de mix et variation

```lua
local default_mix_channels = {
	master = {volume = 0.9}, music = {volume = 0.4}, ambient = {volume = 0.3},
	sfx = {volume = 0.9}, ui = {volume = 1.0},
}
local default_variation = {
	pitch  = {1.00, 1.00},   -- plage [min,max] → random
	volume = {1.00, 1.00},
	offset = {0.0, 0.0},     -- décalage de départ dans le sample
	priority = audio.priority_med, effects = true,
}
```

`play_now(filename, override_variation, fresh)` applique la variation (pitch/volume/offset
aléatoires dans la plage), clone la source si `fresh` (permet le chevauchement), et gère la
**priorité** :

```lua
function audio:apply_variation(cfg, source, variation)
	source:setPitch(math.random_lerp(table.unpack2(variation.pitch)))
	source:setVolume(audio:_get_config_volume(cfg) * math.random_lerp(table.unpack2(variation.volume)))
	local offset = math.random_lerp(table.unpack2(variation.offset))
	if offset > 0 then source:seek(offset * source:getDuration(), "seconds") end
	if variation.effects then self:apply_effects(source) end
end
```

### 8.2 Pitch qui monte sur les répétitions (feel "combo")

C'est l'astuce audio la plus copiable. Au ramassage d'étoiles (`src/entities/pickup.lua`),
un **compteur partagé** fait monter le pitch à chaque ramassage rapproché, et se reset après
2 s :

```lua
local star_pickup_count = 0
local star_pickup_last_time = 0
-- dans collect() :
local now = TIME()
if now - star_pickup_last_time > 2 then star_pickup_count = 0 end
star_pickup_last_time = now
local pitch = 1 + star_pickup_count * 0.03
audio:play_now(table.pick_random({"star_pickup_1","…"}), { pitch = {pitch, pitch} })
star_pickup_count = star_pickup_count + 1
```

Idem à la sélection de dés (`pitch = 1 + selected_count * 0.1`). ⇒ Une rafale d'actions
**monte en gamme** musicalement.

### 8.3 Plafond de voix prioritaires et son positionnel

- `add_prioritised_source` plafonne à **8 sources prioritaires** ; au-delà, il stoppe la voix
  la moins prioritaire (priorité + ancienneté). Évite la bouillie sonore lors des gros combos.
- `play_positional` / `set_positional` spatialisent les SFX mono (pan/atténuation selon la
  position monde, `position_scale = 40`).
- Variantes aléatoires omniprésentes : `audio:play_now(table.pick_random({"crack_1","crack_2","crack_3"}))`
  pour ne jamais répéter exactement le même son.

### 8.4 Sons branchés sur les events

L'UI (§6.1) joue automatiquement `"hover"` au survol, `"select"` au clic, `"click"` sur tout
press. Les entités jouent leurs sons dans leurs méthodes (`hop`→"hop_1/2", `take_damage`→
"punched_oof"+"crack", `ripple`→"water_drop", `explosion`→via screenshake, etc.). Le curseur
soft joue même `"hover"` quand on scrolle. **Règle implicite : toute interaction physique a un
son, souvent randomisé et/ou re-pitché.**

---

## 9. Ce qu'on vole pour The Pit

Techniques concrètes, classées par rapport effort/impact, avec mode d'emploi.

### 9.1 La carte de déplacement `rg32f` partagée (★ priorité absolue)
**Quoi :** un canvas `rg32f` plein écran où n'importe quel système "tape" des bosses/ondes
additives, qui s'estompe de 10 %/frame, lu par un shader final `uv += disp/dim`.
**Appliquer :** créer `src/fx/displacement.lua` (copier la structure de §4.9). Brancher un
`:bump()` sur : pose/drag d'un monstre sur le plateau, impact d'attaque en combat, clic de
bouton, ouverture de modale. Un seul système → tout l'écran "réagit" physiquement. C'est
**l'effet signature** de DHNE et le plus transversal.

### 9.2 Stacker 5-7 effets proportionnels par "événement"
**Quoi :** une explosion = screenshake + flash + particules + bump + onde + cercle additif +
push des voisins, tous scalés par `strength` et avec falloff radial (§5.6).
**Appliquer :** pour un "gros coup" en combat (mort d'une créature, coup critique), écrire une
fabrique `impact(k, {pos, strength})` qui déclenche le combo. Varier durées (0.2–0.6 s) et
courbes pour que ça ne "flashe" pas d'un bloc.

### 9.3 Screenshake qui tourne + pilote l'aberration chromatique
**Quoi :** `camera:push` applique le shake en **rotation + translation** (§5.1), et
`chromab_scale = shake:amount() * 0.2` (§3.2).
**Appliquer :** copier `screenshake.lua` tel quel (amplitude lerp-vers-0, trigger fusionnant).
Lier l'intensité d'un éventuel shader d'aberration à `shake:amount()`. Donne un punch
"déchirure couleur" gratuit à chaque secousse.

### 9.4 La micro-vie permanente des entités (breathing + squash&stretch + hover-scale)
**Quoi :** même au repos, scale = `1 + sin(TIME*…)*0.02` ; étirement selon la vélocité avec
conservation de volume ; `_hover_scale` lerpé à 40·dt ; lift + rebond quand sélectionné (§5.7).
**Appliquer :** ajouter ces ~10 lignes dans l'update des cartes/créatures de The Pit. Coût
nul, transforme des sprites "morts" en êtres vivants. Le `lerp(self.scale, target, 0.1)` au
press des boutons (§6.2) est le même principe côté UI.

### 9.5 Le tween chaînable `graphics_lerp` + presets bounce/wiggle
**Quoi :** une pile de lerps avec attente en cascade et courbe par segment ; presets
`bounce_in`, `wiggle`, `slide`, `hovered_wiggle` ; `dynamic_push` s'auto-update (§5.2).
**Appliquer :** copier `graphics_lerp.lua`. L'utiliser pour : apparition des cartes (bounce_in),
punch au clic (`clear():wiggle()`), entrées/sorties de panneaux (slide). Remplace tout besoin
d'une lib de tween externe.

### 9.6 Le color-key + motifs scrollés pour recolorer sans assets (shader du dé)
**Quoi :** une palette indexée par `if tex == colour_key[i]` qui remappe vers un dégradé +
motif animé par face ; magenta = contour (§4.15). Idem `void.lua`, `colour_rotation.lua`.
**Appliquer :** pour les afflictions/rangs de créatures de The Pit, color-key les zones
"variables" du sprite et les remapper par shader (poison=vert, burn=orange…) au lieu de
multiplier les spritesheets. Aligne avec la philosophie "tags canoniques + petits nombres".

### 9.7 Coloration auto des mots-clés (`coloured_text`)
**Quoi :** un parseur qui colorie `Poison`/`Burn`/`Shield`/nombres selon un dico, + balises
`$couleur`, produisant une table imprimable par LÖVE (§5.8).
**Appliquer :** brancher sur les descriptions de cartes/reliques de The Pit. The Pit a déjà
`tags.lua` + un glossaire ; un `coloured_text` garantit que chaque tag mentionné apparaît dans
sa couleur canonique **sans markup manuel**. Synergie directe avec la règle "icon+couleur+nom".

### 9.8 Masques d'aberration locaux pour garder l'UI lisible
**Quoi :** le shader chromab accepte 4 masques rect/cercle ; tooltips et cartes enregistrent
leur zone pour s'en exclure (§4.4, §6.3).
**Appliquer :** si The Pit ajoute un post-process global (aberration/blur), exposer une API
`add_rect_mask` et la faire appeler par la TCG monster card / tooltips pour qu'elles restent
nettes. Évite le compromis "joli mais illisible".

### 9.9 Audio : pitch montant sur rafales + variantes randomisées + plafond de voix
**Quoi :** compteur partagé qui monte le pitch sur actions rapprochées (reset après 2 s) ;
`pick_random` de 3 samples par event ; cap à 8 voix prioritaires (§8.2, §8.3).
**Appliquer :** pour les chaînes d'actions de The Pit (combo de combat, achats en boutique),
faire monter le pitch d'un SFX de base. Quasi gratuit, lit "progression" à l'oreille.

### 9.10 Curseur logiciel ultra-juicé (`soft_cursor`)
**Quoi :** un curseur dessiné main, qui s'incline selon la vélocité, s'étire (squash&stretch),
cligne des yeux, pulse au clic (glerp), et **tape des bumps de displacement** au clic/scroll/
maintien clic droit (§5.x, `soft_cursor.lua`).
**Appliquer :** si The Pit veut un curseur thématique (griffe/rune), reprendre : tilt =
`lerp(tilt, clamp(mouse_dx*0.02))`, stretch selon `|dx|/|dy|`, `glerp:clicked()` au press, et
un `displacement:bump` au clic. C'est ce qui fait que **le pointeur lui-même se sent vivant**.

---

### Annexe — valeurs de tuning de référence (`src/tweaks.lua`)

```lua
shader_default_amounts = {
	chromab = 1,        -- multiplicateur d'aberration (× screenshake*0.2 dynamique)
	scanlines = 0.7,
	bulge = 0.05,
	screenshake = 0.7,  -- multiplicateur global d'amplitude
}
```

Toutes ces valeurs sont **exposées en accessibilité** (`SAVE.accessibility.chromab/scanlines/
bulge/screenshake_scale`, `fast_anim`, `no_bg_scroll`, `no_tips`) → leçon transversale :
**chaque effet de juice doit avoir un curseur d'intensité réductible à 0** pour l'accessibilité
et le confort.
