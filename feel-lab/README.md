# THE PIT — FEEL LAB

> Mini-projet LÖVE **autonome et isolé** pour expérimenter le **feel/feedback (UX/UI)** et l'**enrobage
> inter-scènes** sans toucher au jeu principal. DA copiée (palette Wraeclast + 4 voix typo + `Feel`), zéro
> dépendance aux fichiers du jeu — aucun risque de conflit avec un autre chantier en cours.

## Lancer

```sh
love feel-lab                 # depuis la racine du dépôt
love feel-lab --shoot         # capture chaque écran en PNG (save dir/shots/) puis quitte
```

Navigation : **Esc** = retour/ferme · **F11** = plein écran · **drag** les sigils · **clique tout**.

---

## Le diagnostic (ce qu'on corrige)

Deux problèmes distincts, confirmés en lisant le code du jeu :

1. **« Les interfaces semblent mortes en interactivité. »** `src/ui/feel.lua` est un bon moteur de juice
   (hover/press/action différée) **mais** : ses hooks **son sont vides**, il **n'émet ni scale, ni tilt, ni
   drag**, et il n'y a **aucun screen-shake / hitstop**. Le « bonbon sucré » des refs (Balatro, Tiny Rogue,
   Dead Cells) vient de l'**empilement de canaux** (anim + scale + son + shake) à chaque interaction.

2. **« On a l'impression d'un autre programme à chaque écran. »** `main.lua:host.goto()` est un **swap
   brutal** (zéro transition), et les vues spéciales (fin de combat, Chronicle, relicpick) sont **3 patterns
   distincts**. Il manque : des **transitions**, une **pile de modales unifiée**, et un **shell persistant**.

---

## Les propositions (toutes jouables, comparables)

### A. Feel d'interaction — room « Interaction Feel »
- **Profils comparables en direct** : `Grimdark (0.2)` ↔ `Balanced (0.6)` ↔ `Balatro (1.0)` règlent l'intensité
  du « candy » (scale/tilt) → tu **juges le feeling** sans recompiler.
- **Boutons** : hover (lift + glow + punch de scale) · press (squash + flash + overshoot) · **son** (pitch ±5-8 %).
- **Drag & drop à la Balatro** : spring découplé `vel = vel*0.75 + (target-pos)*0.25` + **tilt par vélocité**
  (inclinaison « tissu dans le vent ») + lift/ombre au pickup + **snap amorti** au socket + son pickup/drop.
- **Strike** : démo **screen-shake `trauma²`** (Eiserloh/Vlambeer, via `love.math.noise`) + **hitstop** + son grave.
- **Number-roll** : score qui **roule** + **échelle de pitch montante** (C-D-E-F-G) = le payoff dopaminergique.

### B. Transitions de scène — room « Scene Transitions »
9 techniques jouables en plein écran entre 2 maquettes (BUILD ↔ COMBAT), durée réglable :
`fade_black` · `crossfade` · `dissolve (noise)` · `burn (ember edge)` · `slide ‹/›/^` · `iris (circle)` · `pixelate`.
**Reco** : build↔combat = **fade-through-black** (+ vignette de tension) ou **dissolve/burn** (grimdark) ;
menu↔codex = **slide** directionnel (renforce le « back »).

### C. Modales & enrobage — room « Modals & Popups » + shell global
- **Une seule pile de modales** (`modalstack`) : tout pop-up **dim le fond**, **gèle** la scène, **capte
  l'input**, et entre/sort avec la **même chorégraphie** (backdrop puis panel scale 0.94→1 courbe *back*).
  Types : `confirm` (neutre / danger), `banner` VICTORY/DEFEAT (cérémonial), `toast` (non-bloquant).
