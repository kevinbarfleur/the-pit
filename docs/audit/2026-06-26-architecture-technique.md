# Audit architecture technique - 2026-06-26

## Etat global

La base technique est bien meilleure que celle d'un prototype moyen. Elle est
deja organisee par domaines :

- `src/combat`, `src/board`, `src/effects`, `src/run` : simulation et regles.
- `src/render`, `src/ui`, `src/fx`, `src/audio` : presentation.
- `src/data`, `src/gen`, `src/i18n`, `src/net`, `src/lab` : contenu, generation,
  snapshots et outils.
- `tests` et `tools/check.sh` : suite headless large.

Le probleme n'est pas l'absence d'architecture. Le probleme est que certaines
zones ont grandi plus vite que les frontieres.

## LÖVE / Lua : pratiques validees

Le projet cible LÖVE 11.5. Les points importants verifiés :

- `love.conf` est le bon endroit pour configurer fenetre, modules et version.
- Depuis LÖVE 11.x, les couleurs graphiques sont en flottants `0..1`.
- `love.update(dt)` recoit un delta en secondes, mais la simulation du projet ne
  depend pas du delta variable : `main.lua` pilote un pas fixe.
- `love.graphics.newCanvas` / `setCanvas` sont utilises comme passes de rendu ;
  il faut toujours decrocher/restaurer la cible de rendu proprement.
- Pour l'audio long, `love.audio.newSource(path, "stream")` est le choix sain ;
  pour les SFX courts, `SoundData` + sources statiques est coherent.
- Lua 5.1 n'a qu'une structure de donnees centrale, la table. Pour la simulation,
  l'usage d'arrays et `ipairs` est plus robuste que `pairs` quand l'ordre compte.
- Les variables globales accidentelles sont un vrai risque Lua ; le style local
  actuel est donc a preserver.

## Boucle moteur et determinisme

`main.lua` implemente une boucle fixe 1/60 avec accumulation et `MAX_SKIP`.
C'est le bon modele pour un autobattler deterministe : la presentation peut
vivre au temps mur, mais le combat et la progression doivent avancer par steps
discrets.

Constat positif :

- `tools/check.sh` verifie RNG global interdit dans la SIM.
- `src/combat/arena.lua` annonce et respecte le role SIM pure.
- `src/render/arena_draw.lua` lit l'arene et reagit aux events sans muter la sim.
- `src/ui/juice.lua`, `src/ui/feel.lua`, `src/audio/sfx.lua`, `src/audio/music.lua`
  sont dans la couche presentation.

Point a surveiller :

- `src/run/state.lua` et `src/combat/arena.lua` utilisent
  `love.math.newRandomGenerator`. C'est assumé par les docs du projet, mais ca
  rend ces modules moins purs hors environnement LÖVE. Si un jour tu veux lancer
  des simulations massives sans LÖVE, injecter un adaptateur RNG serait plus
  portable.

## Fichiers a risque

Mesures utiles au 2026-06-26 :

- `src/scenes/build.lua` : 3532 lignes.
- `src/gen/primgen.lua` : 3005 lignes.
- `src/ui/forge.lua` : 1806 lignes.
- `src/i18n/en.lua` : 1137 lignes.
- `src/gen/creaturegen.lua` : 1117 lignes.
- `src/data/units.lua` : 1039 lignes.
- `src/combat/arena.lua` : 1027 lignes.
- `src/render/critter.lua` : 924 lignes.
- `src/scenes/designsystem.lua` : 837 lignes.
- `src/scenes/combat.lua` : 759 lignes.

Gros fichier ne veut pas dire mauvais fichier. Le risque depend du rythme de
changement et du nombre de responsabilites. Dans cette lecture, l'ordre de
danger est :

1. `src/scenes/build.lua`
2. `src/ui/forge.lua`
3. `src/gen/primgen.lua`
4. `src/run/state.lua`
5. `src/combat/arena.lua`

## `build.lua` : extraction recommandee

`build.lua` doit rester le coordinateur de scene, pas devenir le jeu entier.
Extraction progressive recommandee :

- `src/scenes/build_layout.lua` : calculs de rects, shop, bench, commander,
  HUD, board. Module pur, testable sans LÖVE.
- `src/scenes/build_comp.lua` ou `src/run/comp_builder.lua` : conversion
  board/bench/commander vers comp combat, resolution auras, roles, data baked.
- `src/ui/build_shop.lua` : rendu cartes boutique + etats d'achat/freeze.
- `src/ui/build_board.lua` : rendu board + slots + overlays de drop/synergie.
- `src/ui/build_tooltip.lua` : placement/clamp et composition des fiches.
- `src/render/build_fx.lua` : merge FX, particules, shake local.

Critere : une extraction est reussie si `Build` garde l'etat de scene et les
gestes, mais ne porte plus les algorithmes de layout, de comp ou de rendu de
chaque molecule.

