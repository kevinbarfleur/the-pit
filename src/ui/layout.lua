-- src/ui/layout.lua
-- MOTEUR DE LAYOUT « flex » minimal en ESPACE DESIGN (1280×720). But : que TOUT soit aligné au pixel,
-- sans trou ni élément à la mauvaise taille — « placé à la perfection par un designer ». Réutilisé par
-- TOUTES les étapes du rollout (barre du build, grille de cases, boutique, cartes, codex).
--
-- Une « boîte » = { x, y, w, h } en px DESIGN (coin haut-gauche + taille). row()/column() découpent une
-- boîte conteneur en boîtes-enfants selon des règles flex. Tout est PLANCHÉ (pixel-perfect, pas de demi-px).
--
-- ── Enfants ──
-- Chaque enfant est une SPEC : un nombre = taille fixe sur l'axe principal (px) ; OU une table
--   { size = n }            -> taille fixe (px) sur l'axe principal
--   { flex = k }            -> absorbe k parts de l'espace RESTANT sur l'axe principal (k>0)
--   { min = n }             -> taille minimale (avec flex)
-- L'axe CROISÉ est piloté par `align` du conteneur (start/center/end/stretch). `stretch` = l'enfant
-- remplit toute l'étendue croisée du conteneur (c'est ce qui « fait disparaître les trous »).
--
-- ── Options ──
-- { gap=0, pad=0|{l,t,r,b}|{x,y}, align="stretch", justify="start" }
--   justify (axe principal) : start | center | end | "between" | "around" | "evenly"
--   align   (axe croisé)    : start | center | end | stretch
--   gap                     : espace entre enfants (px) ; flex absorbe le RESTE après gaps+fixes.
--
-- row(box, specs, opts)    -> { rect, rect, ... } (une boîte par enfant, dans l'ordre)
-- column(box, specs, opts) -> idem, axe principal vertical.
--
-- PUR (zéro love.*) : juste de l'arithmétique de rectangles -> testable headless, réutilisable partout.

local Layout = {}

local floor, max = math.floor, math.max

-- Normalise pad -> { l, t, r, b }.
local function pads(p)
  if not p then return 0, 0, 0, 0 end
  if type(p) == "number" then return p, p, p, p end
  if p.l or p.t or p.r or p.b then return p.l or 0, p.t or 0, p.r or 0, p.b or 0 end
  if p.x or p.y then return p.x or 0, p.y or 0, p.x or 0, p.y or 0 end
  return 0, 0, 0, 0
end

-- Lit une spec d'enfant -> { fixed?, flex?, min }.
local function readSpec(s)
  if type(s) == "number" then return { fixed = s, min = 0 } end
  if type(s) == "table" then
    if s.flex and s.flex > 0 then return { flex = s.flex, min = s.min or 0 } end
    return { fixed = s.size or s.min or 0, min = s.min or 0 }
  end
  return { fixed = 0, min = 0 }
end

-- Cœur génératif : `main` = "x" (row) ou "y" (column). Découpe `box` sur l'axe principal.
local function flow(main, box, specs, opts)
  opts = opts or {}
  local n = #specs
  local out = {}
  if n == 0 then return out end

  local cross = (main == "x") and "y" or "x"
  local mainSize = (main == "x") and "w" or "h"
  local crossSize = (main == "x") and "h" or "w"

  local pl, pt, pr, pb = pads(opts.pad)
  -- boîte intérieure (après padding).
  local ix = box.x + pl
  local iy = box.y + pt
  local iw = box.w - pl - pr
  local ih = box.h - pt - pb
  local inner = { x = ix, y = iy, w = iw, h = ih }

  local gap = opts.gap or 0
  local mainAvail = inner[mainSize]
  local crossAvail = inner[crossSize]

  -- 1) mesure : somme des fixes + total des parts flex.
  local parsed = {}
  local fixedTotal, flexTotal = 0, 0
  for i = 1, n do
    local p = readSpec(specs[i])
    parsed[i] = p
    if p.flex then flexTotal = flexTotal + p.flex; fixedTotal = fixedTotal + (p.min or 0)
    else fixedTotal = fixedTotal + p.fixed end
  end
  local gapsTotal = gap * (n - 1)
  local leftover = max(0, mainAvail - fixedTotal - gapsTotal) -- espace à répartir aux flex

  -- 2) taille de chaque enfant sur l'axe principal.
  local sizes = {}
  local usedFlex = 0
  local lastFlex = nil
  for i = 1, n do
    local p = parsed[i]
    if p.flex then
      lastFlex = i
      local s = floor(leftover * (p.flex / flexTotal))
      sizes[i] = (p.min or 0) + s
      usedFlex = usedFlex + s
    else
      sizes[i] = p.fixed
    end
  end
  -- arrondi : on donne le reste (px perdus au floor) au DERNIER flex -> remplissage EXACT, zéro trou.
  if lastFlex then sizes[lastFlex] = sizes[lastFlex] + (leftover - usedFlex) end

  -- 3) position de départ sur l'axe principal selon justify (seulement utile s'il reste de la place :
  --    avec un flex la place est déjà absorbée -> justify n'a d'effet que sans flex).
  local contentMain = gapsTotal
  for i = 1, n do contentMain = contentMain + sizes[i] end
  local free = max(0, mainAvail - contentMain)
  local justify = opts.justify or "start"
  local startMain = inner[main]
  local between = gap
  if flexTotal == 0 then
    if justify == "center" then startMain = startMain + floor(free / 2)
    elseif justify == "end" then startMain = startMain + free
    elseif justify == "between" and n > 1 then between = gap + free / (n - 1)
    elseif justify == "around" and n > 0 then local u = free / n; startMain = startMain + floor(u / 2); between = gap + u
    elseif justify == "evenly" and n > 0 then local u = free / (n + 1); startMain = startMain + floor(u); between = gap + u
    end
  end

  -- 4) émet les rects (axe principal = position courante ; axe croisé = align).
  local align = opts.align or "stretch"
  local cur = startMain
  for i = 1, n do
    local ms = sizes[i]
    local cs, cpos
    if align == "stretch" then
      cs = crossAvail; cpos = inner[cross]
    else
      -- enfant non-stretch : taille croisée = sa taille naturelle si fournie (table .h/.w), sinon = avail.
      local sp = specs[i]
      cs = (type(sp) == "table" and sp[crossSize]) or crossAvail
      if cs > crossAvail then cs = crossAvail end
      if align == "center" then cpos = inner[cross] + floor((crossAvail - cs) / 2)
      elseif align == "end" then cpos = inner[cross] + (crossAvail - cs)
      else cpos = inner[cross] end -- start
    end
    local rect = {}
    rect[main] = floor(cur + 0.5)
    rect[cross] = floor(cpos + 0.5)
    rect[mainSize] = floor(ms + 0.5)
    rect[crossSize] = floor(cs + 0.5)
    -- garantit { x, y, w, h } complets.
    out[i] = { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    cur = cur + ms + between
  end
  return out
end

function Layout.row(box, specs, opts) return flow("x", box, specs, opts) end
function Layout.column(box, specs, opts) return flow("y", box, specs, opts) end

-- Helper : rétrécir/insetter une boîte de `d` px (ou {l,t,r,b}) -> sous-boîte intérieure.
function Layout.inset(box, d)
  local l, t, r, b = pads(d)
  return { x = floor(box.x + l + 0.5), y = floor(box.y + t + 0.5),
    w = floor(box.w - l - r + 0.5), h = floor(box.h - t - b + 0.5) }
end

return Layout
