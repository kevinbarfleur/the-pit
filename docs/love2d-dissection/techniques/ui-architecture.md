# Architecture UI — arbre de noeuds retained-mode, UI déclarative, layout auto, tooltips

> Comment Balatro construit *toute* son UI (menus, HUD, boutons, panneaux,
> tooltips, cartes) avec un seul système d'arbre de noeuds maison + des
> définitions déclaratives. C'est le modèle le plus pertinent pour donner à
> chaque écran de The Pit le même niveau de finition sans recâbler des positions
> à la main.

## 1. Retained-mode vs immediate-mode

Deux philosophies d'UI :

- **Immediate mode** (ex: SUIT, Slab, ImGui) : on (re)déclare l'UI chaque frame
  dans `draw`. Simple, mais peu d'animation/état persistant, layout limité.
- **Retained mode** (Balatro) : l'UI est un **arbre d'objets persistants** créé
  une fois ; on le modifie, on l'anime, on le détruit. Chaque noeud garde son
  état (hover, position eased, enfants). C'est ce qui permet le mouvement fluide
  et les tooltips persistants.

Balatro = retained-mode **maison**, sans lib tierce. La même hiérarchie
`Object → Node → Moveable` sert pour le gameplay ET l'UI.

---

## 2. Le socle : Node (arbre, transform, états, collision)

`engine/node.lua`. Chaque élément d'UI est un Node avec :

```lua
self.T = { x, y, w, h, r, scale }          -- transform en "game units" (pas en pixels)
self.container = args.container or G.ROOM  -- repère parent (translation/rotation héritée)
self.children = {}                          -- arbre
self.states = {
    visible = true,
    collide = {can=false, is=false},        -- testé pour le hit-test souris ?
    hover   = {can=true,  is=false},
    click   = {can=true,  is=false},
    drag    = {can=true,  is=false},
    focus   = {can=false, is=false},        -- navigation manette/clavier
}
```

### Dessin relatif au conteneur

`Node:translate_container` applique la transform du parent avant de dessiner. Donc
on positionne un élément **relativement à son panneau**, et déplacer le panneau
déplace tout. (C'est aussi le mécanisme du screenshake global — voir
`game-feel-juice.md`.)

### Hit-test qui gère la rotation

`Node:collides_with_point(point)` (`node.lua:143`) transforme le point dans
l'espace local (annule translation + rotation du conteneur et du noeud) puis fait
un test rectangle simple. Donc **un bouton incliné reste cliquable correctement**.
Détail clé : `local _b = self.states.hover.is and G.COLLISION_BUFFER or 0` agrandit
légèrement la zone cliquable d'un élément déjà survolé → évite le "flicker" de
hover quand le curseur est sur un bord (stickiness). À voler.

---

## 3. Le CONTROLLER : un seul gestionnaire d'input

`engine/controller.lua` unifie souris, clavier et manette. Chaque frame :

1. calcule la position du curseur (réel ou émulé manette) en game units ;
2. parcourt les noeuds `collide.can = true`, trouve la cible sous le curseur ;
3. met à jour les "targets" : `hovering.target`, `clicked.target`,
   `dragging.target`, `focused.target`, `released_on.target` ;
4. appelle les hooks correspondants : `Node:hover()`, `:stop_hover()`,
   `:click()`, `:drag()`, `:stop_drag()`, `:release(dragged)`.

Avantage : **un seul endroit** gère tout l'input, et n'importe quel noeud peut
réagir en surchargeant ces méthodes. Quand un noeud est détruit, `Node:remove`
nettoie toutes les références dans le CONTROLLER (`node.lua:319`) → pas de
pointeur mort.

---

## 4. L'UI déclarative : UIBox + définitions

C'est le coeur du confort. On décrit un panneau comme une **table imbriquée**
(du "HTML en Lua"), et `UIBox` (`engine/ui.lua`) le transforme en arbre de
noeuds avec layout calculé.

### Forme d'une définition

```lua
local def = {n=G.UIT.ROOT, config={align="cm", padding=0.1, r=0.1, colour=G.C.BLACK}, nodes={
    {n=G.UIT.R, config={align="cm", padding=0.05}, nodes={        -- Row (horizontale)
        {n=G.UIT.C, config={align="cm"}, nodes={                  -- Column (verticale)
            {n=G.UIT.T, config={text="Boutique", scale=0.6, colour=G.C.WHITE}},  -- Text
            {n=G.UIT.R, config={align="cm", minh=0.3}, nodes={ ... }},
        }},
        {n=G.UIT.O, config={object= maCarte}},                    -- Objet arbitraire (sprite/carte)
    }},
}}
local box = UIBox{ definition = def, config = { align="cm", major = G.ROOM, offset={x=0,y=0} } }
```

### Les types de noeuds (`G.UIT`)

| Type | Rôle |
|------|------|
| `ROOT` | racine du panneau (fond, padding, arrondi) |
| `R` | **Row** : aligne ses enfants horizontalement |
| `C` | **Column** : aligne ses enfants verticalement |
| `T` | **Text** (statique ou dynamique) |
| `O` | **Object** : insère un Moveable existant (carte, sprite, slider custom) |
| `B` | **Box** : rectangle/espaceur de taille fixe |
| `S` | Slider, et autres widgets |

