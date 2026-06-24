-- src/ui/slot.lua
-- ATOMES DE JEU — CASES DU PLATEAU (design-system-spec.md §2.10) : une case du plateau-graphe 3×3, dans ses
-- SIX états, + l'arête de synergie entre deux cases adjacentes.
--   • draw(x,y,size,state,opts)  — une case carrée. 6 états (bord + fond) :
--       "empty"    bord pierre sourd / fond très sombre (case libre déverrouillée)
--       "selected" bord LAITON + fond hachuré diagonal (case occupée sélectionnée)
--       "neighbor" bord SANG + lueur (« arête de synergie active » — le voisin buffe)
--       "drop"     bord VERT (+ lueur) — LE SEUL vert de la palette = cible de drop valide
--       "locked"   bord très sourd + fond noir + glyphe de cadenas (slot non débloqué)
--       "hover"    bord laiton-spéculaire + hachure plus claire (survolé/drag par-dessus)
--     opts = { typePip = "flesh|order|bone|arcane|abyss"  (pip en haut-gauche),
--              level   = n (1..3 -> pips de niveau en haut-droite, via Badge),
--              affkeys = { "burn", "poison", ... } (petites marques d'affliction en bas) }
--   • edge(x1,y1,x2,y2,active) — l'ARÊTE de synergie : un trait SANG lumineux entre deux cases (segment).
--
-- COUCHE RENDER PURE (love.graphics, espace design 1280×720, sous Draw.begin). Pips de type via Draw.pip,
-- pips de niveau via Badge.levelPips (réutilise l'atome §2.6). Couleurs via Theme UNIQUEMENT. HEADLESS-SAFE :
-- love.graphics stubé -> no-op (golden neutre).
--
-- Réf pixel : pit-forge.js drawSlot (6 états, stripeFill, pip + pips de niveau + rivets) ; nombres = §2.10.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Badge = require("src.ui.badge")

local Slot = {}

local C = Theme.c
local floor, max = math.floor, math.max

-- Rampe de couleur du NIVEAU de fusion (1->3) affiché en TEXTE : gris (base) -> jade (renforcé) -> or (max).
-- Lisible d'un coup d'œil ; remplace les pips losanges (trop encombrants sur une petite case, retour user 2026-06).
local LEVEL_INK = { { 0.62, 0.60, 0.56 }, { 0.55, 0.80, 0.62 }, { 0.88, 0.72, 0.34 } }

local function g() return love and love.graphics or nil end

-- Descripteur d'état : { border, glow?, hatch? } — couleurs canoniques de §2.10 (palette tokenisée).
-- glow = couleur de lueur de bord (additive) ; hatch = la case occupée porte une hachure diagonale.
local STATE = {
  empty    = { fill = C.stone850, border = C.slotEdge },
  selected = { fill = C.stone800, border = C.brass,  hatch = true },
  neighbor = { fill = C.stone800, border = C.blood,  glow = C.blood, hatch = true },
  drop     = { fill = C.stone850, border = C.drop,   glow = C.drop },   -- seul vert de la palette
  locked   = { fill = C.stone900, border = C.stone700, lock = true },
  hover    = { fill = C.stone700, border = C.brassS, glow = C.brassL, hatch = true },
}

-- Hachure diagonale sombre (case occupée) : 1 px sur `sz` le long de (x+y) -> rayures fines reconnaissables.
local function hatchFill(x, y, w, h, col, sz)
  local gr = g(); if not gr then return end
  sz = sz or 3
  gr.setColor(col[1], col[2], col[3], col[4] or 1)
  for sx = 0, w - 1 do
    for sy = 0, h - 1 do
      if (floor((sx + sy) / sz) % 2) == 0 then gr.rectangle("fill", x + sx, y + sy, 1, 1) end
    end
  end
  gr.setColor(1, 1, 1, 1)
end

-- Glyphe de cadenas (état locked) : une croix « + » sourde au centre (le slot scellé). cx,cy = centre.
local function lockGlyph(cx, cy, r)
  local gr = g(); if not gr then return end
  cx, cy = floor(cx), floor(cy)
  gr.setColor(C.stone700[1], C.stone700[2], C.stone700[3], 1)
  gr.rectangle("fill", cx - r, cy - 1, r * 2, 2)
  gr.rectangle("fill", cx - 1, cy - r, 2, r * 2)
  gr.setColor(1, 1, 1, 1)
end

-- ── draw — une case dans son état. x,y = coin haut-gauche, size = côté (px design ; §2.10 = 54). Renvoie
-- (size) pour le chaînage. L'ordre : fond → hachure → glyphe lock → bord d'état → lueur → pip/level/affl.
function Slot.draw(x, y, size, state, opts)
  opts = opts or {}
  local gr = g()
  x, y, size = floor(x), floor(y), floor(size)
  local s = STATE[state] or STATE.empty

  -- 1) fond plein.
  Draw.rect(x + 1, y + 1, size - 2, size - 2, s.fill)
  -- 2) hachure diagonale (cases occupées).
  if s.hatch then hatchFill(x + 1, y + 1, size - 2, size - 2, C.stone700, 3) end
  -- 3) glyphe de cadenas (verrouillé).
  if s.lock then lockGlyph(x + size / 2, y + size / 2, floor(size * 0.18)) end

  -- 4) bord d'état (2px : un liseré net + un ourlet intérieur sombre = relief léger).
  Draw.rect(x, y, size, size, nil, s.border, 2)
  if gr then
    gr.setColor(C.iron[1], C.iron[2], C.iron[3], 0.5)
    gr.rectangle("line", x + 2, y + 2, size - 4, size - 4)
  end

  -- 5) lueur de bord (additive) pour neighbor/drop/hover — l'« émissif » d'état (synergie/cible/survol).
  if s.glow and gr and gr.setBlendMode then
    gr.setBlendMode("add")
    gr.setColor(s.glow[1], s.glow[2], s.glow[3], 0.4)
    gr.rectangle("line", x, y, size, size)
    gr.rectangle("line", x - 1, y - 1, size + 2, size + 2)
    gr.setBlendMode("alpha")
    gr.setColor(1, 1, 1, 1)
  end

  -- 6) PASTILLE DE TIER en haut-gauche : petit disque de la couleur de RARETÉ (remplace le pip de famille — la
  -- famille n'a aucune incidence mécanique, retour user 2026-06). opts.tierCol = {r,g,b} (= rarity.tierColor).
  if opts.tierCol and gr and gr.circle then
    local tc = opts.tierCol
    local pr = max(1.5, floor(size * 0.042)) -- petit point DISCRET (÷2, retour user 2026-06)
    local cx, cy = x + 5 + pr, y + 5 + pr
    gr.setColor(tc[1], tc[2], tc[3], 1); gr.circle("fill", cx, cy, pr)
    gr.setColor(0, 0, 0, 0.5); gr.circle("line", cx, cy, pr + 0.5)
    gr.setColor(1, 1, 1, 1)
  end
  -- 7) NIVEAU EN TEXTE en haut-droite ("LVn", rampe gris->jade->or) au lieu des pips losanges (trop encombrants,
  -- retour user 2026-06). Petit fond sombre derrière -> lisible par-dessus le rig.
  if opts.level and opts.level > 0 then
    local n = math.min(opts.level, 3)
    local ink = LEVEL_INK[n] or LEVEL_INK[1]
    local f = Theme.ui(8)
    local txt = "LV" .. n
    local tw = (f and f:getWidth(txt)) or (#txt * 5)
    local tx, ty = x + size - tw - 4, y + 4
    if gr then gr.setColor(0, 0, 0, 0.55); gr.rectangle("fill", tx - 2, ty - 1, tw + 4, 10); gr.setColor(1, 1, 1, 1) end
    Draw.text(txt, tx, ty, ink, f)
  end
  -- 8) MARQUES D'AFFLICTION en bas (petites pastilles de couleur de famille, lisibles d'un coup d'œil).
  if opts.affkeys and #opts.affkeys > 0 and gr then
    local ax = x + 5
    local ay = y + size - 7
    for _, key in ipairs(opts.affkeys) do
      local col = C[key] or C.bleed
      gr.setColor(col[1], col[2], col[3], 1)
      gr.rectangle("fill", ax, ay, 4, 4)
      gr.setColor(C.iron[1], C.iron[2], C.iron[3], 1)
      gr.rectangle("line", ax, ay, 4, 4)
      ax = ax + 6
    end
    gr.setColor(1, 1, 1, 1)
  end
  return size
