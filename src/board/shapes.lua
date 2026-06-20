-- src/board/shapes.lua
-- Formes de plateau, définies comme GRAPHES EXPLICITES (cf. docs/research/gd-research-result.md §1.3).
-- Idée directrice du rapport : dans un jeu d'adjacence, la FORME du plateau EST le graphe de
-- synergies. On ne dérive donc PAS l'adjacence des coordonnées : chaque forme liste ses cases
-- (pour le rendu) ET ses arêtes (pour les synergies), indépendamment. Toutes gardent 9 slots :
-- un sigil-relique échange une TOPOLOGIE, jamais de la puissance brute.
--
-- Deux couches de données par slot :
--   cells[i] = {x,y}      -> position de rendu (sert aussi au ciblage front/back, par colonne x)
--   edges    = {{a,b}...} -> qui est adjacent à qui (sert aux synergies de voisinage)
--
-- Principe d'équilibrage du rapport : NE PAS égaliser les arêtes de toutes les formes ;
-- viser « 1 forme = 1 archétype qui l'adore ».

local Shapes = {}

-- Carré du novice : 3×3 plein, adjacence ORTHOGONALE (pas les diagonales : la 8-connexité
-- tuerait le puzzle). Hiérarchie lisible : centre (idx 5) = 4 voisins, bords = 3, coins = 2.
Shapes.carre = {
  name = "carre",
  label = "Carre du novice",
  archetype = "polyvalent",
  cells = {
    { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 },
    { x = 0, y = 1 }, { x = 1, y = 1 }, { x = 2, y = 1 },
    { x = 0, y = 2 }, { x = 1, y = 2 }, { x = 2, y = 2 },
  },
  edges = {
    { 1, 2 }, { 2, 3 }, { 4, 5 }, { 5, 6 }, { 7, 8 }, { 8, 9 }, -- horizontales
    { 1, 4 }, { 4, 7 }, { 2, 5 }, { 5, 8 }, { 3, 6 }, { 6, 9 }, -- verticales
  },
}

-- Croix / plus : centre nourri par 4 branches isolées -> build MONO-CARRY extrême
-- (un monstre alimenté par 4 voisins, mais les nourriciers sont faibles).
Shapes.croix = {
  name = "croix",
  label = "Sigil en croix",
  archetype = "mono-carry",
  cells = {
    { x = 2, y = 2 },                   -- 1  centre (4 voisins)
    { x = 2, y = 1 }, { x = 2, y = 0 }, -- 2,3  branche haut
    { x = 2, y = 3 }, { x = 2, y = 4 }, -- 4,5  branche bas
    { x = 1, y = 2 }, { x = 0, y = 2 }, -- 6,7  branche gauche
    { x = 3, y = 2 }, { x = 4, y = 2 }, -- 8,9  branche droite
  },
  edges = { { 1, 2 }, { 2, 3 }, { 1, 4 }, { 4, 5 }, { 1, 6 }, { 6, 7 }, { 1, 8 }, { 8, 9 } },
}

-- Anneau : boucle fermée, chaque case exactement 2 voisins -> builds de CHAÎNE/propagation
-- qui rebouclent sur eux-mêmes. (Cercle d'invocation : thématiquement parfait.)
do
  local cells, edges = {}, {}
  for i = 0, 8 do
    local a = (i / 9) * (2 * math.pi) - math.pi / 2 -- math.cos/sin OK au load (déterministe)
    cells[i + 1] = { x = math.cos(a) * 2.2 + 2.2, y = math.sin(a) * 2.2 + 2.2 }
    edges[i + 1] = { i + 1, ((i + 1) % 9) + 1 } -- i -> i+1, le 9 reboucle sur le 1
  end
  Shapes.anneau = { name = "anneau", label = "Sigil de l'anneau", archetype = "chaine", cells = cells, edges = edges }
end

-- Diamant : adjacence répartie, beaucoup de cases à 2-3 voisins -> builds GO-WIDE / essaim
-- (tout le monde se buff un peu).
Shapes.diamant = {
  name = "diamant",
  label = "Sigil du diamant",
  archetype = "go-wide",
  cells = {
    { x = 2, y = 0 },                                 -- 1
    { x = 1, y = 1 }, { x = 3, y = 1 },               -- 2,3
    { x = 0, y = 2 }, { x = 2, y = 2 }, { x = 4, y = 2 }, -- 4,5,6
    { x = 1, y = 3 }, { x = 3, y = 3 },               -- 7,8
    { x = 2, y = 4 },                                 -- 9
  },
  edges = {
    { 1, 2 }, { 1, 3 },
    { 2, 4 }, { 2, 5 }, { 3, 5 }, { 3, 6 },
    { 5, 7 }, { 5, 8 }, { 4, 7 }, { 6, 8 },
    { 7, 9 }, { 8, 9 },
  },
}

-- Ligne : conduit, max 2 voisins, pas de boucle -> propage du début à la fin.
do
  local cells, edges = {}, {}
  for i = 1, 9 do cells[i] = { x = i - 1, y = 0 } end
  for i = 1, 8 do edges[i] = { i, i + 1 } end
  Shapes.ligne = { name = "ligne", label = "Sigil du conduit", archetype = "conduit", cells = cells, edges = edges }
end

-- Ordre de rotation des sigils (touche [s] dans la scène plateau).
Shapes.order = { "carre", "croix", "anneau", "diamant", "ligne" }

return Shapes