- **Shell persistant** (`shell`) : barre de titre (fil d'Ariane) + bouton retour homogène + pied, dessinés
  **autour** de la scène changeante → **mêmes pixels de chrome partout** = sensation « un seul jeu ».

### D. Son procédural — `synth` + `sfx` + room « Sound Design »
SFX d'UI **synthétisés** (cohérent « zéro asset ») : ondes + ADSR + glissando + **detune/drive/crush/lp/sub/vib**
+ `squelch()` (humide) + `cavern()` (réverb-Puits), joués via `clone()` + **pitch jittré**. Câblés sur
`Feel.onPress/onHover` → le son arrive **sans toucher une scène**.
**5 packs comparables** (room « Sound Design », sélecteur + volume + audition de chaque son) :
- **Oneiric** *(défaut)* — **onirique/doux/réverbéré** : sine & cloches, **attaques douces** (swells, pas de
  transitoire claquant), passe-bas chaud, **reverb diffuse** (Freeverb : combs + allpass), **zéro drive/crush/bruit**
  → atmosphérique, sûr même à fort volume (réponse au « trop percutant/déchirant »).
- **Grimdark** — donjon/pierre : grave, mat, **descendant**, saturé léger (plus dur).
- **Visceral** — humide/chair : `squelch`, gargouillis, succion (dégueulasse).
- **Nightmare** — arcane : désaccordé, **dissonant** (triton/seconde mineure), drones.
- **Candy** — sinus aigus, clairs, ascendants : la réf « trop intense ».
> On échange une **ambiance entière** sans toucher l'UI (mêmes noms de vocabulaire, recettes différentes).
> Recherche sourcée : `docs/04-research-sound-grimdark.md`.

### E. Architecture composants (ta question) — `behavior` + `widgets`
Le jeu a **déjà** des composants : tes modules `Component.draw(rect, opts)` en **immediate-mode** (le bon
paradigme pour un jeu — pas besoin de classes ni d'ECS). Ce qui manquait = des **effets réutilisables
attachables**. `lib/behavior.lua` les fournit : des **behaviors purs** (`hoverable`, `pressable`, `pulsable`,
`shakeable`, `draggable`) posés au-dessus de `Feel`/`Juice` et **composés** avec `compose()`. C'est l'équivalent
LÖVE de tes hooks/directives web : **un effet = une fonction réutilisable, attachée par composition, zéro
duplication**. `lib/widgets.lua` montre des composants (`button/card/toggle/panel`) qui les consomment.

---

### F. Level-Up / Fusion — room « Level-Up » + `levelup` + `particles`
L'animation **multi-étapes « ta-ta-ta-TAAA »** quand on combine 3 copies pour monter un monstre de niveau
(règles réelles du jeu : 3 copies même id+niveau → niveau+1, cap 3, **cascade**, cf. `docs/05-merge-mechanics.md`).
Structure (recherche §06) : anticipation → **convergence staggerée** (âmes en arc, ease-in, traînée) → **impacts**
rythmés (pitch montant via `SFX.ladder` + micro-shake + pulse = les « ta ») → **climax** « TAAA » (flash +
onde de choc + burst radial 20-30 + squash-stretch + **screen-shake trauma²** + **hitstop** + pip pop, **tout
synchro <50ms**) → settle. **3 styles comparables** : **Burst** (arc + gros burst, le plus sûr) · **Orbit**
(spirale qui implose, grimdark) · **Slam** (micro-hitstop par arrivée, le plus scandé). Gère les **3 origines**
(plateau / banc / **carte boutique** avec anticipation d'aspiration) et la **cascade** (escalade façon TFT
rank-up, climax « big » au palier final). Recherche : `docs/06-research-levelup-animation.md`.
> Le jeu a **déjà** une anim de base (`build.lua:spawnMergeFx`, 2 âmes + burst, sans son/shake/rythme) ; ceci
> en est la version riche. Portage : brancher sur ce **point d'entrée unique** (tous les merges y passent) en
> lui passant `{sources+positions, target, toLevel, big}`.

### G. Particules pixel + surcouche shader — `particles` + `sprite` + `postfx`
Les particules **ne sont plus des primitives lisses** (cercles/traits AA = « cheap ») : ce sont des **sprites
pixel bakés** (`sprite.bake` grille ASCII + palette → Image nearest), **snappés à la grille-monde** (×4), au
**fondu par RAMPE de palette** (frames discrètes, pas alpha lisse), **rotation par paliers 90°**, glow additif
sur les cœurs seulement. Types : ember (braise montante) · shard (éclat or/os) · ash (cendre) · spark · mote ;
onde de choc en **chunks pixel ébréchés**. Couleurs **palette Wraeclast** (rampes burn/bleed/bone/gold).
Et surtout : la **surcouche shader « cauchemardesque »** (`postfx`, portée du jeu) blite TOUTE la frame à
travers **dither Bayer 4×4 + grain + palette-lock (ombres→abysse, hautes→braise) + vignette + aberration
chromatique** → c'est CE qui unifie le look « clean, semi-net, semi-pixélisé ». **[F9]** la bascule (comparer).
Recherches : `docs/07-research-pixel-vfx.md`, `docs/08-pixel-pipeline-postfx.md`.

## Carte des fichiers

```
feel-lab/
  conf.lua · main.lua            config + orchestrateur (shell+pile+transition+modales+toasts+shake/hitstop)
  lib/
    palette.lua  theme.lua       DA copiée du jeu (couleurs Wraeclast + 4 voix typo)  [verbatim]
    feel.lua                     moteur de juice copié du jeu (hover/press/float/hooks son)  [verbatim]
    draw.lua                     helpers de rendu (lean, sans dépendance Frame)
    juice.lua      ★ NOUVEAU     canaux « candy » : punch de scale (ressort), tilt, screen-shake trauma², hitstop
    behavior.lua   ★ NOUVEAU     behaviors composables (hoverable/pressable/pulsable/shakeable/draggable + compose)
    widgets.lua    ★ NOUVEAU     composants immediate-mode (button/card/toggle/panel) consommant les behaviors
    synth.lua      ★ NOUVEAU     synthèse SFX (ondes/ADSR/glissando/detune/drive/crush/lp/sub/vib/squelch/cavern)
    sfx.lua        ★ NOUVEAU     directeur de son : 4 PACKS (candy/grimdark/visceral/nightmare) + pitch jitter + hooks Feel
    scenestack.lua ★ NOUVEAU     pile de scènes (switch/push/pop + enter/leave/pause/resume)
    transition.lua ★ NOUVEAU     transition manager multi-techniques (canvas + blend ; shaders pcall-gardés)
    modalstack.lua ★ NOUVEAU     pile de modales unifiée (dim + gel + chorégraphie entrée/sortie)
    modals.lua     ★ NOUVEAU     fabrique de modales (confirm/banner/toast)
    shell.lua      ★ NOUVEAU     chrome persistant (« un seul jeu »)
    particles.lua  ★ NOUVEAU     particules PIXEL (sprites bakés nearest, snap grille, rampe-par-frame, rot 90°, ring chunky)
    sprite.lua     ★ NOUVEAU     bake pixel (grille ASCII + palette → Image nearest) — pour les sprites de particules
    postfx.lua     ★ NOUVEAU     surcouche shader « cauchemardesque » (dither Bayer 4×4 + grain + palette-lock + vignette + chroma) [F9]
    levelup.lua    ★ NOUVEAU     moteur d'animation de FUSION multi-étapes (3 styles + cascade + origines board/banc/shop)
  rooms/
    menu · interaction · sound · transitions · modals · levelup    les 6 ateliers
  docs/  01-research-gamefeel.md  02-research-architecture.md  03-research-components-sfx.md
```

---

## Porter dans le vrai jeu (incrémental, faible risque — cf. `feedback-ui-fullscreen-no-carved-frame`)

Tout est **RENDER pur** (dt mural, jamais le RNG seedé) → **zéro impact** sur le firewall SIM / déterminisme /
golden. Ordre suggéré, chaque étape validable au screenshot :

1. **Son (gain immédiat, risque nul)** : porter `synth.lua` + `sfx.lua` → `src/audio/`, appeler `SFX.load()`
   dans `main.love.load`. Câble `Feel.onPress/onHover` (hooks **déjà présents** dans `src/ui/feel.lua`). +
   s'abonner au **bus** (`src/core/bus.lua`) pour les events de combat. Garde headless `if not (love and love.sound) then return end`.
2. **Behaviors** : porter `behavior.lua` → `src/ui/behavior.lua`. Migrer progressivement `Button.draw` & co
   pour lire `B.compose(...)` (au lieu de relire `feel.lift/squash` à la main). DRY + effets attachables.
3. **Juice étendu** : porter `juice.lua` → `src/ui/juice.lua`. Brancher le **screen-shake** sur les gros events
   de combat (mort/coup lourd) via le bus, et le **hitstop** au pas-fixe (`love.run`) en scalant le `dt` de RENDER.
4. **Transitions** : porter `transition.lua` → `src/render/transition.lua`. Dans `main.lua`, faire passer
   `host.goto(name, payload, {transition=...})` par le manager (snapshot + swap à mi-course). Garder le swap
   immédiat par défaut (compat).
5. **Modales + shell** : porter `modalstack.lua` + `shell.lua`. **Absorber `host.overlay`** (Chronicle) dans la
   pile, passer la fin de combat et les confirmations en **modales** (plus de scènes séparées). Hisser le HUD
   (orbe de vie, or, reliques) dans le `Shell` → unité visuelle.

---

## Sources (vérifiées)
Game-feel : Eiserloh GDC « Juicing Your Cameras With Math » (trauma shake) · « Juice it or lose it »
(Jonasson/Purho) · « Art of Screenshake » (Vlambeer) · repros Balatro (Tom Delalande, Mostly Mad, Mix and Jam).
Archi LÖVE (APIs wiki 11.5 vérifiées) : `newCanvas`/`setCanvas`/`setBlendMode(premultiplied)`/`stencil`/`Shader:send` ·
hump.gamestate/roomy (pile) · pushdown-automata UI. Son : `love.sound.newSoundData`/`SoundData:setSample`/
`Source:setPitch`/`clone` · sfxr.lua. Détail dans `docs/01..03`.