end

-- ── edge — l'ARÊTE DE SYNERGIE entre deux cases adjacentes (§2.10 : barre sang lumineuse). (x1,y1)-(x2,y2)
-- = les deux points à relier (typiquement les centres des cases voisines). active=true -> sang + lueur ;
-- inactive -> filet pierre sourd (l'arête existe mais dort). thickness = épaisseur du trait (def 2px).
function Slot.edge(x1, y1, x2, y2, active, thickness)
  local gr = g(); if not gr then return end
  thickness = thickness or 2
  local col = active and C.blood or C.stone700
  gr.setLineWidth(thickness)
  gr.setColor(col[1], col[2], col[3], active and 1 or 0.7)
  gr.line(floor(x1) + 0.5, floor(y1) + 0.5, floor(x2) + 0.5, floor(y2) + 0.5)
  -- lueur de l'arête active (additive, par-dessus) — « 0 0 6px rgba(blood,.7) ».
  if active and gr.setBlendMode then
    gr.setBlendMode("add")
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], 0.45)
    gr.setLineWidth(thickness + 2)
    gr.line(floor(x1) + 0.5, floor(y1) + 0.5, floor(x2) + 0.5, floor(y2) + 0.5)
    gr.setBlendMode("alpha")
  end
  gr.setLineWidth(1)
  gr.setColor(1, 1, 1, 1)
  return true
end

return Slot
