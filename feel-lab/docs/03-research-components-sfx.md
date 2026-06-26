# Feel Lab — Recherche #3 : Composants réutilisables & Son procédural

## PARTIE A — Architecture par composants

### Constat : le jeu A DÉJÀ des composants
Le pattern de `src/ui/` (`Panel.draw(x,y,w,h,opts) -> rect`) **est** de l'**IMMEDIATE-MODE GUI** : un fichier =
un module-table = un composant ; ils se composent par appel ; l'état d'anim est externalisé dans `Feel` ;
l'état visuel (hover/pressed) passe en `opts`. **C'est le bon paradigme pour un jeu** (l'UI est une pure
fonction de l'état → zéro désynchro, DRY par construction). La doc SUIT (vrld) : *« immediate mode is better
than retained mode for games. »*

### Ce qu'il NE faut PAS faire
- **Pas de lib UI externe** (SUIT/LoveFrames/Gspot) → on perdrait la DA procédurale (palette, `Draw`, `PostFX`).
- **Pas de lib de classes pour l'UI** (retained mode = régression). `rxi/classic` (MIT, 30 LOC, cohérent avec
  le style rxi du projet) **en réserve** seulement si un objet UI à état long apparaît (éditeur, inspecteur).
- **Pas d'ECS** (tiny-ecs/Concord) : ni UI (overkill pour ~10 widgets) ni SIM (le projet fait déjà de la
  composition-par-données : `u.dots` + `tickDots`, mieux pour le déterminisme).

### Le seul vrai manque : des EFFETS attachables (behaviors / traits / mixins)
Un behavior = une **fonction pure** `(id, rect, input) -> { dx, dy, glow, scale, rot, ... }` qui délègue l'anim
à `Feel`/`Juice` et renvoie un delta de transform. On les **compose** (somme des deltas) → un seul transform
avant de dessiner n'importe quel composant, **sans le modifier**. C'est l'équivalent LÖVE des hooks/HOC web.
Lab : `lib/behavior.lua` (`hoverable`/`pressable`/`pulsable`/`shakeable`/`draggable` + `compose`) ; `lib/widgets.lua`
montre des composants qui les consomment.

**Reco minimale (anti sur-ingénierie)** : garder l'IMGUI maison + ajouter `behavior.lua` (~60 lignes). C'est tout.

## PARTIE B — Son procédural (APIs vérifiées wiki 11.5)
- `love.sound.newSoundData(samples, rate, bits, channels)` → SoundData vide. `SoundData:setSample(i, v)`
  (i débute à **0**, v normalisé **-1..1**). Le wiki donne l'exemple sine/square officiel.
- `love.audio.newSource(sd, "static")` (toujours static depuis une SoundData) → `play/stop/setVolume`.
- **`Source:setPitch(p)`** : 1 = base, ÷2 = -1 octave, **0 illégal**. Resampling (change aussi la durée).
- **`Source:clone()`** : copie peu coûteuse à l'état stopped → **polyphonie** (préférer à `newSource`).
- **Le « candy » = pitch jittré ±5-10 %** à chaque play (`p = base + rand*±jitter`) → jamais deux clics
  identiques. Plus : random volume ±10 %, pool no-repeat. **Escalade/combo** = +1 demi-ton/cran (C-D-E-F-G).
- **Layering** : transient + body + sub-bass. Vocabulaire distinct hover≠click≠success≠error.
- **Firewall** : le son est **RENDER** — jamais sous `src/combat|board|effects|run`. Le brancher sur les
  **hooks `Feel.onPress/onHover`** (UI) + le **bus** (`src/core/bus.lua`, events de combat). Baker au boot
  (newSource lent), pas par frame. Garde headless : `if not (love and love.sound) then return end`.
- Lib optionnelle : **sfxr.lua** (nucular, MIT, Lua pur, 1 fichier) si on veut une banque variée ; sinon
  **synth maison ~70 lignes** (lab : `lib/synth.lua` + `lib/sfx.lua`).

Sources : love2d.org/wiki (newSoundData, SoundData:setSample, newSource, Source:setPitch/clone) · rxi/classic ·
SUIT (vrld) · tiny-ecs/Concord · mixins Lua (adonaac, ericjmritz) · sfxr.lua (nucular).
