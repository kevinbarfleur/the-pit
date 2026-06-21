-- src/combat/place.lua
-- Convertit une case de plateau (col,row) en position de COMBAT (x,y,facing) dans le canvas
-- virtuel. Une seule règle, partagée par l'équipe joueur (gauche) et l'IA (droite) :
--   · front = plus grand `col` -> placé au plus près du centre (il engage en premier, §1.4) ;
--   · `row` étale verticalement autour d'une référence (le milieu de la compo).
-- side = -1 (équipe gauche, regarde à droite) ou +1 (équipe droite, regarde à gauche).

local Place = {}

-- Deux formations se font face, CHACUNE dans SA MOITIÉ d'écran. Le pas est ADAPTATIF à l'étendue du sigil
-- (colExt/rowExt fournis par bounds) : une forme étalée/profonde (croix/diamant 4×4, anneau ~4.4, ligne
-- 8×0) se RESSERRE pour ne JAMAIS sortir de sa moitié (x) ni de l'écran (y) ; une forme compacte garde le
-- pas plein. Front = colonne max (au plus près du centre) ; centré vertical sur rowMid. AUCUNE règle par
-- forme -> vaut pour les 5 sigils ET tout futur. La barre de vie étant COLLÉE à la tête (healthbar BAR_DY),
-- un pas serré ne crée plus de chevauchement de barres entre monstres empilés.
local CENTER_X, CENTER_Y = 160, 96
local FRONT_GAP = 22 -- distance du front de chaque équipe au centre (séparation des deux camps)
local COL_GAP, ROW_GAP = 30, 30 -- pas PLEIN (formes compactes) ; carré -> lisible comme le board de build
local X_BUDGET = 112 -- étalement horizontal max d'une équipe : FRONT_GAP+X_BUDGET = 134 < 160 -> reste dans sa moitié
local Y_BUDGET = 116 -- étalement vertical max : ±58 autour du centre -> tient à l'écran (barre + pieds compris)

-- Étendue d'une liste {col,row,...} : front (maxC), centre vertical (rowMid), étendues (colExt/rowExt).
function Place.bounds(list)
  local minC, maxC, minR, maxR = math.huge, -math.huge, math.huge, -math.huge
  for _, u in ipairs(list) do
    if u.col < minC then minC = u.col end
    if u.col > maxC then maxC = u.col end
    if u.row < minR then minR = u.row end
    if u.row > maxR then maxR = u.row end
  end
  if minC == math.huge then minC, maxC, minR, maxR = 0, 0, 0, 0 end
  return { maxC = maxC, rowMid = (minR + maxR) / 2, colExt = maxC - minC, rowExt = maxR - minR }
end

-- (col,row) d'une case -> position de combat (x,y). `b` = table de Place.bounds. Pas adaptatif x ET y.
function Place.pos(col, row, side, b)
  local colGap = (b.colExt > 0) and math.min(COL_GAP, X_BUDGET / b.colExt) or COL_GAP
  local rowGap = (b.rowExt > 0) and math.min(ROW_GAP, Y_BUDGET / b.rowExt) or ROW_GAP
  local depth = b.maxC - col -- 0 = front (au plus près du centre)
  local x = CENTER_X + side * (FRONT_GAP + depth * colGap)
  local y = CENTER_Y + (row - b.rowMid) * rowGap
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

return Place
