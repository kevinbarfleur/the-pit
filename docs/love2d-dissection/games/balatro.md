# Balatro — dissection visuelle LÖVE

> Le mètre-étalon du "juice" de carte en Love2D. Si un seul jeu de cette
> bibliothèque doit être étudié pour The Pit, c'est celui-là : nos cartes de
> monstres, notre feedback de hover/drag et nos effets d'édition (foil, holo)
> peuvent s'inspirer presque directement de son moteur.

Sources lues (extraites du `.love`) : `main.lua`, `conf.lua`, `game.lua`,
`globals.lua`, `card.lua`, `engine/object.lua`, `engine/node.lua`,
`engine/moveable.lua`, `engine/sprite.lua`, `engine/ui.lua`,
`resources/shaders/*.fs`.

Le **catalogue GLSL complet** des 19 shaders est dans
[`../techniques/shaders.md`](../techniques/shaders.md). Le **moteur d'animation
à ressorts** est détaillé dans
[`../techniques/game-feel-juice.md`](../techniques/game-feel-juice.md). Ce
document explique l'architecture qui relie tout ça.

---

## 1. Fiche technique

| Élément | Valeur |
|---------|--------|
| Moteur | LÖVE 11.x (fused exe `Balatro.exe`) |
| Langage | Lua 5.1 / LuaJIT |
| Fichiers Lua | ~47 (très compact) |
| Shaders | 19 fichiers `.fs` dans `resources/shaders/` |
| Architecture | Arbre de noeuds **retained-mode** maison (pas de lib UI tierce) |
| Coordonnées | "game units" : `pixels = unit * G.TILESCALE * G.TILESIZE` |
| Rendu | Tout passe par des **canvas** + un shader **CRT** plein écran |
| État global | un seul objet `G` (le "God object") contient tout |

Organisation des fichiers (commentée) :

```
main.lua              -- love.load/update/draw, boucle, gestion FPS fixe
conf.lua              -- config fenêtre LÖVE
globals.lua           -- définit G : couleurs, constantes, exp_times (ressorts)...
game.lua              -- LE coeur : chargement shaders, états (menu/jeu), draw global, CRT
card.lua              -- la carte (237 Ko) : logique + draw multi-passes + tilt 3D
cardarea.lua          -- conteneur de cartes (main, deck, joker row) avec layout auto
engine/
  object.lua          -- classe de base "class" minimaliste (extend/init)
  node.lua            -- Node : transform T, states hover/click/drag, collision, arbre
  moveable.lua        -- Moveable : T (cible) + VT (visible eased), ressorts, juice_up
  sprite.lua          -- Sprite : quad d'atlas + draw_shader (envoi des uniforms)
  animatedsprite.lua  -- sprites animés (frames)
  particles.lua       -- système de particules maison
  ui.lua              -- UIBox : construit un arbre de noeuds depuis une "définition" déclarative
  text.lua            -- DynaText : texte animé (lettres qui pop, défilent, changent)
  controller.lua      -- input unifié souris/clavier/manette, gestion hover/click/drag focus
  event.lua           -- EventManager : file d'événements/tweens temporisés
  sound_manager.lua   -- audio (thread séparé), pitch/volume par event
functions/
  UI_definitions.lua  -- (342 Ko) toutes les définitions déclaratives d'UI
  common_events.lua   -- helpers d'animation (ease_value, juice_card...)
  button_callbacks.lua-- callbacks des boutons
resources/shaders/    -- 19 shaders .fs
```

**À retenir pour The Pit** : Balatro n'utilise **aucune lib UI/animation tierce**.
Tout repose sur ~6 fichiers moteur très réutilisables. C'est exactement le genre
de socle qu'on peut recopier conceptuellement.

---

## 2. Architecture du code

### 2.1 La hiérarchie de classes

Balatro a un système de classes minimaliste (`engine/object.lua`, façon
`rxi/classic`). Toute la hiérarchie visuelle :

