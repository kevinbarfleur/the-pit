# Vue d'ensemble comparative — 5 jeux LÖVE disséqués

> Synthèse technique transversale. Pour le détail d'un jeu, voir `games/<jeu>.md`.
> Pour reproduire un effet précis, voir `techniques/`.

## Tableau comparatif technique

| | **Balatro** | **Arco** | **Dice Have No Eyes** | **Moonring** | **Mudborne** |
|---|---|---|---|---|---|
| Genre | deckbuilder | tactical RPG | roguelike de dés | dungeon crawler | cozy sim |
| Version LÖVE | 11.x | **11.4** (JIT off) | 11.5 | 11.x | **12.0** |
| Taille `.love` | 85 Mo | 645 Mo | 21 Mo | 166 Mo | 84 Mo |
| Fichiers Lua | ~47 | ~2100 | ~190 | ~260 | ~200 |
| Moteur/archi | arbre de noeuds retained-mode maison | **ECS maison `ferris`** + `batteries` | `batteries` + micro-ECS `soup` | états + SpriteBatch maison | **moteur maison `tngine`** (façon GameMaker) |
| Résolution interne | unités de jeu (scalables) | pixel-art, upscale entier | scalée | **1280×721** fixe | **640×360** |
| Post-process | **canvas → CRT → écran** (1 shader tout-en-un) | léger | **canvas + displacement + CRT/juice** | **3 canvas → recolour → CRT** | **multi-canvas** + shaders d'ambiance |
| Shaders dédiés | 19 `.fs` | 6 inline (`shaders.lua`) | 15 (dossier `src/shaders`) | 13 `.fs` | 10 `.frag` |
| Signature visuelle | éditions de carte (foil/holo) + tilt 3D | pixel-art + ambiance/météo | **juice extrême** (shake→aberration, displacement) | palette 3 couleurs + CRT | eau/outline/jour-nuit par color-key |
| Particules | émetteur maison léger (carrés) | data-driven | système maison | **data-driven (146 défs)** | maison + météo |
| Audio | thread séparé, pitch chaîné | très riche (603 Mo ogg) | mix/variation/priorité | **musique tracker** `.xm/.it` | adaptatif (familles+variantes) |
| Auteur | LocalThunk | Max Cahill & coll. / Panic (éd.) | Maximilian Fegan | **Dene Carter** (co-créateur de Fable) | ellraiser / TNgineers |

## Signature technique de chaque jeu (ce qui le rend unique)

- **Balatro** — *le mouvement comme feel*. Système **T/VT** (cible vs visible eased)
  qui fait que rien ne se téléporte, `juice_up()` (squash-stretch amorti), et des
  **shaders d'édition empilés** avec un **tilt 3D au survol** (perturbation de la
  composante `w` du vertex). Tout passe par un pipeline canvas + CRT dosable.
- **Arco** — *l'ambiance pixel-art*. ECS maison `ferris`, rendu pixel-perfect
  upscalé en entier, parallaxe/météo/lumière, et un combat tactique simultané où
  chaque action a un **planner** (prévisualisation) lisible.
- **Dice Have No Eyes** — *le juice maximal*. Une **carte de déplacement `rg32f`
  partagée** où tout système (clic, impact, explosion, curseur) "tape" des ondes
  additives qui s'estompent ; des **combos d'événements** (7 effets simultanés
  scalés par la force) ; le **screenshake qui pilote l'aberration chromatique**.
- **Moonring** — *le look palette*. Encodage **3 couleurs** dans les assets
  (canal vert/rouge) remappé au runtime par un shader **recolour** HSL à
  luminosités fixes ; pipeline **3 canvas**, **CRT** final, particules data-driven,
  musique **tracker**.
- **Mudborne** — *le mini-moteur maison*. `tngine` (table globale `tn`, cadences
  `step`/`tick`/`tock`, tilemap à **canvas roulant**), rendu **multi-canvas**, et
  une famille de shaders d'ambiance pilotés par **color-keying** (couleurs pures
  = sémantique, possible grâce au `nearest` partout) : eau, glace, neige, nuit,
  outline, swap de palette.

## Patterns communs (ce que TOUS partagent)

1. **`setDefaultFilter('nearest','nearest')`** — pixel-art net, systématique.
2. **Tout passe par des canvas** avant l'écran — condition du post-processing et
   du scaling propre. Aucun ne dessine directement à la fenêtre.
3. **Séparer logique et rendu** — la valeur logique n'est jamais dessinée
   directement : il y a toujours une couche "visible" qui ease (T/VT chez Balatro,
   lerps chez Dice, etc.).
4. **Le feedback est une superposition synchronisée** — un événement marquant
   déclenche *en même temps* shake + flash + squash + son + particules. Aucun
   effet isolé.
5. **`math.random` côté présentation uniquement** — Moonring l'utilise *exprès*
   pour le shake afin de **ne pas polluer le RNG de simulation**. Leçon directe
   pour la frontière SIM/PRESENTATION de The Pit.
6. **Libs partagées** : `batteries` (Arco, Dice) pour les maths/tables/tween ;
   ECS léger (`ferris`, `soup`) ; aucun n'utilise de lib UI tierce lourde.

## Quel jeu étudier pour quel besoin ?

| Besoin pour The Pit | Va voir… |
|---|---|
| Feel des cartes (mouvement, hover, éditions) | **Balatro** + `game-feel-juice.md`, `shaders.md` |
| Juice d'impact (combat, dégâts) | **Dice** + `game-feel-juice.md` |
| Look/palette grimdark cohérent | **Moonring** (recolour) + **Mudborne** (color-key) |
| Post-process (CRT/bloom/vignette) | **Balatro** + **Moonring** + `post-processing.md` |
| Eau/contour/éclairage de scène | **Mudborne** + `shaders.md` |
| Architecture UI / tooltips / layout | **Balatro** + `ui-architecture.md` |
| Mini-moteur maison structuré | **Mudborne** (tngine) + **Balatro** (node tree) |
| Particules d'effets nommés | **Moonring** (data-driven) + `particles.md` |

→ Priorités concrètes d'implémentation : [`apply-to-the-pit.md`](apply-to-the-pit.md).
