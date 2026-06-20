-- src/gen/details.lua
-- DATA PURE (zéro love.*) : petite BANQUE de sous-grilles "détails" dessinées main (hybride B+A).
-- Injectées par creaturegen aux positions marquées du mask. Chaque détail est une petite matrice
-- de RÔLES (pas de lettres-palette finales) : le générateur traduit selon la faction/accent.
--
-- RÈGLE LISIBILITÉ (8-16px) : les détails sont PETITS et ADDITIFS (1-2px), JAMAIS des anneaux 3×3
-- qui troueraient un visage de 4-6px en damier. On ajoute une marque, on ne creuse pas la silhouette.
--
-- Rôles :
--   O = outline (-> outline de faction : K ou F)
--   B = body    (-> rampe de faction, cran moyen)
--   A = accent clair  (-> accent[1])
--   a = accent sombre (-> accent[2])
--   . = transparent (rien)
--
-- Convention : chaque détail a un ancrage {ax, ay} (0-indexé) qui se cale sur la cellule cible.
-- Le générateur écrit par-dessus le body existant (n'agrandit la grille que par les cornes/tentacules).

local D = {}

-- Corne (abyss) : pousse vers le haut depuis le crâne (excroissance, agrandit le sommet).
D.horn = {
  ax = 1, ay = 2,
  grid = {
    ". A .",
    ". A .",
    "O B O",
  },
}

-- Tentacule (abyss) : pend sur le côté de la tête (ombre + pointe accent).
D.tentacle = {
  ax = 1, ay = 0,
  grid = {
    "O a .",
    ". a .",
    ". A .",
  },
}

-- Œil surnuméraire / glint (léger : un accent + ombre dessous). Ajoute, ne troue pas.
D.eye = {
  ax = 0, ay = 0,
  grid = {
    "A A",
    "a .",
  },
}

-- Rune flottante (arcane) : petit éclat losangé (2px accent), pas un anneau.
D.rune = {
  ax = 1, ay = 0,
  grid = {
    ". A .",
    "A . A",
  },
}

-- Croix d'ordre (order) : 2px verticaux + 1 barre, discrète sur le front/torse.
D.cross = {
  ax = 1, ay = 0,
  grid = {
    ". A .",
    "A A A",
  },
}

-- Cavité / fêlure d'os (bone) : un sillon sombre 1px (shade), pas un trou rond.
D.cavity = {
  ax = 0, ay = 0,
  grid = {
    "a .",
    ". a",
  },
}

-- Cicatrice (flesh) : entaille diagonale 2px (shade).
D.scar = {
  ax = 0, ay = 0,
  grid = {
    "a .",
    ". a",
    "a .",
  },
}

return D