```
Object              -- :extend(), :init(), :is(), métatables
  └─ Node           -- transform T={x,y,w,h,r,scale}, states, collision, arbre d'enfants
       └─ Moveable  -- ajoute VT (visible transform eased) + physique de ressort
            └─ Sprite       -- quad depuis un atlas + draw_shader
                 └─ AnimatedSprite
            └─ Card         -- la carte de jeu (hérite Moveable)
            └─ CardArea     -- conteneur qui range ses cartes
            └─ UIBox / UIElement -- l'UI déclarative
```

> **Insight clé** : *tout* ce qui bouge à l'écran est un `Moveable`. Les cartes,
> les boutons, les panneaux, le curseur, même la "pièce" (ROOM) sont des noeuds.
> Un seul système d'animation gère donc tout le jeu.

### 2.2 Le système de coordonnées "game units"

Balatro ne travaille jamais en pixels dans la logique. Tout est en **unités de
jeu**. La conversion se fait au draw :

```lua
pixels = game_unit * G.TILESCALE * G.TILESIZE
```

Avantage : le jeu est résolution-indépendant. On change `TILESCALE` et toute
l'UI se met à l'échelle proprement. Les cartes font ~`1` unité de large peu
importe la taille d'écran.

### 2.3 Le conteneur (container) et le repère relatif

Chaque `Node` a un `container` (par défaut `G.ROOM`). Avant de se dessiner, un
noeud applique la transform de son conteneur (`Node:translate_container`,
`engine/node.lua:307`). Conséquence : on peut **secouer tout l'écran** (screen
shake), tourner ou décaler une zone entière en modifiant un seul conteneur,
sans toucher les objets enfants. C'est comme ça que le screenshake et les
transitions de "pièce" sont gratuits.

### 2.4 Les états d'interaction

`engine/node.lua:55` définit l'état standard de tout noeud :

```lua
self.states = {
    visible = true,
    collide = {can = false, is = false},
    focus   = {can = false, is = false},
    hover   = {can = true,  is = false},
    click   = {can = true,  is = false},
    drag    = {can = true,  is = false},
    release_on = {can = true, is = false}
}
```

Le `CONTROLLER` (souris/manette unifiés) parcourt les noeuds qui ont
`collide.can = true`, teste `collides_with_point`, et bascule `hover.is`,
`click.is`, etc. **Seuls les noeuds collidables sont testés** (réduit le O(n²)).

La collision gère la rotation (`engine/node.lua:143`) : un point est
re-transformé dans l'espace local du conteneur puis du noeud, donc un bouton
incliné reste cliquable correctement. À voler tel quel.

### 2.5 Popups par hover/drag (tooltips)

