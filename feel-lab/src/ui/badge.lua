-- src/ui/badge.lua
-- ATOMES DE JEU — BADGES (design-system-spec.md §2.6) : les petites pastilles de DONNÉES posées sur les
-- cartes/cases/HUD. Trois badges, tous en losanges (la « monnaie » géométrique du jeu) :
--   • cost       — pièce d'or (losange laiton) + nombre (Space Mono). Vire au sang si trop cher.
--   • levelPips   — 3 logements de losange (duplicatas) : n pleins (or) / (max-n) vides (cerclés laiton).
--   • rarity      — échelle R1..R5 : 5 segments horizontaux, le rang courant gildé + pips dorés dessous.
--
-- COUCHE RENDER PURE (love.graphics autorisé, espace design 1280×720, sous Draw.begin). Ce ne sont PAS des
-- widgets bakés (Forge) : ce sont des primitives DYNAMIQUES dessinées chaque frame (la valeur change), comme
-- Draw.pip/Draw.bar. Couleurs/polices via Theme UNIQUEMENT ; les chiffres via Draw.text* (UTF-8-safe).
-- HEADLESS-SAFE : sous le mock LÖVE, love.graphics.* est stubé -> tout no-op, aucun crash (golden neutre).
--
-- Réf pixel : pit-forge.js drawDiamond / drawLevelPips / drawRarityScale ; nombres = §2.6.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")

local Badge = {}

local C = Theme.c
local floor = math.floor

-- Garde-fou love.graphics (no-op headless). Tous les tracés passent par là.
local function g()
  return love and love.graphics or nil
end

-- ── Losange plein (Manhattan |dx|+|dy|<=r), bord + remplissage + éclat (port de drawDiamond). cx,cy =
-- centre ; r = demi-diagonale en px design. fill/edge = {r,g,b,a} Theme ; spec = point spéculaire optionnel.
local function diamond(cx, cy, r, fill, edge, spec)
  local gr = g(); if not gr then return end
  cx, cy = floor(cx + 0.5), floor(cy + 0.5)
  for dy = -r, r do
    for dx = -r, r do
      local m = math.abs(dx) + math.abs(dy)
      if m <= r then
        local c = (m >= r - 0.9) and edge or fill
        if c then gr.setColor(c[1], c[2], c[3], c[4] or 1); gr.rectangle("fill", cx + dx, cy + dy, 1, 1) end
      end
    end
  end
  if spec then gr.setColor(spec[1], spec[2], spec[3], spec[4] or 1); gr.rectangle("fill", floor(cx - r * 0.3), floor(cy - r * 0.3), 1, 1) end
  gr.setColor(1, 1, 1, 1)
end
Badge.diamond = diamond

-- ── COST BADGE (pièce d'or) — §2.6. Icône losange 11px (laiton) + nombre Space Mono 700 15px `gold`.
-- affordable=false -> icône sombre (sang séché) + nombre `blood-l` (« trop cher »). Renvoie la largeur totale.
-- x,y = coin haut-gauche du badge ; le losange est centré verticalement sur la hauteur du nombre.
function Badge.cost(x, y, value, affordable)
  if affordable == nil then affordable = true end
  local fontPx = 15
  local font = Theme.value(fontPx)
  local fh = font and font:getHeight() or fontPx
  local r = 5 -- demi-diagonale (~11px de large, cf. §2.6)
  local cy = y + fh / 2
  local iconFill = affordable and C.brassL or C.bloodD       -- laiton clair / sang séché
  local iconEdge = affordable and C.iron or C.bloodD
  local spec = affordable and C.brassS or nil
  diamond(x + r, cy, r, iconFill, iconEdge, spec)
  local num = tostring(value)
  local tx = x + 2 * r + 4
  local col = affordable and C.gold or C.bloodL
  Draw.text(num, tx, y, col, font)
  return (tx - x) + (font and font:getWidth(num) or #num * 8)
end

-- ── LEVEL PIPS (duplicatas) — §2.6. `max` logements (def 3) de losange 9px ; les `n` premiers pleins (or +
-- lueur), le reste vides (fond sombre + cerclage laiton). pas horizontal de 9px (cf. drawLevelPips). x,y =
-- coin haut-gauche ; renvoie la largeur totale.
function Badge.levelPips(x, y, n, max)
  max = max or 3
  n = math.max(0, math.min(n or 0, max))
  local r = 4          -- demi-diagonale (~9px)
  local step = 9       -- pas (§2.6 : 9px)
  local cy = y + r
  for i = 0, max - 1 do
    local cx = x + r + i * step
    if i < n then
      diamond(cx, cy, r, C.gold, C.brass, C.brassS) -- plein doré + éclat
    else
      diamond(cx, cy, r, C.stone900, C.brass, nil)  -- vide : fond sombre, cerclage laiton
    end
  end
  return max * step
end

-- ── RARITY SCALE (R1..R5) — §2.6. `max` segments horizontaux (def 5) sur la largeur w ; le segment du rang
-- `rank` est GILDÉ (cadre + fond laiton) et porte `rank` pips dorés dessous, les autres restent sombres.
-- x,y = coin haut-gauche, w = largeur totale, h optionnel (def 12). Renvoie la hauteur dessinée (barre + pips).
function Badge.rarity(x, y, w, rank, max, h)
  max = max or 5
  rank = math.max(0, math.min(rank or 0, max))
  h = h or 12
  local gr = g()
  local gap = 3
  local segW = (w - gap * (max - 1)) / max
  for i = 1, max do
    local sx = x + (i - 1) * (segW + gap)
    local active = (i == rank)
    local fill = active and C.brass or C.stone900
    local edge = active and C.brassS or C.line
    Draw.rect(sx, y, segW, h, fill, edge, 1)
    -- éclat de crête sur le segment actif (haut éclairé), discret.
    if active and gr then
      gr.setColor(C.brassL[1], C.brassL[2], C.brassL[3], 0.5)
      gr.rectangle("fill", sx + 1, y + 1, segW - 2, 1)
      gr.setColor(1, 1, 1, 1)
    end
  end
  -- pips dorés sous le segment actif (rank losanges) — la « valeur » du rang, lisible sans lire.
  if rank > 0 then
    local sx = x + (rank - 1) * (segW + gap)
    local py = y + h + 4
    local pr = 2
    local pStep = 4
    local startX = sx + segW / 2 - ((rank - 1) * pStep) / 2
    for s = 0, rank - 1 do
      diamond(startX + s * pStep, py, pr, C.brassS, C.brass, nil)
    end
    return (h + 4) + pr * 2
  end
  return h
end

return Badge
