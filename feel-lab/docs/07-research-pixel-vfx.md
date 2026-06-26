# Feel Lab — Recherche #7 : VFX/particules pixel-art grimdark

> Pourquoi les particules « vectorielles » lisses jurent en pixel-art, et comment les rendre cohérentes.
> **[C]** consensuel/sourcé · **[I]** inférence.

## Diagnostic
Les particules cheap = `circle/line/rectangle` **anti-aliasés**, à **position sub-pixel**, **alpha continu**,
**rotation continue**, **couleurs hors-DA**. En pixel-art, l'anti-aliasing est l'ennemi (« a pixel is either on
or off »). Quand l'image vit dans un monde nearest ×4, ces bords mous ne s'alignent pas sur la grille → le
contraste « sprite net / particule baveuse » saute aux yeux.

## Les corrections (toutes implémentées dans `lib/particles.lua`)
1. **Sprites bakés nearest** au lieu de primitives (`sprite.bake(grille ASCII, palette)`). Bords durs = matche les créatures.
2. **Snap à la grille-monde** : positions floats (physique) mais **dessin arrondi au pixel-monde** (×4) → pas de creep/shimmer.
3. **Fondu par RAMPE de couleur** (frames discrètes piochées selon la vie), **pas alpha lisse** (qui bave + bande).
4. **Rotation par paliers 90°** (jamais continue → scintille). Scale par paliers (swap de sprite), pas `size*(0.5+a)`.
5. **Tailles entières petites** (3-8 px-monde), **palette Wraeclast** (jamais `setColor(1,0.7,0.3)` générique).
6. **Glow additif sur cœurs/halos seulement** (halo dithéré, pas blur gaussien) ; le shader postfx porte la braise globale.

## Anatomie des sprites (rampes depuis la palette)
- **ember** (braise montante, additif, 4 frames) : `W`(cœur ivoire)→`Q`(braise)→`q`(sang)→`o`(brun)→vide.
- **shard** (éclat or/os, opaque, rot 90°) : `T`(or)/`S`(os)/`Y`/`s`. Gravité forte (retombe).
- **ash** (cendre, opaque) : `A`→`a`, dérive + gravité douce.
- **spark** (étincelle-traînée, additif, orientée vélocité) : `T`(tête)→`y`(ombre). Longueur = vitesse.
- **mote** (micro-étincelle 1px, additif) : `W`/`T`. « high-brightness pixels placed sparingly ».
- **onde de choc** : anneau de **chunks 1-px** qui grossit par rayon entier et **s'ébrèche en dithérant** (pas `circle("line")` AA).

## Effets pour un climax de fusion grimdark (lisibilité = peu de types, bcp d'instances)
Colonne de **braises montantes** (signature) + **burst d'éclats** qui retombent + **cendres** + **motes** + flash
**braise** (jamais blanc pur). Peu de types simultanés ; densité par type, pas globale.

## Réfs jeux
- **Dead Cells** : modèles low-poly **rendus sans AA en basse réso** + toon. → « no-AA + low-res » = exactement ce qui manquait. 1-2 blend modes/anim.
- **Blasphemous** : VFX main, peu de frames, **palette + silhouette** font l'autorité (pas le nombre de particules).
- **Noita** : sprites sur grille, flags `additive`, `color_change` par seconde, **rotation 90° random**, ranges de vélocité — paramétrage data (= notre `P.burst`).
- **Hyper Light Drifter/Eastward** : sub-pixel OK dans les FRAMES, pas dans la position blité.
- **Loop Hero/Vampire Survivors** : en masse → silhouettes ultra-simples 1-2 couleurs.

## Pièges
Trop de particules (bouillie) · alpha lisse (bave+bande) · rotation continue (scintille) · trop grosses (cassent l'échelle) ·
couleurs hors-DA · **scale non-entier + dither screen-space = Moiré** → mitiger en **dithérant DANS le sprite source**
(pas en screen-space) ; le postfx global garde son dither screen-space (comme le jeu). Glow blanc/blur = trahit la DA.

Sources : pixie.haus/Pixel Parmesan (anti-AA), bugnet/ProPixelizer (pixel-snap/creep), Noita wiki (rotation 90°/data),
Pixel FX Designer/Sprite-AI (rampe+dither, Birth/Mid/Death), Xor/Aseprite (glow halo/bloom-surface), VFX Apprentice
(silhouette), Dead Cells (GameDeveloper/80.lv), Blasphemous (gameanim).
