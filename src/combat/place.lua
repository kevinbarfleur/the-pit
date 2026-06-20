-- src/combat/place.lua
-- Convertit une case de plateau (col,row) en position de COMBAT (x,y,facing) dans le canvas
-- virtuel. Une seule règle, partagée par l'équipe joueur (gauche) et l'IA (droite) :
--   · front = plus grand `col` -> placé au plus près du centre (il engage en premier, §1.4) ;
--   · `row` étale verticalement autour d'une référence (le milieu de la compo).
-- side = -1 (équipe gauche, regarde à droite) ou +1 (équipe droite, regarde à gauche).

local Place = {}

local CENTER_X, CENTER_Y = 160, 96
local FRONT_GAP = 18 -- écart du front au centre
local COL_GAP = 24   -- profondeur entre colonnes
local ROW_GAP = 30   -- espacement vertical entre rangées

-- maxCol = plus grand col de la compo (définit le front) ; rowRef = row moyen (centrage vertical).
function Place.pos(col, row, side, maxCol, rowRef)
  local depth = maxCol - col
  local x = CENTER_X + side * (FRONT_GAP + depth * COL_GAP)
  local y = CENTER_Y + (row - rowRef) * ROW_GAP
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Statistiques utiles d'une liste d'unités {col,row,...} : maxCol et row moyen.
function Place.bounds(list)
  local maxCol, sum = -math.huge, 0
  for _, u in ipairs(list) do
    maxCol = math.max(maxCol, u.col)
    sum = sum + u.row
  end
  return maxCol, (#list > 0 and sum / #list or 0)
end

return Place
