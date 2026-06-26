# Feel Lab — Recherche #2 : Navigation / Transitions / Modales (LÖVE 11.5)

> APIs LÖVE vérifiées sur love2d.org/wiki (cible 11.5). Tout est **RENDER pur** (dt mural) → zéro impact
> déterminisme/golden/firewall SIM.

## État des lieux (jeu actuel)
- `main.lua:host.goto(name)` = **swap brutal** (remplace `host.scene`, aucune transition). Certaines scènes
  mémoïsées, d'autres recréées.
- `host.overlay` = **slot d'overlay UNIQUE** (la Chronique) : embryon de pile à 1 niveau, qui **gèle** déjà la
  scène (`love.update` fait `return` si overlay). Briques prêtes : `ui/modal.lua`, `ui/nav.lua`, `ui/feel.lua`
  (action différée = déjà « sentir le clic avant que l'écran change »).
- Conclusion : **pas besoin de lib externe**. Il manque (1) une **pile** au lieu du swap, (2) un
  **TransitionManager** sur canvas, (3) un **shell** persistant.

## 1. Pile de scènes (stack-based gamestate)
Pattern de référence (hump.gamestate / roomy, MIT) :
- `switch(to)` → remplace le sommet : `leave(old)` + `enter(new)`. (= flux : build→combat)
- `push(to)` → empile SANS détruire le dessous : `pause(current)` + `enter(new)`. **C'est exactement un
  modal/overlay** : la scène dessous reste vivante mais gelée.
- `pop()` → `leave(top)` + **`resume`** la révélée (PAS `enter` → état préservé : scroll/sélection).
> roomy sur push : *"does not call leave() on the previous state — useful for pause menus."* → **un modal = un push.**

**Le « back » est gratuit** = `pop()`. Distinguer **navigation hiérarchique** (push/pop : menu→codex→retour)
de **remplacement de flux** (switch : build→combat, on ne « revient » pas). Piège : ne jamais `switch/pop` au
milieu d'un `update` qui itère encore (différer en fin de frame ; l'action différée de `Feel` fait déjà ça).
Implémentation lab : `lib/scenestack.lua` (array + ipairs, déterministe).

## 2. Transitions (capture-and-blend sur Canvas)
Principe : **snapshot** la frame sortante dans un canvas, basculer la scène, puis chaque frame rendre
l'entrante (live) dans un 2e canvas et **interpoler** par `progress ∈ [0,1]`.
- APIs : `love.graphics.newCanvas` (créer **une fois**, pas par frame) · `setCanvas` · blit d'un canvas =
  `setBlendMode("alpha","premultiplied")` (sinon halos sur bords transparents) · `stencil`/`setStencilTest`
  (iris sans shader) · `newShader`/`Shader:send` (dissolve/pixelate).
- Capturer la **frame finale native** (post-UI), pas le monde → évite les 2 chemins de rendu (canvas virtuel
  vs nativeWorld) et reste net (`setFilter("nearest")`).
- **Techniques** (toutes dans `lib/transition.lua`) : `fade_black` (workhorse grimdark) · `crossfade` ·
  `slide_*` (direction spatiale) · `iris_in` (stencil) · `dissolve`/`burn` (shader bruit + lisière braise) ·
  `pixelate` (shader). Durées : in-game 150-300 ms, jamais >1 s.
- **Swap masqué** : pour `fade_black`, l'écran est noir à mi-course → le changement de scène n'est jamais vu brut.

## 3. Pile de modales unifiée
Un modal **n'est pas un cas spécial** : c'est un push qui (1) gèle le dessous, (2) dim le fond (voile
semi-opaque), (3) capte tout l'input (le sommet retourne « handled »), (4) s'anime entrée/sortie.
- Chorégraphie : backdrop dim **d'abord** → panel entre (scale 0.94→1 + fade, courbe *back*) ; fermeture =
  panel part **d'abord** → backdrop revient. Réutiliser la courbe `Feel.approach` (lissage exponentiel framerate-correct).
- **Toasts** = cas à part (non-bloquants, ne captent rien) : petite file rendue par-dessus tout, auto-expire.
- Implémentation lab : `lib/modalstack.lua` (+ `lib/modals.lua` confirm/banner/toast). **Absorbe `host.overlay`.**

## 4. Shell / chrome global (« un seul jeu »)
Une **couche persistante** dessinée **autour** de la scène changeante : même fond, même barre de titre (fil
d'Ariane), même bouton retour, même HUD (vies/or/reliques). Les scènes ne dessinent plus que **leur contenu**.
Dans `main.love.draw` : `Shell.drawBack → (transition ? transition:draw : scene:draw) → Shell.drawFront →
modals → toasts → postfx`. Le jeu a déjà les ingrédients (`fx/background`, `ui/frame`, `render/lifeorb`,
`ui/nav`, `postfx`) : le travail = les **hisser hors des scènes** dans un `Shell` unique (lab : `lib/shell.lua`).

## 5. Pièges LÖVE (vérifiés)
1. Aucun canvas actif quand `present` est appelé (la `love.run` du jeu appelle present en fin de draw → faire
   `setCanvas()` avant). 2. Premultiplied alpha pour tout blit de canvas. 3. **Bloquer l'input pendant une
   transition** (sinon double-switch). 4. `newCanvas` mémoïsé par (w,h), recréé seulement au resize. 5.
   Pixel-perfect : capturer la frame native + `nearest`. 6. **RENDER pur** : jamais faire dépendre une décision
   de gameplay du `progress`. 7. Headless-safe (no-op si `love.graphics` absent) pour garder `check.sh` vert.

## Architecture cible (4 petits modules RENDER-pur)
`scenestack.lua` · `transition.lua` · `modalstack.lua` · `shell.lua`, orchestrés dans `main.lua`
(`host.stack/modals/transition`, `host.goto(name, payload, {transition})`, `host.back()`). Incrémental :
pile + fade d'abord (valider), puis modales + shell.

Sources : hump.gamestate `github.com/vrld/hump` · roomy `github.com/tesselode/roomy` · ScreenWipeShader-Love
(Unlicense) · pushdown-automata UI (alamrafiul.com) · wiki : newCanvas/setCanvas/Canvas/setBlendMode/stencil/Shader:send.