Élégant : un noeud déclare juste `config.h_popup` (définition d'UI) et le moteur
crée/détruit automatiquement le tooltip au survol (`engine/node.lua:267`
`Node:hover` / `Node:stop_hover`). Idem `d_popup` pour le drag. **C'est le
pattern de tooltip de The Pit à adopter** : pas de gestion manuelle, le tooltip
naît du hover et meurt à la sortie.

### 2.6 Le God object `G`

Tout vit dans `G` (défini dans `globals.lua` + `game.lua`) : `G.SHADERS`,
`G.MOVEABLES` (liste de tous les moveables à mettre à jour), `G.ROOM`,
`G.CONTROLLER`, `G.C` (couleurs), `G.FUNCS` (callbacks d'UI), `G.E_MANAGER`
(events), `G.TIMERS`, `G.SETTINGS`, etc. Pratique mais à doser : pour The Pit on
garde nos frontières SIM/PRESENTATION, mais le pattern "une table de registres
globaux pour la présentation" est OK côté rendu.

---

## 3. Pipeline de rendu & post-processing

Balatro **ne dessine jamais directement à l'écran**. Le flux (dans le `draw` de
`game.lua`) :

```
1. setCanvas(G.CANVAS)         -- on dessine TOUTE la scène (fond, cartes, UI, curseur)
2. setCanvas(G.AA_CANVAS)      -- on redessine G.CANVAS à travers le shader 'CRT'
       setShader(G.SHADERS['CRT'])
       draw(G.CANVAS, 0, 0)    -- => applique distorsion barrel + scanlines + bloom + aberration
3. setCanvas()                 -- retour à l'écran
       scale(1/G.CANV_SCALE)
       draw(G.AA_CANVAS)       -- blit final mis à l'échelle (anti-aliasing par sur-échantillonnage)
```

Code réel de l'étape 2 (`game.lua:2933`) :

```lua
love.graphics.setCanvas(G.AA_CANVAS)
love.graphics.push()
    love.graphics.setColor(G.C.WHITE)
    G.SHADERS['CRT']:send('distortion_fac', {1.0 + 0.07*G.SETTINGS.GRAPHICS.crt/100, 1.0 + 0.1*G.SETTINGS.GRAPHICS.crt/100})
    G.SHADERS['CRT']:send('scale_fac', {1.0 - 0.008*G.SETTINGS.GRAPHICS.crt/100, 1.0 - 0.008*G.SETTINGS.GRAPHICS.crt/100})
    G.SHADERS['CRT']:send('feather_fac', 0.01)
    G.SHADERS['CRT']:send('bloom_fac', G.SETTINGS.GRAPHICS.bloom - 1)
    G.SHADERS['CRT']:send('time', 400 + G.TIMERS.REAL)
    G.SHADERS['CRT']:send('noise_fac', 0.001*G.SETTINGS.GRAPHICS.crt/100)
    G.SHADERS['CRT']:send('crt_intensity', 0.16*G.SETTINGS.GRAPHICS.crt/100)
    G.SHADERS['CRT']:send('scanlines', G.CANVAS:getPixelHeight()*0.75/G.CANV_SCALE)
    love.graphics.setShader(G.SHADERS['CRT'])
love.graphics.draw(self.CANVAS, 0, 0)
love.graphics.pop()
love.graphics.setCanvas()
love.graphics.setShader()
```

Points à retenir :
- **`G.CANV_SCALE` = sur-échantillonnage** : la scène est rendue plus grande que
  l'écran puis réduite → anti-aliasing "gratuit" et pixel-art net.
- Le CRT est **optionnel et dosable** (slider `SETTINGS.GRAPHICS.crt`). Mettre
  l'intensité à 0 garde la distorsion barrel à ~0 mais le pipeline canvas reste.
- Le bloom est intégré DANS le shader CRT (boucle 7×7 d'échantillons au-dessus
  d'un cutoff de luminance). Voir le code complet dans
  [`../techniques/post-processing.md`](../techniques/post-processing.md).

### Le fond animé (`background.fs`)

Le fameux fond "peinture qui tourbillonne" du menu/jeu est un shader appliqué à
un simple rectangle plein écran. Il combine un **swirl** central (rotation de
l'angle polaire selon le rayon) et un **effet de peinture** (5 itérations de
`sin/cos` qui replient les UV), puis mélange 3 couleurs. Code complet dans
[`../techniques/shaders.md#balatro--background-fond-anime`](../techniques/shaders.md).
C'est l'effet le plus copié de Balatro ; il est entièrement procédural (aucune
texture).

---

## 4. Le système de shaders de carte (foil / holo / polychrome…)

C'est *la* signature visuelle de Balatro. Architecture en 3 couches :

### 4.1 Chargement (auto-discovery)

`game.lua:126` charge tous les `.fs` du dossier en table `G.SHADERS` :

```lua
self.SHADERS = {}
local shader_files = love.filesystem.getDirectoryItems("resources/shaders")
for k, filename in ipairs(shader_files) do
    if string.sub(filename, -3) == '.fs' then
        local shader_name = string.sub(filename, 1, -4)
        self.SHADERS[shader_name] = love.graphics.newShader("resources/shaders/"..filename)
    end
end
```

> Astuce reproductible : **convention par nom de fichier**. `foil.fs` →
> `G.SHADERS.foil`. Aucun enregistrement manuel.

### 4.2 Le contrat d'uniforms partagé

Chaque shader de carte expose les **mêmes uniforms de base** (envoyés par
`sprite.lua`), plus un uniform `vec2` au nom du shader (`foil`, `holo`,
`polychrome`…) qui porte ses paramètres animés. Les uniforms communs :

| Uniform | Rôle |
|---------|------|
| `dissolve` (number) | 0→1, progression de la dissolution/burn (mort de carte, achat) |
| `time` (number) | temps animé, **dérivé de l'ID de la carte** pour désynchroniser |
| `texture_details` (vec4) | position+taille du quad dans l'atlas (pour recalculer les UV locales) |
| `image_details` (vec2) | dimensions de l'atlas |
| `shadow` (bool) | passe d'ombre (rendu en noir, alpha réduit) |
| `burn_colour_1/2` (vec4) | couleurs de la flamme de dissolution |
| `mouse_screen_pos`, `hovering`, `screen_scale` | pour le **tilt 3D** au survol (vertex shader) |

### 4.3 L'envoi des uniforms (`sprite.lua:73` `draw_shader`)

```lua
function Sprite:draw_shader(_shader, _shadow_height, _send, _no_tilt, ...)
    local _draw_major = self.role.draw_major or self
    -- décale la position pour la passe d'ombre (parallaxe)
    if _shadow_height then
        self.VT.y = self.VT.y - _draw_major.shadow_parrallax.y*_shadow_height
        self.VT.x = self.VT.x - _draw_major.shadow_parrallax.x*_shadow_height
        self.VT.scale = self.VT.scale*(1-0.2*_shadow_height)
    end
    -- envoi des uniforms communs
    G.SHADERS[_shader]:send('mouse_screen_pos', self.ARGS.prep_shader.cursor_pos)
    G.SHADERS[_shader]:send('screen_scale', G.TILESCALE*G.TILESIZE*(_draw_major.mouse_damping or 1)*G.CANV_SCALE)
    G.SHADERS[_shader]:send('hovering', (_no_tilt) and 0 or (_draw_major.hover_tilt or 0))
    G.SHADERS[_shader]:send("dissolve", math.abs(_draw_major.dissolve or 0))
    G.SHADERS[_shader]:send("time", 123.33412*(_draw_major.ID/1.14212)%3000)  -- désync par ID
    G.SHADERS[_shader]:send("texture_details", self:get_pos_pixel())
    G.SHADERS[_shader]:send("image_details", self:get_image_dims())
    G.SHADERS[_shader]:send("burn_colour_1", _draw_major.dissolve_colours and _draw_major.dissolve_colours[1] or G.C.CLEAR)
    G.SHADERS[_shader]:send("shadow", (not not _shadow_height))
    if _send then G.SHADERS[_shader]:send(_shader, _send) end  -- l'uniform spécifique (ex: foil={r,g})

    love.graphics.setShader(G.SHADERS[_shader])
    self:draw_self()
    love.graphics.setShader()
    -- annule le décalage d'ombre
    ...
end
```

### 4.4 Le rendu **multi-passes** par carte (`define_draw_steps`)

Une carte holographique avec ombre, c'est plusieurs passes empilées
(`sprite.lua:56` + `:draw`) :

```lua
function Sprite:draw()
    if self.draw_steps then
        for k, v in ipairs(self.draw_steps) do
            self:draw_shader(v.shader, v.shadow_height, v.send, v.no_tilt, ...)
        end
    else
        self:draw_self()
    end
    for k, v in pairs(self.children) do v:draw() end
end
```

Une carte typique enchaîne : **passe ombre** (`dissolve` shader, `shadow=true`,
décalée) → **passe base** (`dissolve`, le sprite normal) → **passe édition**
(`foil`/`holo`/`polychrome`, en additif) → **passe sceau** (`gold_seal`).
Chaque passe = un `setShader` + un `draw`. C'est ce qui donne la profondeur.

### 4.5 Le tilt 3D au survol (le détail qui tue)

Le vertex shader partagé par tous les shaders de carte incline le quad vers le
curseur. Extrait (`foil.fs:130`) :

```glsl
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.) return transform_projection * vertex_position;
    float mid_dist = length(vertex_position.xy - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
    float scale = 0.2*(-0.03 - 0.3*max(0., 0.3-mid_dist))
                *hovering*(length(mouse_offset)*length(mouse_offset))/(2. - mid_dist);
    return transform_projection * vertex_position + vec4(0,0,0,scale);  // perturbe w → faux perspective
}
#endif
```

> Le truc génial : on perturbe la composante **w** du vertex (`+vec4(0,0,0,scale)`).
> Après division perspective, ça simule une inclinaison 3D de la carte **sans
> vraie matrice 3D**. Couplé à l'ombre parallaxée, la carte semble "se soulever"
> sous le curseur. **À voler absolument pour les cartes de monstres de The Pit.**

---

## 5. Animation & game feel — le moteur T/VT

Détaillé dans [`../techniques/game-feel-juice.md`](../techniques/game-feel-juice.md).
Résumé du principe (`engine/moveable.lua`) :

- Chaque Moveable a **`T`** (transform *cible*, ce qu'on veut) et **`VT`**
  (visible transform, ce qui est *réellement dessiné*). On ne touche jamais VT
  directement : on pose `T.x = nouvelle_position` et le moteur fait **easer VT
  vers T** chaque frame avec une physique de ressort-amortisseur :

```lua
function Moveable:move_xy(dt)
    self.velocity.x = G.exp_times.xy*self.velocity.x + (1-G.exp_times.xy)*(self.T.x - self.VT.x)*35*dt
    -- ... clamp à max_vel ...
    self.VT.x = self.VT.x + self.velocity.x
end
```

- **`juice_up(amount)`** : le squash-stretch iconique quand une carte se
  déclenche (un Joker qui marque, une main jouée). C'est un sinus amorti sur le
  scale ET la rotation :

```lua
function Moveable:juice_up(amount, rot_amt)
    self.juice = { scale = 0, scale_amt = amount, r = 0,
        r_amt = rot_amt or pseudorandom_element({0.6*amount, -0.6*amount}),
        start_time = G.TIMERS.REAL, end_time = G.TIMERS.REAL + 0.4 }
    self.VT.scale = 1 - 0.6*amount   -- "écrase" instantanément, puis rebondit
end
-- chaque frame :
self.juice.scale = scale_amt * sin(50.8*t) * max(0, ((end-t)/(end-start))^3)
```

- **Major/Minor** : les cartes d'une main sont des Moveable "Minor" soudés à un
  CardArea "Major". Bouger/incliner le Major déplace tous les enfants avec un
  offset, gratuitement.

C'est le système qui fait que **rien ne se téléporte jamais** dans Balatro :
tout glisse, rebondit, s'aligne en douceur.

---

## 6. UI / UX — l'UI déclarative (`engine/ui.lua` + `UI_definitions.lua`)

Balatro construit son UI à partir de **tables de définition déclaratives**
(comme du "HTML en Lua"), transformées en arbre de Moveables par `UIBox`.

Forme typique d'une définition (style) :

```lua
{n=G.UIT.ROOT, config={align="cm", padding=0.1, colour=G.C.BLACK, r=0.1}, nodes={
    {n=G.UIT.R, config={align="cm"}, nodes={                 -- une "Row"
        {n=G.UIT.C, config={align="cm"}, nodes={             -- une "Column"
            {n=G.UIT.T, config={text="Play", scale=0.5, colour=G.C.UI.TEXT_LIGHT}},  -- Text
            {n=G.UIT.B, config={w=2, h=0.5}},                -- Box (espaceur)
        }},
    }},
}}
```

- `G.UIT` = types de noeuds : `ROOT`, `R` (row), `C` (column), `T` (text),
  `B` (box), `O` (objet arbitraire : une carte, un sprite), `S` (slider)…
- `config` porte : alignement (`align="cm"` = center/middle), padding, couleur,
  arrondi `r`, fonctions `button`, `h_popup` (tooltip), `func` (update dynamique).
- Le layout est **automatique** : rows et columns se dimensionnent selon leurs
  enfants + padding (façon flexbox simplifié). On ne calcule jamais de pixels à
  la main.

Boutons : `config.button = 'name'` pointe vers `G.FUNCS.name`. Le CONTROLLER
appelle ce callback au clic. Le feedback visuel (enfoncement, surbrillance) est
géré par les états `hover.is`/`click.is` lus au draw.

> **Pour The Pit** : on a déjà des Frames/cartes. L'idée à importer est l'**UI
> déclarative** (définir un panneau comme une table de noeuds) + le **layout
> row/column auto-dimensionné**, ce qui supprime tout le calcul de positions
> manuel et rend l'UI résolution-indépendante.

### Texte animé (`engine/text.lua`, `DynaText`)

Les nombres qui montent, les lettres de score qui "poppent" une à une, le texte
qui change de couleur : c'est `DynaText`. Il gère une liste de chaînes, fait
apparaître les lettres avec un délai (`pop_in`), applient un `juice_up` par
lettre, et peut faire défiler/cycler le contenu. C'est ce qui rend les scores
"vivants".

---

## 7. Particules (`engine/particles.lua`)

Système maison léger : un `Particles` est un Moveable qui émet des sprites
(ou des points colorés) avec vitesse, durée de vie, gravité, fade. Utilisé pour
les étoiles du fond, la poussière, les confettis de victoire. Voir
[`../techniques/particles.md`](../techniques/particles.md) pour le pattern
générique. Balatro reste sobre : la plupart du "juice" vient du **mouvement des
cartes** (T/VT + juice_up), pas des particules.

---

## 8. Audio (feedback)

`engine/sound_manager.lua` tourne sur un **thread séparé**. Chaque son peut être
joué avec un **pitch** et un **volume** paramétrés. Détail crucial pour le feel :
quand plusieurs Jokers marquent en chaîne, le pitch du son de score **monte
progressivement** (chaque déclenchement incrémente le pitch), créant la montée
sonore satisfaisante. Le son est piloté par les events de combat, jamais par la
frame de rendu.

> **Pour The Pit** : associer un SFX à chaque déclenchement de capacité avec un
> **pitch croissant dans une chaîne** est un gain de feel énorme pour quasi rien.

---

## 9. Ce qu'on vole pour The Pit

1. **Système T/VT (cible vs visible eased)** — la base. On pose la position
   cible, le moteur ease. Plus aucune téléportation. → voir game-feel-juice.md.
2. **`juice_up()`** — squash-stretch amorti à appliquer sur tout déclenchement
   (capacité, dégâts, achat). Une ligne, énorme impact.
3. **Tilt 3D au hover via la composante w** — pour nos cartes de monstres. Effet
   "premium" pour ~15 lignes de GLSL.
4. **Passe d'ombre parallaxée** — redessiner le sprite décalé en noir/alpha
   réduit *avant* le sprite. Donne du relief instantané aux cartes.
5. **Shaders d'édition empilés (foil/holo/polychrome)** — pour marquer la rareté
   ou un statut (béni/maudit) d'un monstre. Code complet dans shaders.md.
6. **Dissolve/burn shader partagé** — une seule fonction `dissolve_mask` réutilisée
   par tous les shaders pour les transitions d'apparition/destruction de carte.
7. **Tooltips automatiques par hover (`h_popup`)** — le noeud déclare sa
   définition de tooltip, le moteur le crée/détruit. Zéro gestion manuelle.
8. **UI déclarative + layout row/column auto** — définir nos panneaux comme des
   tables de noeuds plutôt que des positions en dur.
9. **Pitch audio croissant dans une chaîne** — montée sonore satisfaisante.
10. **Pipeline canvas + post-process dosable** — rendre la scène sur un canvas
    sur-échantillonné, puis un shader plein écran optionnel (CRT/bloom léger).
```