### Le layout automatique (`UIBox:calculate_xywh`)

`ui.lua:118` calcule récursivement la taille de chaque noeud :
- une feuille (`B`, `T`, `O`) prend sa taille intrinsèque (texte mesuré, objet, dims) ;
- une **Row** somme les largeurs des enfants + paddings, prend la hauteur max ;
- une **Column** somme les hauteurs, prend la largeur max ;
- puis `set_wh` propage et `set_alignments` place chaque enfant selon son
  `align` (`c`=center vertical, `m`=middle horizontal, `t/b/l/r`=bords, `i`=inner).

> **Conséquence pratique** : on ne calcule **jamais** de coordonnées en pixels.
> On décrit la structure (rows/columns/padding/align) et tout se dimensionne et
> se centre seul, à n'importe quelle résolution. C'est un mini-flexbox.

### Mise à jour dynamique

Un noeud peut porter `config.func` (recalculé chaque frame) ou un `ref_table` +
`ref_value` pour afficher une valeur qui change (or, PV…). `UIBox:get_UIE_by_ID`
récupère un élément par son `config.id` pour le modifier après coup.

---

## 5. Tooltips automatiques (hover/drag popups)

Le plus élégant. Un noeud déclare simplement la définition de son tooltip :

```lua
config = {
    h_popup = create_my_tooltip_definition(card),  -- une définition d'UIBox
    h_popup_config = { align='tm', offset={x=0,y=-0.1} },
}
```

Et le moteur s'occupe du reste (`node.lua:267`) :

```lua
function Node:hover()
    if self.config and self.config.h_popup then
        if not self.children.h_popup then
            self.children.h_popup = UIBox{ definition = self.config.h_popup, config = self.config.h_popup_config }
            self.children.h_popup.states.collide.can = false
        end
    end
end
function Node:stop_hover()
    if self.children.h_popup then self.children.h_popup:remove(); self.children.h_popup = nil end
end
```

Le tooltip **naît au survol et meurt à la sortie**, sans aucune gestion manuelle
de visibilité/positionnement. `d_popup` fait pareil pendant un drag (ex: l'aide
qui suit une carte qu'on déplace).

> **Pour The Pit** : c'est exactement le pattern à adopter pour les tooltips de
> cartes/reliques/tags. Chaque carte déclare sa définition de glossaire ; le hover
> l'affiche. Plus de code de tooltip dispersé.

---

## 6. Boutons (callback par nom)

Un noeud cliquable porte `config.button = 'shop_buy'`. Au clic, le CONTROLLER
appelle `G.FUNCS.shop_buy(node)`. Les callbacks vivent tous dans `G.FUNCS`
(`functions/button_callbacks.lua`). Le feedback visuel (enfoncement, halo) vient
des états `hover.is`/`click.is` lus au moment du draw (on assombrit/agrandit selon
l'état). Pas de logique de rendu dans le callback.

Détail de feel (cf. `CLAUDE.md` de The Pit) : **feedback pointer-down immédiat,
action au release**. Balatro joue le SFX et l'enfoncement au `click`, exécute la
fonction au `release` sur la même cible → on peut "annuler" en relâchant ailleurs.

---

## 7. Texte vivant (`DynaText`, `engine/text.lua`)

`DynaText` est un Moveable spécialisé pour le texte animé :
- fait apparaître les lettres une à une (`pop_in`, délai par lettre) ;
- applique un `juice_up` par lettre (les chiffres de score qui "sautent") ;
- peut cycler une liste de chaînes (texte qui change : "Niveau 1" → "Niveau 2") ;
- gère couleur par segment, ombre, scale animé.

C'est ce qui rend les nombres et titres "vivants" plutôt que statiques. Pour The
Pit : score/dégâts/or qui montent avec un pop = adoption directe.

---

## 8. Plan de reproduction pour The Pit

The Pit a déjà un design system (Frame carved-stone, cartes TCG). Ce qu'on
importe de Balatro, par ordre de valeur :

1. **Transform en unités + dessin relatif au conteneur** (résolution-indépendant,
   screenshake/transitions gratuits).
2. **UI déclarative + layout row/column auto** : définir chaque panneau (shop,
   HUD, codex, bilan) comme une table de noeuds. Supprime tout le calcul de
   positions et harmonise l'aspect de tous les écrans.
3. **Tooltips automatiques par hover** (`h_popup`) pour cartes/tags/reliques.
4. **CONTROLLER unique** hover/click/drag/focus + nettoyage des références à la
   destruction + buffer de hover anti-flicker.
5. **DynaText** pour les nombres/titres animés.
6. **États lus au draw** pour le feedback (jamais de logique de rendu dans un
   callback de bouton).

> Garder nos frontières : cet arbre de noeuds vit **côté présentation** (`src/ui`,
> `src/render`). Il lit l'état de la SIM, ne le mute jamais.
