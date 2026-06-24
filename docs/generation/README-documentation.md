# Documentation-recette — Générateur procédural de pixel art (bestiaire, attaques, biomes, transitions)

Suite de documents permettant à un développeur de **reproduire exactement** le moteur : pixel art
procédural **déterministe** par assemblage de primitives, animé par un **champ de déplacement par
pixel**, avec un système d'attaque, des biomes en couches tileables et des transitions de scène.

## Ordre de lecture

1. **[DOC-01 — Fondations](DOC-01-fondations-moteur.md)**
   Déterminisme (mulberry32 + décorrélation par hash), grille & rendu pixelisé, bibliothèque de
   primitives (ellipse, disc, tube, tentacle, mass, eye, outline…), modèle d'ombrage, **ancres
   sémantiques**, registre (ARCHMAP/FAMILIES/PROF), discipline de génération propre, validation.

2. **[DOC-02 — Le champ de déplacement](DOC-02-champ-de-deplacement.md)**
   Le cœur de l'animation : `disp(x,y)` + `blit`, les profils idle (breathe / sway / flap / tentacles
   / writhe / legs / bob), l'animation des yeux, et **pourquoi ça ne déchire jamais** (dégradés lissés).

3. **[DOC-03 — Le système d'attaque](DOC-03-systeme-attaque.md)**
   Enveloppe anticipation→frappe→récupération (`_env`, smootherstep, hit-stop), les ~16 *kinds*
   (lunge, swing, lash, skitter…), la couche d'effets `atkFx`, la table `ATK`, la boucle idle↔attaque,
   et les **correctifs validés par la recherche** : squash-and-stretch à volume conservé, overlapping
   action par phase-lag, déformation lissée.

4. **[DOC-04 — Biomes](DOC-04-biomes.md)**
   Décors en 6 couches parallaxables et tileables, **dithering ordonné de Bayer**, gradients tramés,
   ridgelines par somme de sinus entières (fBm tileable), brume, compositing, dé-doublonnage des motifs.

5. **[DOC-05 — Transitions](DOC-05-transitions.md)**
   Mélange source→cible piloté par une progression `p`, **fronts plumeux** (smoothstep) anti-arêtes,
   génériques (fondus, ondulations, iris) vs adaptatives thématiques (vortex, marée, spores, voile).

## Annexe R — Dossier de recherche

État de l'art citable (références GDC/SIGGRAPH/articles) validant et étendant les techniques :
12 principes de l'animation (Disney) ; linear blend skinning / Verlet (Jakobsen) / IK deux-os (Juckett) ;
solveur Spore (Hecker et al., SIGGRAPH 2008) ; game feel (Penner easing, smootherstep, screenshake,
hit-stop) ; pixel art (Saint11, *Pixel Logic*) ; PCG propre (noise & domain warping de Quilez, Bayer,
WFC, grammaires de créatures, MAP-Elites) ; tileable/parallaxe & post-traitement shader ; export
sprite-sheet. *(Fourni séparément — voir le dossier de recherche.)*

## Fichiers de référence (implémentations exécutables)

- `generateur-bestiaires-attaques.html` — bestiaire 97 archétypes + animations idle + système d'attaque.
- `generateur-biomes.html` — 16 biomes en couches tileables.
- `generateur-transitions.html` — 10 transitions douces.

Chaque fichier est autonome (HTML/canvas/JS, aucune dépendance) et se valide par
`node --check` + un harnais runtime (voir DOC-01 §7).

## Les invariants à ne jamais violer

1. **Déterminisme** : même seed ⇒ même résultat (toujours hacher le seed pour décorréler).
2. **Lisser, ne jamais trancher** : toute déformation par région se multiplie par un dégradé continu
   (poids de skinning normalisés), jamais par un seuil dur — sinon le sprite se déchire.
3. **Silhouette d'abord** : une forme lisible au plissement d'yeux prime sur le détail.
4. **Un motif signature par famille/biome** : dé-doublonner pour garder de la variété sans répétition.
5. **L'effet vend l'impact** : à petite échelle, particules/arcs/ondes rendent l'attaque lisible.