## `arena.lua` : bon coeur, tuning a sortir

`arena.lua` est gros, mais il a une frontiere claire. Il peut rester monolithique
plus longtemps que `build.lua`, car le combat a besoin d'une orchestration
centrale stricte.

A sortir avant de refactorer la logique :

- constantes de fatigue, caps, cooldowns, seuils ;
- tables de tuning des status ;
- poids de ciblage/aggro ;
- seuils de mort, execute, anti-one-shot.

Destination possible : `src/data/combat_tuning.lua` ou `src/combat/tuning.lua`.

Eviter pour l'instant : decouper `arena.lua` en 15 micro-modules. Le risque de
casser la lecture du pipeline serait superieur au gain.

## `run/state.lua` : economie et donnees

Le module est deterministe et teste, mais il porte beaucoup de chiffres :
or, odds, XP, tiers, cadence reliques, slots, vie anti-tilt, refus, etc.

Recommendation :

- `src/data/economy.lua` : tables d'odds, XP, slots, or, cadence.
- `src/run/state.lua` : logique d'application des regles.
- `tools/balancematrix.lua`, `tools/scenarios` : consomment les memes tables,
  pas une copie.

Objectif : pouvoir changer une courbe sans lire 500 lignes de logique.

## Generateurs : quarantainer les labs

Le projet a plusieurs couches de generation :

- `src/gen/primgen.lua`
- `src/gen/creaturegen.lua`
- `src/gen/forge.lua`
- `src/gen/atlas.lua`
- `src/ui/forge.lua`
- scenes de galerie/iteration/designsystem

Ce n'est pas forcement mauvais : un jeu procedural a besoin d'ateliers. Mais il
faut que le statut soit visible :

- **runtime production** : appele en jeu normal.
- **bake/cache runtime** : appele mais memoise, cout controle.
- **lab/dev** : utile pour iterer, pas source directe de regles.
- **legacy** : garde pour compat/tests, mais ne pas etendre.

Action simple : ajouter un en-tete `Status:` dans les gros generateurs et dans
`src/ui/forge.lua`.

## Rendu et scaling

Le code actuel choisit un scaling fractionnaire qui remplit la fenetre :

- `Viewport.update` prend `min(sw/vw, sh/vh)` sans `floor`.
- `main.lua` commente explicitement le choix "scale fractionnaire".
- `tests/viewport.lua` valide des valeurs comme `4.5`, `3.2`, `8`.

Des docs plus anciens parlent encore d'echelle entiere pixel-perfect. C'est une
decision a mettre a jour.

Deux options propres :

1. **Mode fill responsive** : production actuelle. Avantage : plus moderne,
   remplit mieux les fenetres, UI native nette. Risque : sprites pixel art plus
   doux a certaines resolutions.
2. **Mode integer crisp** : echelle entiere avec gutters. Avantage : pixel art
   strict. Risque : plus de barres, moins moderne sur desktop.

Recommendation : acter "fill responsive" comme default si les screenshots sont
juges bons, puis ajouter plus tard un toggle "Crisp integer" pour puristes.

## High DPI : commentaire contradictoire

`conf.lua` dit que les evenements souris restent en unites fenetre et que
`main.lua` convertit via `love.window.toPixels`. `main.lua` dit l'inverse :
aucune conversion DPI appliquee.

Le check viewport passe, mais il ne prouve pas la verite sur un ecran Retina
reel. Il faut corriger le commentaire faux et, idealement, ajouter un test manuel
de debug : afficher `love.mouse.getPosition()`, `love.graphics.getDimensions()`,
`love.window.getMode()` sur Retina et non-Retina.

## Tests

La suite actuelle est excellente pour un prototype :

- determinisme ;
- snapshot ;
- economy fuzz ;
- synergies ;
- golden combat ;
- generation ;
- UI headless ;
- viewport.

Manques pertinents :

- visual smoke automatise sur captures : existence, dimensions, pixels non vides,
  peut-etre histogramme simple ;
- audit statique docs/source-of-truth : detecter les termes stales comme
  `cryptic`, `hidden`, `identification`, `linear slots` dans les docs actives ;
- perf counters : allocations/frame, draw calls, `love.graphics.getStats` en
  scene build/combat.

## Performance

Rien dans l'audit ne crie "probleme perf urgent". Les risques classiques LÖVE
sont surtout :

- allouer des tables en masse dans `draw` ou `update` haute frequence ;
- mesurer/wrapper du texte chaque frame sans cache ;
- rebaker des widgets trop souvent ;
- dessiner des gradients/rectangles par bandes partout ;
- generer des creatures dans une boucle de rendu au lieu de cache/memoiser.

Le projet a deja beaucoup de caches. Il faut maintenant les rendre observables :
compteurs de cache hit/miss en mode dev, stats `love.graphics.getStats`, et une
capture perf simple par scene.
