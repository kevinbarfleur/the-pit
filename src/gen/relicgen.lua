-- src/gen/relicgen.lua
-- GÉNÉRATEUR VISUEL DES RELIQUES (artefacts maudits) — port Lua/LÖVE du moteur de
-- docs/generation/generateur-reliques.html. Couche DATA/gen : la CONSTRUCTION de la grille est PURE
-- (zéro love.graphics) ; seul le BAKE (RelicGen.bake/cached) touche love.image/love.graphics — à la
-- demande, jamais par frame (cf. src/core/sprite.lua). Le RENDU ANIMÉ vit dans src/render/relic_anim.lua
-- (qui consomme RelicGen.view).
--
-- ── PRINCIPE (porté du HTML) ─────────────────────────────────────────────────────────────────────────
--   • Grille 40×40 (≫ l'ancien 16×16) : assez dense pour un VRAI objet maudit (silhouette + ombres +
--     highlight + contour 1px). Centrée, FOND TRANSPARENT (l'UI pose son cadre).
--   • Une relique = un MOTIF (parmi 26 : flame/heart/shield/bowl/…) + une PALETTE thématique (parmi 11 :
--     BLOOD/FIRE/ROT/POISON/BONE/IRON/GOLD/PALE/STONE/SHADOW/FLESH), chacune deep/sh/base/hi/accent.
--   • Le mapping VIS[relicId] -> {m, pal, anim, …} relie chaque relique réelle (cf. src/data/relics.lua /
--     RelicGen.order) à son visuel. Un ID non mappé retombe sur le motif 'gem' (fallback sûr).
--
-- ── FORMAT INTERNE (porté de makeGrid) ────────────────────────────────────────────────────────────────
--   grid = { w, h, data }  où data[y*w + x + 1] = { r, g, b } (floats 0..1) ou nil (transparent).
--   (1-indexé côté Lua ; les primitives écrivent via set(g,x,y,c) avec x,y 0-indexés, comme le HTML.)
--   Les couleurs sont des TABLES {r,g,b} : les palettes sont pré-converties une fois ; les littéraux hex
--   du HTML passent par hx("#rrggbb") (mémoïsé) -> même table partagée.
--
-- ── API (CONSERVÉE pour les appelants existants : miniatures STATIQUES) ───────────────────────────────
--   RelicGen.SIZE                 = 40 (côté de la grille carrée).
--   RelicGen.order                = liste ordonnée des ids (append-only, INCHANGÉE).
--   RelicGen.grid(id)             -> la grille COLORÉE {w,h,data} (ou nil si id inconnu). DATA pure.
--   RelicGen.view(id)             -> { g, pal, anim, … } (résultat de buildRelic) mémoïsé, pour relic_anim.
--   RelicGen.bake(id [,palette])  -> { image, w, h } (Image LÖVE nearest, grille STATIQUE) ou nil.
--   RelicGen.cached(id [,palette])-> idem bake, mémoïsé par id (une icône bakée une fois).
--   (le paramètre `palette` est ACCEPTÉ pour compat d'appel — ignoré : la relique porte sa propre palette.)
--
--   Réf API (vérifiée love2d.org/wiki via love-api 11.5) :
--     love.image.newImageData(w,h) ; ImageData:setPixel(x,y, r,g,b,a) (0-indexé, floats 0..1 depuis 11.0)
--     love.graphics.newImage(data) ; Image:setFilter("nearest","nearest").

local RelicGen = {}

RelicGen.SIZE = 40

local floor, sqrt, sin, cos, abs, max, min, ceil, PI =
  math.floor, math.sqrt, math.sin, math.cos, math.abs, math.max, math.min, math.ceil, math.pi

-- ═══════════════════════════ PRIMITIVES (port direct du HTML, 0-indexées) ═══════════════════════════
-- round() : arrondi commercial (Math.round du JS = floor(x+0.5) pour x>=0, géré pour les négatifs).
local function round(x) return floor(x + 0.5) end

local function makeGrid(w, h) return { w = w, h = h, data = {} } end

-- set(g,x,y,c) : pose la couleur c (table {r,g,b}) au pixel (x,y) (0-indexé) si dans la grille.
local function set(g, x, y, c)
  x = floor(x); y = floor(y)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
  g.data[y * g.w + x + 1] = c
end

local function ellipse(g, cx, cy, rx, ry, c)
  cx = round(cx); cy = round(cy); rx = max(1, round(rx)); ry = max(1, round(ry))
  for y = -ry, ry do
    for x = -rx, rx do
      if (x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.05 then set(g, cx + x, cy + y, c) end
    end
  end
end

local function disc(g, cx, cy, r, c)
  cx = round(cx); cy = round(cy); r = max(0, round(r))
  for y = -r, r do
    for x = -r, r do
      if x * x + y * y <= r * r + r * 0.5 then set(g, cx + x, cy + y, c) end
    end
  end
end

-- line : Bresenham (port direct).
local function line(g, x0, y0, x1, y1, c)
  x0 = round(x0); y0 = round(y0); x1 = round(x1); y1 = round(y1)
  local dx, dy = abs(x1 - x0), abs(y1 - y0)
  local sx = (x0 < x1) and 1 or -1
  local sy = (y0 < y1) and 1 or -1
  local err = dx - dy
  while true do
    set(g, x0, y0, c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

-- tube : enchaîne des discs d'un rayon interpolé r0->r1 le long d'une polyligne pts={{x,y},...}.
local function tube(g, pts, r0, r1, c)
  if #pts == 1 then disc(g, pts[1][1], pts[1][2], r0, c); return end
  local segLens, total = {}, 0
  for i = 2, #pts do
    local dx, dy = pts[i][1] - pts[i - 1][1], pts[i][2] - pts[i - 1][2]
    local l = sqrt(dx * dx + dy * dy)
    segLens[i - 1] = l; total = total + l
  end
  if total == 0 then disc(g, pts[1][1], pts[1][2], r0, c); return end
  local acc = 0
  for i = 2, #pts do
    local a, b, L = pts[i - 1], pts[i], segLens[i - 1]
    local steps = max(1, ceil(L))
    for s = 0, steps do
      local t = (acc + L * s / steps) / total
      local x = a[1] + (b[1] - a[1]) * s / steps
      local y = a[2] + (b[2] - a[2]) * s / steps
      local r = r0 + (r1 - r0) * t
      disc(g, x, y, r, c)
    end
    acc = acc + L
  end
end

-- polygon : remplissage scanline (port direct ; pts={{x,y},...}).
local function polygon(g, pts, c)
  local miny, maxy = math.huge, -math.huge
  for i = 1, #pts do miny = min(miny, pts[i][2]); maxy = max(maxy, pts[i][2]) end
  miny = floor(miny); maxy = ceil(maxy)
  for y = miny, maxy do
    local xs = {}
    for i = 1, #pts do
      local a = pts[i]
      local b = pts[(i % #pts) + 1]
      local y0, y1 = a[2], b[2]
      if (y0 <= y and y1 > y) or (y1 <= y and y0 > y) then
        xs[#xs + 1] = a[1] + (b[1] - a[1]) * (y - y0) / (y1 - y0)
      end
    end
    table.sort(xs)
    local k = 1
    while k + 1 <= #xs do
      for x = round(xs[k]), round(xs[k + 1]) do set(g, x, y, c) end
      k = k + 2
    end
  end
end

local function rectF(g, x0, y0, x1, y1, c)
  for y = y0, y1 do for x = x0, x1 do set(g, x, y, c) end end
end

-- outline : ajoute la couleur oc autour des pixels déjà posés (4-voisinage), sur les trous transparents.
local function outline(g, oc)
  local w, h = g.w, g.h
  local src = {}
  for i = 1, w * h do src[i] = g.data[i] end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local idx = y * w + x + 1
      if not src[idx] then
        local t = (x > 0 and src[idx - 1])
          or (x < w - 1 and src[idx + 1])
          or (y > 0 and src[idx - w])
          or (y < h - 1 and src[idx + w])
        if t then g.data[idx] = oc end
      end
    end
  end
end

-- ═══════════════════════════ COULEURS (hex -> table {r,g,b} floats) ═══════════════════════════
-- hx("#rrggbb") (ou "#rgb") -> { r, g, b } floats, mémoïsé (les littéraux du HTML partagent leur table).
local HXC = {}
local function hx(h)
  local got = HXC[h]; if got then return got end
  local s = h:gsub("#", "")
  if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
  local n = tonumber(s, 16) or 0
  local c = { (floor(n / 0x10000) % 0x100) / 255, (floor(n / 0x100) % 0x100) / 255, (n % 0x100) / 255 }
  HXC[h] = c
  return c
end

-- ── PALETTES thématiques (port de PAL) : deep/sh/base/hi/accent en tables floats. ──
local PAL = {
  BLOOD  = { deep = hx("#3a0a12"), sh = hx("#6e1322"), base = hx("#a81d33"), hi = hx("#d83b52"), accent = hx("#ff7283") },
  FIRE   = { deep = hx("#4a1402"), sh = hx("#8a2f06"), base = hx("#e0760f"), hi = hx("#ffc23a"), accent = hx("#fff1a0") },
  ROT    = { deep = hx("#1f2a14"), sh = hx("#3c4a1e"), base = hx("#6b7a2e"), hi = hx("#9fae42"), accent = hx("#c7d05a") },
  POISON = { deep = hx("#102a1a"), sh = hx("#1e4a2e"), base = hx("#2e7a4a"), hi = hx("#46c77a"), accent = hx("#7affb0") },
  BONE   = { deep = hx("#4a4636"), sh = hx("#7a745c"), base = hx("#b9b08c"), hi = hx("#e8e0c0"), accent = hx("#fffbe0") },
  IRON   = { deep = hx("#1c2026"), sh = hx("#3a424c"), base = hx("#6b7682"), hi = hx("#aab4c0"), accent = hx("#dfe6ee") },
  GOLD   = { deep = hx("#4a3408"), sh = hx("#8a6a14"), base = hx("#d8a82a"), hi = hx("#ffe35a"), accent = hx("#fff7c0") },
  PALE   = { deep = hx("#2a2e3a"), sh = hx("#4a5060"), base = hx("#8a90a4"), hi = hx("#cfd6e6"), accent = hx("#ffffff") },
  STONE  = { deep = hx("#232323"), sh = hx("#454548"), base = hx("#777a80"), hi = hx("#a8acb2"), accent = hx("#cfd2d6") },
  SHADOW = { deep = hx("#140a1e"), sh = hx("#2a1840"), base = hx("#4a2e72"), hi = hx("#7a52c0"), accent = hx("#b48aff") },
  FLESH  = { deep = hx("#3a2014"), sh = hx("#6e3a24"), base = hx("#a85a3c"), hi = hx("#d08a64"), accent = hx("#f0b38a") },
}
local OUTC = hx("#0c0810")

-- ═══════════════════════════ MOTIFS (port direct des m*) ═══════════════════════════
-- Signature : m(g, p, rnd, o)  où p = palette, rnd = fn aléatoire (réservée), o = options.
-- mFlame — flamme (port).
local function mFlame(g, p, rnd, o)
  o = o or {}
  local cx, cy, h, baseR = o.cx or 20, o.cy or 26, o.h or 18, o.baseR or 7
  for i = 0, h - 1 do
    local t = i / h
    local y = cy - i
    local r = baseR * (1 - t * 0.85) * (1 + 0.12 * sin(i * 0.8))
    if r < 0.6 then r = 0.6 end
    local col = (t < 0.22) and p.sh or ((t < 0.55) and p.base or ((t < 0.82) and p.hi or p.accent))
    disc(g, cx + round(sin(i * 0.5) * 1.2 * t), y, r, col)
  end
  for i = 2, h - 4 do
    local t = i / h
    local y = cy - i
    disc(g, cx + round(sin(i * 0.5) * 1.2 * t), y, max(0.6, baseR * 0.42 * (1 - t)), p.accent)
  end
end

-- mHeart — cœur (port ; courbe implicite). o.flame => petite flamme au-dessus.
local function mHeart(g, p, rnd, o)
  local cx, cy, s = 20, 20, 10
  for y = -s, s + 2 do
    for x = -s - 1, s + 1 do
      local nx = x / s
      local Y = -(y) / s + 0.28
      local v = (nx * nx + Y * Y - 1) ^ 3 - nx * nx * Y * Y * Y
      if v <= 0 then
        local col = p.base
        if y > s * 0.25 then col = p.sh end
        set(g, cx + x, cy + y, col)
      end
    end
  end
  disc(g, cx - 4, cy - 3, 3, p.hi); disc(g, cx - 4, cy - 3, 1, p.accent); line(g, cx, cy - 6, cx, cy + 2, p.sh)
  if o and o.flame then mFlame(g, p, rnd, { cx = cx, cy = cy - 6, h = 11, baseR = 4 }) end
end

-- mShield — bouclier (port). o.o = { crack, thorn, wave }.
local function mShield(g, p, rnd, o)
  local oo = (o and o.o) or {}
  local cx, cy = 20, 20
  polygon(g, { { cx - 10, cy - 11 }, { cx + 10, cy - 11 }, { cx + 10, cy - 1 }, { cx + 5, cy + 8 }, { cx, cy + 13 }, { cx - 5, cy + 8 }, { cx - 10, cy - 1 } }, p.sh)
  polygon(g, { { cx - 8, cy - 9 }, { cx + 8, cy - 9 }, { cx + 8, cy - 1 }, { cx + 4, cy + 6 }, { cx, cy + 10 }, { cx - 4, cy + 6 }, { cx - 8, cy - 1 } }, p.base)
  line(g, cx - 8, cy - 9, cx + 8, cy - 9, p.hi); disc(g, cx, cy - 1, 3, p.hi); disc(g, cx, cy - 1, 2, p.accent)
  if oo.crack then
    line(g, cx + 2, cy - 8, cx - 1, cy + 2, p.deep); line(g, cx - 1, cy + 2, cx + 2, cy + 9, p.deep); line(g, cx - 1, cy + 2, cx - 4, cy + 5, p.deep)
  end
  if oo.thorn then
    for i = -2, 2 do local tx = cx + i * 5; polygon(g, { { tx - 1, cy - 11 }, { tx + 1, cy - 11 }, { tx, cy - 15 } }, p.accent) end
  end
  if oo.wave then
    for i = -1, 2 do
      local wy = cy - 2 + i * 3
      line(g, cx - 7, wy, cx - 3, wy - 1, p.hi); line(g, cx - 3, wy - 1, cx + 1, wy, p.hi); line(g, cx + 1, wy, cx + 5, wy - 1, p.hi)
    end
  end
end

-- mBowl — calice (port). o.lp = palette du liquide, o.bubbles.
local function mBowl(g, p, rnd, o)
  local lp = (o and o.lp) or p
  local cx, cy = 20, 22
  for y = 0, 9 do for x = -12, 12 do if (x * x) / 144 + (y * y) / 100 <= 1 and y >= 0 then set(g, cx + x, cy + y, p.sh) end end end
  for y = 1, 9 do for x = -11, 11 do if (x * x) / 121 + (y * y) / 81 <= 1 and y >= 1 then set(g, cx + x, cy + y, p.base) end end end
  ellipse(g, cx, cy, 12, 2, p.hi); ellipse(g, cx, cy, 10, 1.6, lp.base); ellipse(g, cx, cy, 10, 1.3, lp.hi); disc(g, cx + 4, cy, 1, lp.accent)
  if o and o.bubbles then disc(g, cx - 4, cy - 1, 1, lp.hi); disc(g, cx + 2, cy - 2, 1, lp.accent); disc(g, cx + 6, cy - 1, 1, lp.hi) end
  rectF(g, cx - 3, cy + 10, cx + 3, cy + 12, p.sh); rectF(g, cx - 6, cy + 12, cx + 6, cy + 13, p.base)
end

-- mNail — clou (port).
local function mNail(g, p, rnd, o)
  local cx = 20
  ellipse(g, cx, 9, 6, 2, p.sh); ellipse(g, cx, 8, 6, 2, p.base); line(g, cx - 5, 7, cx + 5, 7, p.hi)
  tube(g, { { cx, 10 }, { cx, 28 } }, 3, 0.6, p.sh); tube(g, { { cx, 10 }, { cx, 28 } }, 2, 0.4, p.base); line(g, cx - 1, 11, cx - 1, 26, p.hi)
end

-- mMushroom — champignon (port).
local function mMushroom(g, p, rnd, o)
  local cx, cy = 20, 18
  for y = -8, 2 do for x = -12, 12 do if (x * x) / 144 + (y * y) / 81 <= 1 and y <= 2 then set(g, cx + x, cy + y, p.sh) end end end
  for y = -7, 1 do for x = -11, 11 do if (x * x) / 121 + (y * y) / 64 <= 1 and y <= 1 then set(g, cx + x, cy + y, p.base) end end end
  ellipse(g, cx - 3, cy - 4, 4, 2, p.hi); disc(g, cx - 5, cy - 3, 1, p.accent); disc(g, cx + 4, cy - 2, 1, p.accent); disc(g, cx, cy - 5, 1, p.accent)
  rectF(g, cx - 11, cy + 1, cx + 11, cy + 2, p.deep); tube(g, { { cx, cy + 2 }, { cx, cy + 15 } }, 3, 4, p.sh); tube(g, { { cx, cy + 2 }, { cx, cy + 14 } }, 2, 3, p.base); line(g, cx - 1, cy + 3, cx - 1, cy + 13, p.hi)
end

-- mBalance — balance penchée (port).
local function mBalance(g, p, rnd, o)
  local cx = 20
  tube(g, { { cx, 8 }, { cx, 30 } }, 1.4, 1.4, p.sh); line(g, cx - 12, 12, cx + 12, 12, p.base); line(g, cx - 12, 11, cx + 12, 11, p.hi); disc(g, cx, 8, 2, p.hi); rectF(g, cx - 4, 30, cx + 4, 31, p.sh)
  for s = -1, 1, 2 do
    local px = cx + s * 12
    line(g, px, 12, px - 3, 20, p.deep); line(g, px, 12, px + 3, 20, p.deep)
    for x = -4, 4 do set(g, px + x, 20, p.base) end
    for x = -3, 3 do set(g, px + x, 21, p.sh) end
  end
  rectF(g, cx - 13, 18, cx - 10, 19, p.hi)
end

-- mChoir — chœur de gorges creuses (port). '#0a0307' littéral.
local function mChoir(g, p, rnd, o)
  local cy = 20
  local dark = hx("#0a0307")
  for k = -1, 1 do
    local cx = 20 + k * 10
    ellipse(g, cx, cy, 5, 8, p.sh); ellipse(g, cx, cy, 4, 7, p.deep); ellipse(g, cx, cy, 2.4, 5, dark)
    for i = -2, 2 do set(g, cx + i, cy - 5, p.hi); set(g, cx + i, cy + 5, p.base) end
  end
end

-- mMaw — gueule (port). o.wide => plus large.
local function mMaw(g, p, rnd, o)
  local cx, cy = 20, 20
  local wide = o and o.wide
  local rw = wide and 14 or 12
  local dark = hx("#0a0307")
  ellipse(g, cx, cy, rw, 9, p.sh); ellipse(g, cx, cy, rw - 1, 8, p.deep); ellipse(g, cx, cy, rw - 3, 6, dark)
  for i = -3, 3 do local tx = cx + i * 3; polygon(g, { { tx - 1.6, cy - 8 }, { tx + 1.6, cy - 8 }, { tx, cy - 3 } }, p.hi) end
  for j = -3, 3 do local bx = cx + j * 3 + 1; polygon(g, { { bx - 1.6, cy + 8 }, { bx + 1.6, cy + 8 }, { bx, cy + 3 } }, p.base) end
end

-- mWhetstone — pierre à aiguiser (port).
local function mWhetstone(g, p, rnd, o)
  local cx, cy = 20, 22
  polygon(g, { { cx - 13, cy + 2 }, { cx + 11, cy - 4 }, { cx + 13, cy + 1 }, { cx - 11, cy + 7 } }, p.sh)
  polygon(g, { { cx - 12, cy + 2 }, { cx + 10, cy - 3 }, { cx + 11, cy }, { cx - 11, cy + 6 } }, p.base)
  line(g, cx - 12, cy + 2, cx + 10, cy - 3, p.hi)
  polygon(g, { { cx - 6, cy - 3 }, { cx + 2, cy - 5 }, { cx + 3, cy - 3 }, { cx - 5, cy - 1 } }, p.hi)
end

-- mFeather — plume (port).
local function mFeather(g, p, rnd, o)
  local cx = 20
  tube(g, { { cx + 6, 32 }, { cx - 3, 8 } }, 0.8, 0.8, p.sh)
  for i = 0, 21 do
    local t = i / 22
    local bx = cx + 6 - 9 * t
    local by = 32 - 24 * t
    local len = 6 * (1 - abs(t - 0.45) * 1.4)
    if len >= 1 then line(g, bx, by, bx - len, by - len * 0.4, p.base); line(g, bx, by, bx + len * 0.7, by - len * 0.5, p.hi) end
  end
  disc(g, cx - 3, 8, 1, p.accent)
end

-- mTongue — langue fourchue (port).
local function mTongue(g, p, rnd, o)
  local cx = 20
  tube(g, { { cx, 30 }, { cx, 16 } }, 2.4, 1.6, p.sh); tube(g, { { cx, 30 }, { cx, 16 } }, 1.6, 1, p.base)
  tube(g, { { cx, 16 }, { cx - 5, 8 } }, 1.2, 0.5, p.base); tube(g, { { cx, 16 }, { cx + 5, 8 } }, 1.2, 0.5, p.base)
  line(g, cx - 1, 28, cx - 1, 17, p.hi); disc(g, cx - 5, 8, 1, p.accent); disc(g, cx + 5, 8, 1, p.accent)
end

-- mDrop — goutte ou PLAIE (o.wound). '#1a0307' littéral.
local function mDrop(g, p, rnd, o)
  local cx, cy = 20, 19
  if o and o.wound then
    local woundDark = hx("#1a0307")
    ellipse(g, cx, cy + 2, 10, 12, p.sh); ellipse(g, cx, cy + 2, 9, 11, p.base)
    for y = -9, 9 do local w = round(3 * (1 - (y * y) / 81)); for x = -w, w do set(g, cx + x, cy + 2 + y, p.deep) end end
    for y = -7, 7 do local w = round(1.6 * (1 - (y * y) / 49)); for x = -w, w do set(g, cx + x, cy + 2 + y, woundDark) end end
    line(g, cx - 3, cy - 5, cx - 2, cy + 6, p.accent); line(g, cx + 3, cy - 5, cx + 2, cy + 6, p.accent)
    return
  end
  disc(g, cx, cy + 4, 6, p.sh); disc(g, cx, cy + 4, 5, p.base)
  polygon(g, { { cx - 5, cy + 4 }, { cx + 5, cy + 4 }, { cx, cy - 8 } }, p.sh)
  polygon(g, { { cx - 4, cy + 4 }, { cx + 4, cy + 4 }, { cx, cy - 6 } }, p.base)
  disc(g, cx - 1, cy + 3, 2, p.hi); disc(g, cx - 1, cy + 2, 1, p.accent)
end

-- mBook — grimoire (port).
local function mBook(g, p, rnd, o)
  local cx, cy = 20, 20
  rectF(g, cx - 11, cy - 12, cx + 11, cy + 12, p.sh); rectF(g, cx - 10, cy - 11, cx + 10, cy + 11, p.base)
  rectF(g, cx + 7, cy - 12, cx + 11, cy + 12, p.deep); rectF(g, cx - 12, cy - 10, cx - 11, cy + 10, p.hi)
  disc(g, cx - 1, cy - 1, 3, p.accent)
  for i = -3, 3 do line(g, cx - 7, cy + i * 2.6, cx + 5, cy + i * 2.6, p.deep) end
end

-- mLetter — lettre scellée (o.seal = palette du sceau).
local function mLetter(g, p, rnd, o)
  local cx, cy = 20, 20
  local seal = (o and o.seal) or p
  rectF(g, cx - 12, cy - 8, cx + 12, cy + 9, p.sh); rectF(g, cx - 11, cy - 7, cx + 11, cy + 8, p.base)
  polygon(g, { { cx - 11, cy - 7 }, { cx + 11, cy - 7 }, { cx, cy + 2 } }, p.sh)
  line(g, cx - 11, cy - 7, cx, cy + 2, p.hi); line(g, cx + 11, cy - 7, cx, cy + 2, p.hi)
  disc(g, cx, cy + 1, 3, seal.base); disc(g, cx, cy + 1, 2, seal.accent)
end

-- mLantern — lanterne (o.gp = palette de la flamme/lueur).
local function mLantern(g, p, rnd, o)
  local gp = (o and o.gp) or p
  local cx, cy = 20, 20
  for a = 0, 15 do local an = PI + a / 16 * PI; set(g, round(cx + cos(an) * 4), round(6 + sin(an) * 4), p.hi) end
  rectF(g, cx - 1, 8, cx + 1, 10, p.sh)
  polygon(g, { { cx - 7, 11 }, { cx + 7, 11 }, { cx + 4, 8 }, { cx - 4, 8 } }, p.sh)
  rectF(g, cx - 7, 11, cx + 7, 28, p.deep); rectF(g, cx - 6, 12, cx + 6, 27, p.sh); rectF(g, cx - 5, 13, cx + 5, 26, gp.deep)
  disc(g, cx, cy + 1, 4, gp.base); disc(g, cx, cy + 1, 2, gp.accent)
  line(g, cx, 11, cx, 28, p.sh); line(g, cx - 7, 19, cx + 7, 19, p.sh); rectF(g, cx - 6, 28, cx + 6, 30, p.base)
end

-- mCoin — pièce (port).
local function mCoin(g, p, rnd, o)
  local cx, cy = 20, 20
  disc(g, cx, cy, 11, p.sh); disc(g, cx, cy, 10, p.base); disc(g, cx, cy, 9, p.sh); disc(g, cx, cy, 8, p.base)
  ellipse(g, cx - 3, cy - 4, 3, 2, p.hi); line(g, cx, cy - 5, cx, cy + 5, p.deep); line(g, cx - 4, cy, cx + 4, cy, p.deep)
  for a = 0, 35 do local an = a / 36 * 6.283; set(g, round(cx + cos(an) * 11), round(cy + sin(an) * 11), p.hi) end
end

-- mBanner — bannière (port).
local function mBanner(g, p, rnd, o)
  local cx = 18
  tube(g, { { cx - 9, 7 }, { cx - 9, 32 } }, 1.2, 1.2, p.sh); disc(g, cx - 9, 7, 2, p.hi)
  polygon(g, { { cx - 8, 9 }, { cx + 10, 9 }, { cx + 10, 27 }, { cx + 1, 31 }, { cx - 8, 27 } }, p.base)
  rectF(g, cx + 6, 9, cx + 10, 27, p.sh); line(g, cx - 8, 9, cx + 10, 9, p.hi); disc(g, cx + 1, 18, 3, p.deep); disc(g, cx + 1, 18, 2, p.accent)
end

-- mEye — œil (port). '#e8e0d0', '#100a14', '#ffffff' littéraux.
local function mEye(g, p, rnd, o)
  local cx, cy = 20, 20
  ellipse(g, cx, cy, 13, 8, p.sh); ellipse(g, cx, cy, 12, 7, hx("#e8e0d0"))
  disc(g, cx, cy, 5, p.base); disc(g, cx, cy, 4, p.accent); disc(g, cx, cy, 2, hx("#100a14")); disc(g, cx - 1, cy - 1, 1, hx("#ffffff"))
  for x = -12, 12 do
    local yy = round(-sqrt(max(0, 1 - (x * x) / 169)) * 8)
    set(g, cx + x, cy + yy, p.deep); set(g, cx + x, cy - yy, p.deep)
  end
end

-- mCrown — couronne (port).
local function mCrown(g, p, rnd, o)
  local cx, cy = 20, 22
  rectF(g, cx - 11, cy, cx + 11, cy + 6, p.sh); rectF(g, cx - 10, cy + 1, cx + 10, cy + 5, p.base); line(g, cx - 10, cy + 1, cx + 10, cy + 1, p.hi)
  for i = -2, 2 do local px = cx + i * 5; polygon(g, { { px - 3, cy }, { px + 3, cy }, { px, cy - 8 } }, p.base) end
  for i = -2, 2 do
    local px = cx + i * 5
    line(g, px - 3, cy, px, cy - 8, p.hi); line(g, px + 3, cy, px, cy - 8, p.sh); disc(g, px, cy - 7, 1, p.accent)
  end
  for j = -1, 1 do disc(g, cx + j * 6, cy + 3, 1, p.accent) end
end

-- mRibs — cage thoracique (port).
local function mRibs(g, p, rnd, o)
  local cx = 20
  tube(g, { { cx, 8 }, { cx, 30 } }, 1.6, 1.6, p.sh)
  for i = 0, 4 do
    local y = 11 + i * 4
    local w = 11 - i
    for s = -1, 1, 2 do line(g, cx, y, cx + s * w, y + 3, p.base); line(g, cx + s * w, y + 3, cx + s * (w - 2), y + 7, p.base) end
  end
  disc(g, cx, 8, 2, p.hi)
end

-- mBoil — pustule (port).
local function mBoil(g, p, rnd, o)
  local cx, cy = 20, 20
  disc(g, cx, cy, 10, p.sh); disc(g, cx, cy, 9, p.base)
  local pts = { { cx - 4, cy - 3 }, { cx + 4, cy - 2 }, { cx - 2, cy + 4 }, { cx + 3, cy + 4 }, { cx, cy - 1 } }
  for i = 1, #pts do disc(g, pts[i][1], pts[i][2], 2, p.sh); disc(g, pts[i][1], pts[i][2], 1, p.accent) end
  ellipse(g, cx - 3, cy - 4, 3, 2, p.hi)
end

-- mShovel — bêche (port).
local function mShovel(g, p, rnd, o)
  local cx = 20
  tube(g, { { cx, 8 }, { cx, 22 } }, 1.4, 1.4, p.sh)
  for a = 0, 15 do local an = PI + a / 16 * PI; set(g, round(cx + cos(an) * 3), round(8 + sin(an) * 3), p.hi) end
  polygon(g, { { cx - 7, 22 }, { cx + 7, 22 }, { cx + 6, 30 }, { cx, 34 }, { cx - 6, 30 } }, p.sh)
  polygon(g, { { cx - 6, 23 }, { cx + 6, 23 }, { cx + 5, 29 }, { cx, 33 }, { cx - 5, 29 } }, p.base)
  line(g, cx - 6, 23, cx + 6, 23, p.hi)
end

-- mGrave — pierre tombale (port).
local function mGrave(g, p, rnd, o)
  local cx, cy = 20, 20
  for y = -12, 12 do
    for x = -9, 9 do
      local top
      if y < -6 then top = (abs(x) <= sqrt(max(0, 1 - ((y + 6) * (y + 6)) / 36)) * 9) else top = true end
      if top and y <= 12 then set(g, cx + x, cy + y, (x > 5) and p.sh or p.base) end
    end
  end
  rectF(g, cx - 1, cy - 7, cx + 1, cy + 3, p.deep); rectF(g, cx - 4, cy - 4, cx + 4, cy - 2, p.deep); ellipse(g, cx, cy + 13, 12, 2, p.deep)
end

-- mShell — coquille (port).
local function mShell(g, p, rnd, o)
  local cx, cy = 20, 21
  for y = -10, 4 do for x = -13, 13 do if (x * x) / 169 + (y * y) / 121 <= 1 and y <= 4 then set(g, cx + x, cy + y, p.sh) end end end
  for y = -9, 3 do for x = -12, 12 do if (x * x) / 144 + (y * y) / 100 <= 1 and y <= 3 then set(g, cx + x, cy + y, p.base) end end end
  for k = -2, 2 do
    local rx = cx + k * 5
    for yy = -9, 3 do if (rx - cx) * (rx - cx) / 169 + (yy * yy) / 121 <= 1 then set(g, rx, cy + yy, p.deep) end end
  end
  ellipse(g, cx - 3, cy - 5, 4, 2, p.hi); rectF(g, cx - 12, cy + 3, cx + 12, cy + 4, p.deep)
end

-- mGem — gemme (fallback ; port).
local function mGem(g, p, rnd, o)
  local cx, cy = 20, 20
  polygon(g, { { cx, cy - 11 }, { cx + 9, cy - 2 }, { cx + 6, cy + 10 }, { cx - 6, cy + 10 }, { cx - 9, cy - 2 } }, p.sh)
  polygon(g, { { cx, cy - 9 }, { cx + 7, cy - 2 }, { cx + 5, cy + 8 }, { cx - 5, cy + 8 }, { cx - 7, cy - 2 } }, p.base)
  polygon(g, { { cx, cy - 9 }, { cx + 7, cy - 2 }, { cx, cy - 2 } }, p.hi)
  disc(g, cx - 2, cy - 3, 1, p.accent)
end

local MOTIF = {
  flame = mFlame, heart = mHeart, shield = mShield, bowl = mBowl, nail = mNail, mushroom = mMushroom,
  balance = mBalance, choir = mChoir, maw = mMaw, whetstone = mWhetstone, feather = mFeather, tongue = mTongue,
  drop = mDrop, book = mBook, letter = mLetter, lantern = mLantern, coin = mCoin, banner = mBanner, eye = mEye,
  crown = mCrown, ribs = mRibs, boil = mBoil, shovel = mShovel, grave = mGrave, shell = mShell, gem = mGem,
}

-- ═══════════════════════════ MAPPING relique -> visuel (port de VIS) ═══════════════════════════
local VIS = {
  bloodstone       = { m = "heart",     pal = "BLOOD",  anim = { "beat" } },
  carapace         = { m = "shell",     pal = "FLESH",  anim = { "harden" } },
  aegis            = { m = "shield",    pal = "IRON",   anim = { "ward" }, o = { crack = true } },
  kings_bowl       = { m = "bowl",      pal = "IRON",   lp = "POISON", anim = { "brew" } },
  ember_heart      = { m = "heart",     pal = "FIRE",   anim = { "beat", "flicker" }, flame = true },
  weeping_nail     = { m = "nail",      pal = "IRON",   anim = { "drip" }, drop = "BLOOD" },
  grave_cap        = { m = "mushroom",  pal = "ROT",    anim = { "spore", "pulse" } },
  famines_math     = { m = "balance",   pal = "BONE",   anim = { "sway" } },
  hollow_choir     = { m = "choir",     pal = "PALE",   anim = { "chant" } },
  feeding_frenzy   = { m = "maw",       pal = "BONE",   anim = { "chatter" } },
  whetstone        = { m = "whetstone", pal = "STONE",  anim = { "spark" } },
  thornguard       = { m = "shield",    pal = "IRON",   anim = { "bristle" }, o = { thorn = true } },
  sacred_shield    = { m = "shield",    pal = "GOLD",   anim = { "barrier" } },
  second_breath    = { m = "feather",   pal = "PALE",   anim = { "drift" } },
  forked_tongue    = { m = "tongue",    pal = "BLOOD",  anim = { "flick" } },
  everburn         = { m = "flame",     pal = "FIRE",   anim = { "flicker" } },
  open_wounds      = { m = "drop",      pal = "BLOOD",  anim = { "drip" }, wound = true },
  plague_communion = { m = "bowl",      pal = "IRON",   lp = "SHADOW", anim = { "brew", "spore" }, bubbles = true },
  carrion_ledger   = { m = "book",      pal = "BONE",   anim = { "strike" } },
  black_summons    = { m = "letter",    pal = "SHADOW", anim = { "sealpulse" }, seal = "BLOOD" },
  beggars_lantern  = { m = "lantern",   pal = "IRON",   gp = "FIRE", anim = { "flicker" } },
  usurers_ledger   = { m = "book",      pal = "GOLD",   anim = { "pageflip" } },
  tithe_bowl       = { m = "bowl",      pal = "GOLD",   lp = "GOLD", anim = { "coinpop" } },
  paupers_boon     = { m = "coin",      pal = "GOLD",   anim = { "coinspin" } },
  grave_robbers_cut = { m = "shovel",   pal = "IRON",   anim = { "dig" } },
  blood_banner     = { m = "banner",    pal = "BLOOD",  anim = { "sway" } },
  seers_mark       = { m = "eye",       pal = "POISON", anim = { "blink" } },
  carrion_feast    = { m = "ribs",      pal = "BONE",   anim = { "pulse" } },
  second_plague    = { m = "boil",      pal = "POISON", anim = { "pulse", "spore" } },
  tide_caller      = { m = "shield",    pal = "PALE",   anim = { "waveflow" }, o = { wave = true } },
  bait_lantern     = { m = "lantern",   pal = "IRON",   gp = "POISON", anim = { "flicker", "lure" } },
  echo_crown       = { m = "crown",     pal = "GOLD",   anim = { "echo" } },
  gravediggers_due = { m = "grave",     pal = "STONE",  anim = { "mist" } },
  splitting_maw    = { m = "maw",       pal = "BLOOD",  anim = { "chatter" }, wide = true },
  -- ── W1 — axe type-identité (3 reliques) : motifs/palettes distincts des existants (réconciliation 1:1). ──
  pack_blood       = { m = "maw",       pal = "FLESH",  anim = { "chatter" } },          -- la meute affamée (gueule, chair)
  bile_orb         = { m = "bowl",      pal = "SHADOW", lp = "POISON", anim = { "brew" } }, -- globe d'eau noire (vase, venin)
  prismatic_wraith = { m = "gem",       pal = "SHADOW", anim = { "pulse" } },             -- le prisme multi-facettes
  -- W3 - axe mimetisme/amplification : meta-multiplicateurs d'auras, append-only avec Relics.order.
  zenith_stone     = { m = "gem",       pal = "GOLD",   anim = { "pulse", "spark" } },
  forked_echo      = { m = "choir",     pal = "SHADOW", anim = { "echo", "chant" } },
  link_cable       = { m = "nail",      pal = "IRON",   anim = { "spark" } },
  -- W4 - axe tank/removal/execution : le finish d'equipe (cage thoracique pale = le faucheur) + l'anti-mur (bloc de
  -- siege en fer, distinct du whetstone par la palette). Append-only avec Relics.order (reconciliation 1:1).
  reapers_scythe   = { m = "ribs",      pal = "PALE",   anim = { "mist" } },             -- le faucheur d'equipe (os, brume froide)
  siege_hammer     = { m = "whetstone", pal = "IRON",   anim = { "spark" } },            -- le marteau de siege (fer lourd, etincelle d'impact)
}
RelicGen.VIS = VIS
RelicGen.PAL = PAL

-- Les motifs portés sont DÉTERMINISTES par construction (aucun ne lit `rnd`). On fournit un stub pour
-- respecter la signature m(g,p,rnd,o) du HTML sans dépendance bit (mulberry32 inutile ici).
local function rndStub() return 0 end

-- ═══════════════════════════ buildRelic (port) ═══════════════════════════
-- Construit la grille COLORÉE + les métadonnées d'animation pour `id`. PUR (aucun love.*).
-- Renvoie une `view` = { g, pal, anim, dropPal, liquid, glowPal, flamePal, dripX, dripY, flameTop, flameBase }.
local function buildRelic(id)
  local v = VIS[id] or { m = "gem", pal = "STONE", anim = { "pulse" } }
  local p = PAL[v.pal] or PAL.STONE
  local g = makeGrid(40, 40)
  local opt = {
    lp = v.lp and PAL[v.lp] or p,
    gp = v.gp and PAL[v.gp] or p,
    o = v.o or {},
    seal = v.seal and PAL[v.seal] or p,
    wide = v.wide, wound = v.wound, flame = v.flame, bubbles = v.bubbles,
  }
  ;(MOTIF[v.m] or mGem)(g, p, rndStub, opt)
  outline(g, OUTC)

  local view = {
    g = g, pal = p, anim = v.anim or {},
    dropPal = v.drop and PAL[v.drop] or p,
    liquid = v.lp and PAL[v.lp] or p,
    glowPal = v.gp and PAL[v.gp] or p,
    flamePal = (v.m == "lantern") and (v.gp and PAL[v.gp] or p) or p,
    dripX = 20, dripY = (v.m == "nail") and 28 or 24,
  }
  if v.m == "flame" then view.flameTop, view.flameBase = 8, 24
  elseif v.m == "lantern" then view.flameTop, view.flameBase = 14, 24
  elseif v.m == "heart" and v.flame then view.flameTop, view.flameBase = 10, 14
  else view.flameTop, view.flameBase = 10, 22 end
  return view
end

-- ═══════════════════════════ API publique ═══════════════════════════
-- Cache des `view` (data pure) par id — partagé bake() / view() / relic_anim.lua.
local VIEWCACHE = {}
local function viewOf(id)
  local got = VIEWCACHE[id]
  if got == nil then
    got = buildRelic(id)
    VIEWCACHE[id] = got
  end
  return got
end

-- view(id) -> { g, pal, anim, … } (mémoïsé). Pour le rendu ANIMÉ (relic_anim). nil-safe : id toujours
-- mappé (fallback gem dans buildRelic) -> jamais nil pour un id non-vide.
function RelicGen.view(id)
  if type(id) ~= "string" or id == "" then return nil end
  return viewOf(id)
end

-- grid(id) -> la grille COLORÉE {w,h,data} (ou nil si id absent de l'ORDRE). DATA pure (aucun love.*).
-- (un id inconnu hors-ordre renvoie nil, comme l'API historique ; un id de l'ordre est toujours mappé.)
local ORDERSET
local function inOrder(id)
  if not ORDERSET then
    ORDERSET = {}
    for _, k in ipairs(RelicGen.order) do ORDERSET[k] = true end
  end
  return ORDERSET[id] == true
end
function RelicGen.grid(id)
  if not inOrder(id) then return nil end
  return viewOf(id).g
end

-- ── BAKE STATIQUE : grille colorée -> { image, w, h } (Image LÖVE nearest). Headless-safe (no-op du
-- mock sur newImageData/newImage/setFilter). À appeler une fois (chargement/galerie), JAMAIS par frame. ──
local function bakeGrid(g)
  local w, h = g.w, g.h
  local data = love.image.newImageData(w, h) -- transparent par défaut
  for y = 0, h - 1 do
    local row = y * w
    for x = 0, w - 1 do
      local c = g.data[row + x + 1]
      if c then data:setPixel(x, y, c[1], c[2], c[3], 1) end
    end
  end
  local img = love.graphics.newImage(data)
  if img.setFilter then img:setFilter("nearest", "nearest") end
  return { image = img, w = w, h = h }
end

-- bake(id [,palette]) -> { image, w, h } ou nil si id inconnu. `palette` ignoré (compat d'appel : la
-- relique porte sa propre palette thématique). Requiert love.image/love.graphics.
function RelicGen.bake(id, _palette)
  if not inOrder(id) then return nil end
  if not (love and love.image and love.graphics and love.image.newImageData and love.graphics.newImage) then return nil end
  return bakeGrid(viewOf(id).g)
end

-- cached(id [,palette]) -> bake mémoïsé par id (une icône bakée une fois, réutilisée par tous les appelants).
local BAKECACHE = {}
function RelicGen.cached(id, palette)
  local got = BAKECACHE[id]
  if not got then
    got = RelicGen.bake(id, palette)
    BAKECACHE[id] = got
  end
  return got
end

-- Réinitialise les caches bakés (changement de contexte LÖVE / tests). Les `view` (data pure) restent.
function RelicGen.clearBaked() BAKECACHE = {} end

-- ── ORDRE (append-only, INCHANGÉ : source de vérité des ids présents au cabinet) ──
RelicGen.order = {
  "bloodstone", "carapace", "whetstone", "aegis",
  "kings_bowl", "ember_heart", "weeping_nail", "grave_cap",
  "hollow_choir", "famines_math", "feeding_frenzy", "sacred_shield",
  -- vagues 3-4 (append-only)
  "second_breath", "thornguard", "forked_tongue", "everburn",
  "plague_communion", "open_wounds",
  -- vague 5 : reliques d'économie / boutique (append-only)
  "usurers_ledger", "tithe_bowl", "paupers_boon", "grave_robbers_cut",
  "beggars_lantern", "black_summons", "carrion_ledger",
  -- refonte 2026-06 (relics-overhaul) — NOUVELLES (append-only)
  "blood_banner", "seers_mark", "carrion_feast", "second_plague", "tide_caller", "bait_lantern",
  "echo_crown", "gravediggers_due", "splitting_maw",
  -- W1 — axe type-identité (mono-type amps + rainbow team payoff ; plan big-update §AXE 2)
  "pack_blood", "bile_orb", "prismatic_wraith",
  -- W3 - axe mimetisme/amplification (meta-multiplicateurs)
  "zenith_stone", "forked_echo", "link_cable",
  -- W4 - axe tank/removal/execution (finish d'equipe + anti-mur ; plan big-update §AXE 7)
  "reapers_scythe", "siege_hammer",
}

return RelicGen
