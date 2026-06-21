-- src/render/affliction_icons.lua
-- DATA-ONLY : grilles pixel art des icônes de statut (afflictions) affichées
-- au-dessus de la barre de vie d'une unité, en scène de COMBAT.
--
-- CONTRAT (le renderer consomme ce format tel quel) :
--   * Le module retourne une table { bleed, poison, burn, rot, shock }.
--   * Chaque valeur est un TABLEAU de strings de MÊME longueur (une grille),
--     ligne du HAUT en premier — format attendu par Sprite.bake (src/core/sprite.lua) :
--     bake lit grid[y]:sub(x,x) et mappe le caractère -> couleur via la palette fournie.
--   * Taille 8×8 (plancher de lisibilité pour ce type d'icône). Une grille peut
--     faire 8×9 si une forme HAUTE (goutte/flamme) le réclame.
--   * Dessinées en ESPACE VIRTUEL (canvas 320×180) puis blit ×4, sur FOND SOMBRE
--     (arène grimdark) ; plusieurs s'alignent sur la barre de vie (~20px de large).
--
-- CARACTÈRES = TEINTES ABSTRAITES (on ne choisit PAS la couleur, seulement la
-- FORME et l'OMBRAGE). Le renderer construit une palette par famille et teinte :
--   ' ' transparent
--   'o' teinte la plus sombre  (UNIQUEMENT un trou interne : œil, bulle ; ou
--                               un selout 1px là où ça sépare — JAMAIS un cadre)
--   'd' teinte mi-sombre       (ombre bas-droite + AA manuel : 1-3px sur escaliers)
--   'm' teinte principale      (le CORPS — porte la silhouette)
--   'h' surlignage (accent UNIQUE, lumière haut-gauche)
--
-- Teintage prévu (info seulement — ne PAS l'encoder ici) :
--   bleed -> cramoisi · poison -> vert toxique · burn -> braise orange
--   rot -> violet nécrotique · shock -> jaune électrique
--
-- MÉTHODE (recherche : Saint11 AA/banding, Lospec lines/curves, Pixel Grimoire) :
--   1. 8×8 mais NON rempli bord-à-bord : marge/négatif autour, masse visuelle ~6px.
--      Les pixels "en plus" servent à des BORDS PROPRES, pas à du volume.
--   2. Diagonales à PAS CONSTANT : chaque pente = segments identiques. Vers le
--      centre d'une courbe, le pas diminue/reste égal ; en s'éloignant il
--      augmente/reste égal. Construire des deux extrémités vers le milieu.
--   3. AA MANUEL SÉLECTIF : 'd' posé en DIAGONALE de coin après la fin d'un pas,
--      seulement sur les pires escaliers (jamais en bande, sinon banding/flou).
--   4. 3 valeurs max, distinctes en gris. Silhouette franche, suggestion > détail
--      (« un pixel sombre = un œil »). Lumière constante haut-gauche.
--   5. Devinable SANS la couleur ; la couleur ne fait que confirmer.

return {
  -- BLEED : goutte de sang (larme). 8×9 (forme haute). Pointe 1px, flancs en
  -- courbe à pas régulier qui se ferment en ventre rond. AA 'd' : épaules de la
  -- courbe (où le pas s'élargit) + ombre bas-droite du ventre.
  bleed = {
    "   m    ",
    "   m    ",
    "  mhm   ",
    "  mmm   ",
    " dmmmd  ",
    " mhmmm  ",
    " mmmmd  ",
    "  mmm   ",
    "   d    ",
  },

  -- POISON : flaque + UNE bulle qui remonte. 8×8. Surface biseautée aux deux
  -- bouts à pas constant ; bulle creuse 'o' (suggestion). AA 'd' : coins
  -- inférieurs de la flaque + sous la bulle.
  poison = {
    "        ",
    "   m    ",
    "  mom   ",
    "   d    ",
    " mhmmm  ",
    "mmmmmmm ",
    "dmmmmmd ",
    " dmmmd  ",
  },

  -- BURN : flamme. 8×9 (haute). TROIS langues de hauteurs différentes (centrale
  -- la plus haute, gauche moyenne, droite courte) séparées par des creux en haut
  -- -> silhouette chaotique, JAMAIS confondue avec la goutte. Waist resserrée au
  -- milieu, base large et ondulée. 'h' (jaune chaud) concentré AUX POINTES, 'm'
  -- (orange) au corps, 'd' (orange froid) à la base. AA 'd' : flanc droit + pied.
  burn = {
    "    h   ",
    "  h mh  ",
    "  hmhh  ",
    " hmmhm  ",
    " mmhmm  ",
    "  mmmm  ",
    " mmhmmd ",
    " dmmmmd ",
    "  ddmd  ",
  },

  -- ROT : crâne. 8×8. Calotte ARRONDIE (courbe à pas régulier des deux côtés),
  -- 2 orbites 'o' (1px = un œil), nasale 'o' 1px, mâchoire plus étroite. Pas de
  -- dents détaillées (suggestion > détail). AA 'd' : coins de la calotte + menton.
  rot = {
    "  dmmd  ",
    " mmmmmm ",
    "mhmmmmm ",
    "mommomm ",
    "mmmommm ",
    "dmmmmmd ",
    " mm mm  ",
    " d   d  ",
  },

  -- SHOCK : éclair. 8×8. Deux jambages en Z, chacun une diagonale à PAS CONSTANT
  -- (segments identiques, zéro escalier irrégulier). Tranchant 'h' sur le bord
  -- d'attaque. AA 'd' : la pointe basse + le coude central.
  shock = {
    "    mh  ",
    "   mh   ",
    "  mhm   ",
    " mhmd   ",
    "  dmh   ",
    "   mh   ",
    "   mh   ",
    "   d    ",
  },
}
