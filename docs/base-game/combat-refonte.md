# Combat Refonte — plan (design agent) — RENDER-only, golden 970156547 INCHANGÉ

> L'arène lit « 2 clusters dans le noir » : pas de sol partagé, pas de ligne de front, atmosphère
> absente au niveau des yeux (la brume `ambient` est en haut/bas, pas au centre du combat).
> **Fichiers** : `src/render/arena_draw.lua`, `src/fx/ambient.lua`, `src/scenes/combat.lua`.
> **NE PAS toucher** `src/combat|board|effects|run|net` ; ne jamais muter `u.x/u.y/hp` ni émettre sur le
> bus ; pour le shake = offset render-local ; RNG cosmétique = `love.math` ou Weyl/PHI déterministe.
> Layout monde : `Place.pos` CENTER_X=160 CENTER_Y=96 (virtuel 320×180) ; teams x∈[64,256] y∈[38,154].

## P0 — confrontation (impact max, risque min)
- **P0.2 brume centrale** (`ambient.lua`, branche `full`) : `drawGlow(W*0.5, 380, 520, 300, c.bgEmber, 0.22)`
  + option `drawGlow(W*0.5, 470, 360, 220, c.blood, 0.10)` pulsé → remplit le noir mort du milieu.
- **P0.1 sol + ligne de front** (`arena_draw.lua`, nouvelle `drawArena()` en 1re ligne de `draw()`, ESPACE
  MONDE/virtuel, raw `love.graphics` comme `drawGrid`) : ellipse plateau `ellipse("fill",160,118,130,34)`
  stone850 ~0.6 + rim brassD ; **seam vertical** x=160 y55→150 (blood ~0.18 + glow pulsé `sin(t*0.04)`) ;
  tinte gauche=shield(bleu)/droite=blood(rouge) ~0.05 → « mon côté / leur côté ».
- **P0.3 vignette resserrée** (`ambient.lua` ~l.139) : 2e vignette intérieure (rayon plus serré) → coins
  full black, œil dirigé vers la ligne de front (comme le menu).

## P1 — profondeur (remplir le noir de SENS)
- P1.1 architecture du puits derrière l'ennemi (trapèzes near-black `c.void/stone900` + « gorge »
  d'anneaux `glowImg` concentriques, déterministe via le seed déjà passé).
- P1.2 bande de **brouillard** qui dérive en travers de la ligne (`glowImg` `c.bgWarm`, `sin(t*0.01)`).
- P1.3 **braises plus denses** dans la zone de combat (émetteur centré x~160 virtuel / 640 design).

## P2 — feel de combat
> `arena_draw` écoute DÉJÀ : `spawned/attack/hit/damage/spread/amped/shield_cast/reflect` ; death-fade
> 40f, shadows, healthbars (frame runique + segments d'affliction), floating numbers. Le manque = du POIDS.
- P2.1 **télégraphe « qui agit »** : lunge vers la cible + underline laiton sous l'unité active (front
  montant de `c.state=="attack"`).
- P2.2 **poids du coup** : micro-shake du TRANSFORM MONDE (offset render-local, **jamais** `u.x/u.y`) +
  flash blanc ~2 frames sur le rig touché, scalé par `rec.hp` du `damage`.
- P2.3 **moment de mort** : burst de particules sombres/sang + flash de case rouge (listener `death`).
- P2.4 **beat victoire/défaite** : ramper vignette/maw sur `arena.overAge` AVANT la modale ; tenir les
  survivants en idle pendant que le champ s'assombrit (« le vainqueur dans le noir »).

## Ordre incrémental (screenshot par étape) : P0.2 → P0.1 → P0.3 → P2.2+P2.3 → P1 → P2.1+P2.4.
## Vérif : `sh tools/check.sh` (golden 970156547) + `love . --shoot=combat`.
