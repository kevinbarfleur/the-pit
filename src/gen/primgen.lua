-- src/gen/primgen.lua
-- GENERATEUR PAR PRIMITIVES v3 (« bestiaire modulaire » : corps EXCLUSIFS + ancrage semantique).
--
-- Idee : on DESSINE chaque creature dans une grille 64x64 avec des PRIMITIVES vectorielles rasterisees
-- (ellipse/disc/tube/tentacle/polygon), un ombrage VOLUMETRIQUE (`mass` = ellipses empilees + dither rings),
-- de VRAIS os (skull/spineRibs/boneLimb), puis une passe de TRAITEMENT par famille (corruption ANCREE).
-- Composition : FAMILLE (palette + treat) x ARCHETYPE (silhouette) + seed -> deterministe.
--
-- TROIS PRINCIPES v3 :
--   (1) Corps EXCLUSIFS  : 16 archetypes, aucun partage entre familles (les morts-vivants n'ont pas le
--       corps des demons). (2) VRAIS squelettes (crane/cotes/colonne/os articules), pas des masses.
--   (3) Ancrage semantique : chaque archetype DECLARE son anatomie `A` = { head, faceDir, spine, limbs,
--       belly, mass, tailBase, flesh }. Les `treat()` posent degats/yeux/cornes AUX BONS ANCRAGES
--       (jamais une tete flottante). Ajouter une famille = une palette + une passe `treat`.
--
-- RENDER-only (zero love.graphics par frame) : bake une fois en Image nearest (cf. src/core/sprite.lua),
-- via love.image.newImageData / ImageData:setPixel (floats 0..1) / love.graphics.newImage (API verifiee).
-- RNG = love.math.newRandomGenerator(seed) ; rng:random()->[0,1). Meme seed => creature identique
-- (snapshot async / replays). Le MAPPING unite->(famille,arch,palette,seed) vit dans creaturegen.cached.

local Primgen = {}

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local sin, cos, sqrt, huge = math.sin, math.cos, math.sqrt, math.huge
local function round(x) return floor(x + 0.5) end
local function hypot(a, b) return sqrt(a * a + b * b) end

-- ─────────────────────────── Grille + ecriture ───────────────────────────
local function makeGrid(w, h) return { w = w, h = h, data = {}, eyes = {} } end
-- set(.., nil) EFFACE le pixel (les traitements de pourriture creusent des trous via set(..,nil)).
local function set(g, x, y, c)
  x = floor(x); y = floor(y)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
  g.data[y * g.w + x] = c
end

-- ─────────────────────────── Primitives ───────────────────────────
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

local function line(g, x0, y0, x1, y1, c)
  x0 = round(x0); y0 = round(y0); x1 = round(x1); y1 = round(y1)
  local dx = math.abs(x1 - x0); local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1; local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    set(g, x0, y0, c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

-- tube : disques le long d'une polyligne, rayon interpole r0->r1. pts = { {x,y}, ... }
local function tube(g, pts, r0, r1, c)
  if #pts == 1 then disc(g, pts[1][1], pts[1][2], r0, c); return end
  local segLens, total = {}, 0
  for i = 2, #pts do
    local l = hypot(pts[i][1] - pts[i - 1][1], pts[i][2] - pts[i - 1][2])
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
      disc(g, x, y, r0 + (r1 - r0) * t, c)
    end
    acc = acc + L
  end
end

local function polygon(g, pts, c)
  local miny, maxy = huge, -huge
  for i = 1, #pts do miny = min(miny, pts[i][2]); maxy = max(maxy, pts[i][2]) end
  miny = floor(miny); maxy = ceil(maxy)
  for y = miny, maxy do
    local xs = {}
    for i = 1, #pts do
      local a = pts[i]; local b = pts[(i % #pts) + 1]
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

local function tentacle(g, x0, y0, len, dir, amp, r0, r1, c)
  local seg = max(4, floor(len / 2)); local pts = {}
  for s = 0, seg do
    local t = s / seg
    pts[#pts + 1] = { round(x0 + sin(t * 3.0 + dir) * amp * t), round(y0 + len * t) }
  end
  tube(g, pts, r0, r1, c)
end

-- tentacule RADIALE (part d'un centre vers un angle, ondulation) — couronnes de cephalo/oeil.
local function radTentacle(g, cx, cy, ang, len, amp, r0, r1, c)
  local seg = max(4, floor(len / 3)); local pts = {}
  for s = 0, seg do
    local t = s / seg
    local wob = sin(t * 4 + ang * 3) * amp * t
    pts[#pts + 1] = { cx + cos(ang) * len * t + cos(ang + 1.5708) * wob, cy + sin(ang) * len * t + sin(ang + 1.5708) * wob }
  end
  tube(g, pts, r0, r1, c)
end

-- blob mou (gelatineux) : masse + bulles de surface + reflets ; subverti par yeux/os au treat.
local function blob(g, cx, cy, rx, ry, p, rnd)
  ellipse(g, cx, cy + ry * 0.45, rx * 1.05, ry * 0.5, p.deep)
  ellipse(g, cx, cy, rx, ry, p.deep); ellipse(g, cx, cy, rx - 1, ry - 1, p.base)
  for _ = 1, 4 + floor(rnd() * 4) do
    local a = rnd() * 6.283
    disc(g, cx + cos(a) * rx * 0.92, cy + sin(a) * ry * 0.92, 1 + floor(rnd() * 2), p.base)
  end
  ellipse(g, cx, cy + ry * 0.5, rx * 0.95, ry * 0.4, p.sh)
  ellipse(g, cx, cy - ry * 0.15, rx * 0.7, ry * 0.55, p.base)
  ellipse(g, cx - rx * 0.32, cy - ry * 0.36, rx * 0.34, ry * 0.28, p.hi)
  set(g, round(cx - rx * 0.34), round(cy - ry * 0.46), p.bone)
  set(g, round(cx - rx * 0.28), round(cy - ry * 0.40), p.bone)
end

local function ditherRing(g, cx, cy, rxIn, ryIn, rxOut, ryOut, color)
  cx = round(cx); cy = round(cy)
  local ox, oy = ceil(rxOut), ceil(ryOut)
  for y = -oy, oy do
    for x = -ox, ox do
      local dOut = (x * x) / (rxOut * rxOut) + (y * y) / (ryOut * ryOut)
      local dIn = (x * x) / (rxIn * rxIn) + (y * y) / (ryIn * ryIn)
      if dOut <= 1.02 and dIn > 1.0 and ((cx + x + cy + y) % 2) == 0 then set(g, cx + x, cy + y, color) end
    end
  end
end

-- MASSE ombree : 4 valeurs (deep->sh->base->hi) + 2 anneaux trames. Le coeur de la « finesse » volumetrique.
local function mass(g, cx, cy, rx, ry, p)
  local sR, bR, hR = 0.82, 0.56, 0.30
  ellipse(g, cx, cy, rx, ry, p.deep)
  ellipse(g, cx, cy, rx * sR, ry * sR, p.sh)
  ellipse(g, cx, cy, rx * bR, ry * bR, p.base)
  ditherRing(g, cx, cy, rx * bR, ry * bR, rx * sR, ry * sR, p.base)
  ditherRing(g, cx, cy, rx * sR, ry * sR, rx, ry, p.sh)
  ellipse(g, cx - rx * 0.26, cy - ry * 0.32, rx * hR, ry * hR, p.hi)
end

local function eyeP(g, x, y, r, p)
  x = round(x); y = round(y)
  disc(g, x, y, r + 1, p.deep); disc(g, x, y, r, p.eyeDim); disc(g, x, y, max(1, r - 1), p.eye)
  set(g, x, y, p.out)
  if r >= 2 then set(g, x, y - 1, p.out); set(g, x, y + 1, p.out) end
  if g.eyes then g.eyes[#g.eyes + 1] = { x, y, r } end -- mémorise l'œil pour l'overlay clignement/saccade du rendu vivant
end

local function maw(g, x, y, w, p)
  x = round(x); y = round(y)
  for i = -w, w do for j = -1, 1 do set(g, x + i, y + j, p.deep) end end
  local i = -w
  while i <= w do set(g, x + i, y - 1, p.bone); set(g, x + i, y + 1, p.bone); i = i + 2 end
end

local function growth(g, x, y, p, rnd)
  x = round(x); y = round(y)
  local len = 2 + floor(rnd() * 3)
  local tx = x + round((rnd() - 0.5) * 5)
  tube(g, { { x, y }, { tx, y - len } }, 2, 1, p.base)
  if rnd() < 0.5 then disc(g, tx, y - len, 1, p.eye) else disc(g, tx, y - len, 1, p.deep) end
end

-- entaille / strie aleatoire (grime, cicatrice) : segment centre sur (x,y), orientation seedee.
local function rstreak(g, x, y, r, c, rnd)
  local a = rnd() * math.pi
  local dx, dy = cos(a) * r, sin(a) * r
  line(g, x - dx, y - dy, x + dx, y + dy, c)
end

-- ── helpers d'OS (vrais squelettes, pas des masses) ──
local function boneLimb(g, pts, p) -- os FINS (r1) + articulations -> lecture squelettique nette
  tube(g, pts, 1, 1, p.bone)
  for i = 1, #pts do disc(g, pts[i][1], pts[i][2], 1, p.bone) end
end
local function skull(g, cx, cy, r, p) -- TETE DE MORT renforcee : orbites profondes + lueur vive + nasal + machoire dentee
  ellipse(g, cx, cy, r, r, p.bone)
  ellipse(g, cx, cy - 1, r - 1, r - 1, p.bone)
  local so = max(1, round(r * 0.5))    -- ecartement des orbites
  local orb = max(1, round(r * 0.42))  -- orbites PROFONDES et sombres
  disc(g, cx - so, cy - 1, orb, p.deep); disc(g, cx + so, cy - 1, orb, p.deep)
  set(g, cx - so, cy - 1, p.eye); set(g, cx + so, cy - 1, p.eye) -- lueur morte vive
  local ny = cy + round(r * 0.35)      -- nasal triangulaire sombre
  set(g, cx, ny, p.deep); set(g, cx - 1, ny + 1, p.deep); set(g, cx + 1, ny + 1, p.deep)
  local jy, jw = cy + r - 1, round(r * 0.7) -- machoire dentee (rang + creux)
  for tx = -jw, jw do set(g, cx + tx, jy, p.bone); set(g, cx + tx, jy - 1, p.bone) end
  local tx = -jw + 1
  while tx < jw do set(g, cx + tx, jy, p.deep); tx = tx + 2 end
end
local function spineRibs(g, cx, topY, botY, p, width)
  local y = topY
  while y <= botY do disc(g, cx, y, 1, p.bone); y = y + 2 end -- vertebres
  local n = max(2, floor((botY - topY) / 3))
  for i = 0, n - 1 do
    local ry = topY + 2 + i * 3
    local w = width * (1 - math.abs((i / (n - 1)) - 0.35) * 0.5)
    tube(g, { { cx - 1, ry }, { cx - w * 0.6, ry + 1 }, { cx - w, ry + 3 } }, 1, 1, p.bone)
    tube(g, { { cx + 1, ry }, { cx + w * 0.6, ry + 1 }, { cx + w, ry + 3 } }, 1, 1, p.bone)
  end
end

-- ── helpers d'ancrage (placement sur l'anatomie declaree) ──
local function pickMass(rnd, A) return A.mass[1 + floor(rnd() * #A.mass)] end
local function onMass(rnd, m) -- point aleatoire DANS une masse {cx,cy,r} (densite vers le centre)
  local a = rnd() * 6.283
  local rr = sqrt(rnd()) * m[3] * 0.9
  return { round(m[1] + cos(a) * rr), round(m[2] + sin(a) * rr) }
end

-- contour : tout pixel vide voisin (4-connexite) d'un pixel plein devient `oc`.
local function outline(g, oc)
  local w, h = g.w, g.h
  local src = {}
  for k, v in pairs(g.data) do src[k] = v end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if src[y * w + x] == nil then
        local touch = (x > 0 and src[y * w + x - 1]) or (x < w - 1 and src[y * w + x + 1])
          or (y > 0 and src[(y - 1) * w + x]) or (y < h - 1 and src[(y + 1) * w + x])
        if touch then g.data[y * w + x] = oc end
      end
    end
  end
end

-- ── primitives de construction additionnelles (v7 : formes specifiques par famille) ──
-- Portees telles quelles depuis le generateur v7. Toutes n'utilisent que les primitives ci-dessus
-- (set/ellipse/disc/line/tube/polygon) + locals round/max/cos/sin. Consommees par les archetypes des
-- familles portees en V1+ (no-op tant qu'aucun archetype ne les appelle).
local function rect(g, x, y, w, h, c)
  for j = 0, h - 1 do for i = 0, w - 1 do set(g, x + i, y + j, c) end end
end
local function crystal(g, cx, cy, w, h, p, lean) -- prisme mineral : 2 facettes + aretes
  local t = cx + lean
  polygon(g, { { t, cy - h }, { cx - w, cy }, { cx, cy + h } }, p.sh)
  polygon(g, { { t, cy - h }, { cx + w, cy }, { cx, cy + h } }, p.base)
  line(g, t, cy - h, cx, cy + h, p.hi)
  line(g, t, cy - h, cx - w, cy, p.deep); line(g, cx - w, cy, cx, cy + h, p.deep)
  line(g, t, cy - h, cx + w, cy, p.deep); line(g, cx + w, cy, cx, cy + h, p.deep)
end
local function ghostBody(g, cx, topY, botY, rxTop, p, rnd) -- corps vaporeux qui se dissout vers le bas
  for y = topY, botY do
    local t = (y - topY) / (botY - topY)
    local rx = rxTop * (0.5 + t * 0.9)
    local fade = t
    for x = -rx, rx do
      local edge = math.abs(x) / rx
      local keep = rnd() > (fade * 0.7 + edge * edge * fade)
      if t < 0.15 then keep = true end
      if keep then set(g, round(cx + x), y, edge > 0.7 and p.sh or (edge > 0.4 and p.base or p.hi)) end
    end
  end
end
local function mushroomCap(g, cx, cy, rx, ry, p) -- chapeau de champignon (demi-ellipse + lamelles)
  for y = -ry, 0 do
    for x = -rx, rx do
      if (x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.05 then
        set(g, cx + x, cy + y, y < -ry * 0.4 and p.hi or p.base)
      end
    end
  end
  for x = -rx, rx do set(g, cx + x, cy, p.deep) end
  local x = -rx + 1
  while x < rx do set(g, cx + x, cy + 1, p.sh); x = x + 2 end
  set(g, cx - round(rx * 0.3), cy - round(ry * 0.5), p.bone)
  set(g, cx + round(rx * 0.4), cy - round(ry * 0.3), p.bone)
end
local function bigWing(g, bx, by, dirX, len, p) -- aile membraneuse (chauve-souris/demon)
  local tipX, tipY = bx + dirX * len, by - len * 0.5
  local elbowX, elbowY = bx + dirX * len * 0.5, by - len * 0.4
  polygon(g, { { bx, by }, { elbowX, elbowY }, { tipX, tipY }, { bx + dirX * len * 0.7, by + 6 }, { bx + dirX * len * 0.35, by + 4 } }, p.sh)
  line(g, bx, by, tipX, tipY, p.deep)
  line(g, bx, by, bx + dirX * len * 0.7, by + 6, p.deep)
  line(g, elbowX, elbowY, bx + dirX * len * 0.35, by + 4, p.deep)
end
local function ringMaw(g, cx, cy, r, p) -- gueule annulaire (annelide foreur) : anneau de dents
  disc(g, cx, cy, r, p.deep); disc(g, cx, cy, r - 1, p.out)
  for a = 0, 7 do
    local an = a / 8 * 6.283
    set(g, round(cx + cos(an) * (r - 0.5)), round(cy + sin(an) * (r - 0.5)), p.bone)
  end
end
local function segChain(g, pts, r0, r1, p) -- chaine de segments (corps annele)
  local n = #pts
  for i = 1, n do
    local t = (i - 1) / (n - 1)
    local r = r0 + (r1 - r0) * t
    ellipse(g, pts[i][1], pts[i][2], r, r, p.deep)
    ellipse(g, pts[i][1], pts[i][2], r - 1, r - 1, p.base)
    ellipse(g, pts[i][1] - r * 0.3, pts[i][2] - r * 0.3, max(1, r * 0.4), max(1, r * 0.4), p.hi)
  end
end
local function miniBug(g, x, y, p, rnd) -- petit corps d'insecte (essaim)
  disc(g, x, y, 1, p.base); set(g, x, y, p.sh)
  set(g, x - 1, y + 1, p.base); set(g, x + 1, y + 1, p.base)
  if rnd() < 0.5 then set(g, x, y - 1, p.eye) end
end
local function shield(g, cx, cy, w, h, p) -- grand bouclier (templier) : ecu + bosse + croix
  for y = -h, h do
    local ty = (y + h) / (2 * h)
    local ww = ty < 0.5 and w * (0.7 + ty * 0.6) or w * (1.0 - (ty - 0.5) * 1.6)
    for x = -ww, ww do
      set(g, round(cx + x), cy + y, math.abs(x) > ww - 1 and p.deep or (x < -ww * 0.4 and p.sh or p.base))
    end
  end
  set(g, cx, cy - h, p.bone); disc(g, cx, cy, 2, p.hi)
  line(g, cx, cy - h + 2, cx, cy + h - 2, p.bone)
  line(g, round(cx - w * 0.5), cy - 1, round(cx + w * 0.5), cy - 1, p.bone)
end
local function halo(g, cx, cy, r, p) -- aureole (seraphin) : ellipse en perspective
  for a = 0, 47 do
    local an = a / 48 * 6.283
    set(g, round(cx + cos(an) * r), round(cy + sin(an) * r * 0.45), p.eye)
  end
  for a = 0, 47, 6 do
    local an2 = a / 48 * 6.283
    set(g, round(cx + cos(an2) * r), round(cy + sin(an2) * r * 0.45), p.bone)
  end
end
local function featherWing(g, bx, by, dirX, len, p) -- aile de plumes (griffon/seraphin)
  local tipX, tipY = bx + dirX * len, by - len * 0.45
  polygon(g, { { bx, by }, { bx + dirX * len * 0.45, by - len * 0.42 }, { tipX, tipY }, { bx + dirX * len * 0.8, by + 5 }, { bx + dirX * len * 0.4, by + 7 } }, p.base)
  line(g, bx, by, tipX, tipY, p.deep)
  for f = 1, 5 do
    local t = f / 6
    local ax, ay = bx + dirX * len * t, by - len * 0.4 * t
    line(g, round(ax), round(ay), round(ax + dirX * len * 0.18), round(ay + 6 + t * 4), p.sh)
  end
  for f = 1, 3 do
    local t2 = 0.4 + f * 0.18
    set(g, round(bx + dirX * len * t2), round(by - len * 0.4 * t2), p.hi)
  end
end
local function antler(g, x, y, dir, p) -- ramure (wendigo/cervide)
  tube(g, { { x, y }, { x + dir * 2, y - 6 }, { x + dir * 5, y - 11 } }, 1, 1, p.bone)
  tube(g, { { x + dir * 2, y - 6 }, { x + dir * 6, y - 6 } }, 1, 1, p.bone)
  tube(g, { { x + dir * 4, y - 9 }, { x + dir * 8, y - 10 } }, 1, 1, p.bone)
  tube(g, { { x + dir * 5, y - 11 }, { x + dir * 7, y - 15 } }, 1, 1, p.bone)
end
local function jellyBell(g, cx, cy, rx, ry, p) -- cloche de meduse (translucide, stries)
  for y = -ry, 0 do
    for x = -rx, rx do
      if (x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.0 then
        set(g, cx + x, cy + y, y < -ry * 0.5 and p.hi or (math.abs(x) > rx * 0.6 and p.sh or p.base))
      end
    end
  end
  local k = -rx
  while k <= rx do set(g, cx + k, cy, p.deep); set(g, cx + k, cy + 1, p.hi); k = k + 2 end
  line(g, round(cx - rx * 0.5), round(cy - ry * 0.4), round(cx - rx * 0.5), cy, p.hi)
  line(g, cx, round(cy - ry * 0.7), cx, cy, p.hi)
  line(g, round(cx + rx * 0.5), round(cy - ry * 0.4), round(cx + rx * 0.5), cy, p.hi)
end
local function pincer(g, x, y, dir, p) -- pince (crustace)
  tube(g, { { x, y }, { x + dir * 5, y - 2 } }, 3, 2, p.base)
  polygon(g, { { x + dir * 5, y - 2 }, { x + dir * 11, y - 6 }, { x + dir * 10, y - 2 }, { x + dir * 6, y - 1 } }, p.base)
  polygon(g, { { x + dir * 5, y - 1 }, { x + dir * 10, y + 1 }, { x + dir * 9, y + 3 }, { x + dir * 6, y + 2 } }, p.sh)
  line(g, x + dir * 6, y - 3, x + dir * 11, y - 6, p.deep)
  line(g, x + dir * 6, y + 2, x + dir * 9, y + 3, p.deep)
end
local function dagger(g, x, y, dir, p) -- dague (gredins)
  polygon(g, { { x, y }, { x + dir * 9, y - 2 }, { x + dir * 11, y }, { x + dir * 9, y + 2 } }, p.bone)
  line(g, x + dir * 9, y - 1, x + dir * 11, y, p.hi)
  line(g, x - dir * 1, y - 2, x - dir * 1, y + 2, p.sh)
  set(g, x - dir * 2, y, p.deep)
end
-- ── helpers d'os AMINCIS (squelettes ajoures v7 : plus de vide que skull/spineRibs/boneLimb) ──
local function thinBone(g, pts, p)
  tube(g, pts, 1, 1, p.bone)
  disc(g, pts[1][1], pts[1][2], 1, p.bone); disc(g, pts[#pts][1], pts[#pts][2], 1, p.bone)
end
local function thinSpineRibs(g, cx, topY, botY, p, width)
  for y = topY, botY do
    if y % 2 == 0 then set(g, cx, y, p.bone) else set(g, cx, y, p.sh) end
  end
  local n = 4
  for i = 0, n - 1 do
    local ry = topY + 1 + round(i * ((botY - topY - 2) / (n - 1)))
    local w = width * (1 - math.abs((i / (n - 1)) - 0.3) * 0.5)
    tube(g, { { cx - 1, ry }, { cx - w * 0.7, ry + 1 }, { cx - w, ry + 2 } }, 1, 1, p.bone)
    tube(g, { { cx + 1, ry }, { cx + w * 0.7, ry + 1 }, { cx + w, ry + 2 } }, 1, 1, p.bone)
  end
end
local function skullThin(g, cx, cy, r, p)
  ellipse(g, cx, cy, r, r, p.bone); ellipse(g, cx, cy - 1, r - 1, r - 1, p.bone)
  local so = max(1, round(r * 0.5))
  disc(g, cx - so, cy - 1, 1, p.deep); disc(g, cx + so, cy - 1, 1, p.deep)
  set(g, cx - so, cy - 1, p.eyeDim); set(g, cx + so, cy - 1, p.eyeDim)
  set(g, cx, cy + 1, p.deep)
  local jw = max(1, round(r * 0.6))
  for tx = -jw, jw do set(g, cx + tx, cy + r - 1, p.bone) end
  local tx = -jw
  while tx <= jw do set(g, cx + tx, cy + r - 1, p.deep); tx = tx + 2 end
end

-- ─────────────────────────── Palettes par famille (grimdark, malades) ───────────────────────────
-- Valeurs hex 0xRRGGBB (bake() les convertit en floats). Chaque famille porte EXACTEMENT les clefs que
-- sa passe `treat` utilise (bete = +scar/+wound ; les autres n'en ont pas besoin).
local ELDRITCH = {
  { deep = 0x1e2a14, sh = 0x33461f, base = 0x5a6e3a, hi = 0x7d9152, bone = 0xcfc7a0, eye = 0xd8ff52, eyeDim = 0x8aa83a, out = 0x0c1408 },
  { deep = 0x1c1426, sh = 0x33264a, base = 0x54466e, hi = 0x776a92, bone = 0xc8c0d0, eye = 0xc08aff, eyeDim = 0x7a5aa8, out = 0x0c0814 },
  { deep = 0x2a1212, sh = 0x4a2020, base = 0x6e3a3a, hi = 0x925050, bone = 0xd0bcb0, eye = 0xff6a4a, eyeDim = 0xa8503a, out = 0x160808 },
  { deep = 0x16242a, sh = 0x28424a, base = 0x46666e, hi = 0x688a92, bone = 0xc0ccc8, eye = 0x6affd4, eyeDim = 0x3aa890, out = 0x0a1418 },
  { deep = 0x2a2810, sh = 0x46421c, base = 0x6e6a32, hi = 0x928d4e, bone = 0xd0cca0, eye = 0xeaff6a, eyeDim = 0xa8a03a, out = 0x161408 },
  { deep = 0x1c1a22, sh = 0x322f3c, base = 0x54505e, hi = 0x777282, bone = 0xc8c4cc, eye = 0xb0e8ff, eyeDim = 0x6a9ab0, out = 0x0c0a12 },
}
local UNDEAD = {
  { deep = 0x2e3230, sh = 0x4a4f4a, base = 0x737868, hi = 0x9a9e8c, bone = 0xe8e5d4, eye = 0x7ad0b0, eyeDim = 0x3f8a72, out = 0x141612 },
  { deep = 0x1f2a18, sh = 0x374a2a, base = 0x566a40, hi = 0x7a8c54, bone = 0xd4cfa6, eye = 0x9aff7a, eyeDim = 0x5aa83a, out = 0x0c1408 },
  { deep = 0x2a2014, sh = 0x463722, base = 0x6e5638, hi = 0x927450, bone = 0xdccfa6, eye = 0xffcf6a, eyeDim = 0xa8853a, out = 0x160e08 },
  { deep = 0x28323e, sh = 0x42526a, base = 0x5a6e86, hi = 0x8a9eb6, bone = 0xe2ecf2, eye = 0x9ae8ff, eyeDim = 0x5a9ab0, out = 0x121822 },
}
local BEAST = {
  { deep = 0x2a2a2e, sh = 0x45454c, base = 0x6a6a72, hi = 0x8e8e96, bone = 0xd6cfc0, eye = 0xe8c24a, eyeDim = 0xa8843a, scar = 0xcfc6b4, wound = 0x7a3030, out = 0x141418 },
  { deep = 0x3a1810, sh = 0x6a2c1c, base = 0xa0432b, hi = 0xc4694a, bone = 0xe0d2b0, eye = 0xffd24a, eyeDim = 0xb8903a, scar = 0xe0c4a8, wound = 0x8a2a20, out = 0x1c0a06 },
  { deep = 0x2a2012, sh = 0x4a3a20, base = 0x746038, hi = 0x987a52, bone = 0xd8cba0, eye = 0xcfe04a, eyeDim = 0x9ba83a, scar = 0xd0c4a0, wound = 0x7a3424, out = 0x160e08 },
  { deep = 0x28323e, sh = 0x445466, base = 0x6a7e92, hi = 0x94a6ba, bone = 0xdce6ee, eye = 0xaef0ff, eyeDim = 0x6aa8c0, scar = 0xcdd6de, wound = 0x6a3838, out = 0x121822 },
  { deep = 0x26242a, sh = 0x403e46, base = 0x62606a, hi = 0x86848e, bone = 0xc9c4cc, eye = 0xffae5a, eyeDim = 0xb8804a, scar = 0xc8c2cc, wound = 0x74343a, out = 0x121016 },
}
local DEMON = {
  { deep = 0x1a0808, sh = 0x3a1010, base = 0x5e1c18, hi = 0x8a2c24, bone = 0xb8a888, eye = 0xff7a2a, eyeDim = 0xc85a1a, out = 0x100404 },
  { deep = 0x141016, sh = 0x26202e, base = 0x3a3242, hi = 0x5a4e64, bone = 0xb0a0b8, eye = 0xff5a3c, eyeDim = 0xc84028, out = 0x0a0810 },
  { deep = 0x2a1206, sh = 0x5a2608, base = 0x8a3e10, hi = 0xbd6418, bone = 0xe0c080, eye = 0xffd23a, eyeDim = 0xd88a1a, out = 0x180a04 },
  { deep = 0x181618, sh = 0x2e2c2e, base = 0x48464a, hi = 0x6a686c, bone = 0xc0b8b0, eye = 0xff8a3a, eyeDim = 0xc8601a, out = 0x0c0a0c },
}
local INSECT = {
  { deep = 0x102018, sh = 0x1e3a2a, base = 0x2e5a42, hi = 0x4a8a64, bone = 0xd8d0a0, eye = 0x9aff6a, eyeDim = 0x5aa83a, out = 0x08120c },
  { deep = 0x2a2008, sh = 0x4a3a0e, base = 0x7a5e14, hi = 0xb88e1e, bone = 0xe0d2a0, eye = 0xffe24a, eyeDim = 0xc8a01a, out = 0x160e04 },
  { deep = 0x1e160e, sh = 0x36281a, base = 0x56402a, hi = 0x7c5e3e, bone = 0xd0c0a0, eye = 0xff8a4a, eyeDim = 0xc8602a, out = 0x0e0a06 },
  { deep = 0x1a1426, sh = 0x2e2440, base = 0x463a5e, hi = 0x6a5a8a, bone = 0xc8c0d0, eye = 0xb0ff6a, eyeDim = 0x6aa83a, out = 0x0c0814 },
}
-- ── V1 ténèbres part A ──
local CEPHALO = {
  { deep = 0x1e1430, sh = 0x33245a, base = 0x52408a, hi = 0x8a6ad0, bone = 0xd0c0e0, eye = 0xffd24a, eyeDim = 0xc8a01a, out = 0x0e081a },
  { deep = 0x3a1420, sh = 0x6a2438, base = 0xa03a58, hi = 0xd06a88, bone = 0xe0c0c8, eye = 0xffe24a, eyeDim = 0xc8a83a, out = 0x1c0810 },
  { deep = 0x0e3a3a, sh = 0x1a5a5a, base = 0x2e8a86, hi = 0x6ad0c8, bone = 0xd0e8e0, eye = 0xffd86a, eyeDim = 0xc8a83a, out = 0x062222 },
  { deep = 0x14223a, sh = 0x243a6a, base = 0x3a5aa0, hi = 0x6a8ad0, bone = 0xc8d0e8, eye = 0x9affd0, eyeDim = 0x5ac8a0, out = 0x08101e },
}

local ARCH, TREAT = {}, {}
-- ═══════════════════════════ ARCHETYPES (chacun retourne l'anatomie `A`) ═══════════════════════════
-- A = { head={x,y,r}, faceDir={dx,dy}, spine={{x,y}...}, limbs={{x,y}...}, belly={x,y},
--       mass={{cx,cy,r}...}, tailBase={x,y}|nil, flesh=bool }. Les `treat()` lisent ces ancrages.

-- ── CAUCHEMAR (chair informe : la masse est volontaire) ──
function ARCH.aBouffi(g, rnd, p)
  local rx = 13 + floor(rnd() * 6)        -- largeur 13..18
  local ry = 12 + floor(rnd() * 5)        -- hauteur 12..16
  local cy = 36 + floor(rnd() * 4)        -- centre 36..39
  local legW = 5 + floor(rnd() * 5)       -- écartement des moignons
  tube(g, { { 32 - legW, cy + ry - 2 }, { 31 - legW, 57 } }, 3, 3, p.sh)
  tube(g, { { 32 + legW, cy + ry - 2 }, { 33 + legW, 57 } }, 3, 3, p.sh)
  mass(g, 32, cy, rx, ry, p)
  local A_mass = { { 32, cy, rx } }
  for _ = 1, 1 + floor(rnd() * 3) do      -- 1..3 bosses (lumpiness)
    local lx = 32 + round((rnd() - 0.5) * rx * 1.5)
    local ly = cy + round((rnd() - 0.5) * ry * 1.3)
    local lr = 3 + floor(rnd() * 3)
    mass(g, lx, ly, lr, lr - 1, p); A_mass[#A_mass + 1] = { lx, ly, lr }
  end
  local ey = cy - round(ry * 0.5)
  maw(g, 32 - round(rx * 0.4), cy - round(ry * 0.2), 2, p); eyeP(g, 33, ey, 2, p); eyeP(g, 32 + round(rx * 0.5), ey + 3, 1, p)
  return { head = { x = 33, y = ey, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, cy - ry }, { 32, cy }, { 32, cy + ry } },
    limbs = { { 31 - legW, 57 }, { 33 + legW, 57 } }, belly = { x = 32, y = cy + round(ry * 0.45) }, mass = A_mass, tailBase = nil, flesh = true }
end
function ARCH.aPendu(g, rnd, p)
  local rx = 11 + floor(rnd() * 6)        -- 11..16
  local ry = 13 + floor(rnd() * 5)        -- 13..17
  local cy = 25 + floor(rnd() * 5)        -- 25..29
  local stalk = 6 + floor(rnd() * 8)      -- longueur du pédoncule
  local tend = 5 + floor(rnd() * 5)       -- 5..9 tentacules
  tube(g, { { 32, max(2, cy - ry - stalk) }, { 32, cy - ry + 2 } }, 2, 2, p.sh)
  mass(g, 32, cy, rx, ry, p)
  local baseY = cy + ry - 2
  for i = 0, tend - 1 do
    local tx = 32 - rx + i * (2 * rx / (max(1, tend - 1)))
    tentacle(g, tx, baseY, 10 + floor(rnd() * 11), (i - tend / 2) * 0.4, 3, 2, 1, p.sh)
  end
  maw(g, 32, cy + 2, 3 + floor(rnd() * 2), p)
  return { head = { x = 32, y = cy - round(ry * 0.4), r = 5 }, faceDir = { 0, -1 }, spine = { { 32, cy - ry }, { 32, cy }, { 32, cy + ry } },
    limbs = { { 32 - rx, baseY + 8 }, { 32 + rx, baseY + 8 } }, belly = { x = 32, y = cy + round(ry * 0.4) }, mass = { { 32, cy, rx } }, tailBase = nil, flesh = true }
end
-- ── BUILDERS LEGACY (RÉCONCILIATION B.2) : aTisserand/aBrute/aHellhound/aSwarmflyer/aCentaur ne sont
-- référencés par AUCUNE entrée de FAMILIES (les familles utilisent les builders CANON spider/widow/ogre/
-- wolf/byakhee). Donc `Primgen.archName` ne renvoie JAMAIS ces noms : les noms exposés sont déjà ceux du
-- dictionnaire. On les GARDE (code mort inerte, séquence RNG des autres unités intacte) plutôt que de les
-- supprimer (gain nul, risque de churn). Ils servent de réserve de silhouettes si une future famille les câble.
function ARCH.aTisserand(g, rnd, p)
  local br = 6 + floor(rnd() * 4)         -- rayon du corps 6..9
  local cy = 32 + floor(rnd() * 5)        -- 32..36
  local nPair = 3 + floor(rnd() * 2)      -- 3 ou 4 paires (6/8 pattes)
  local span = 22 + floor(rnd() * 9)      -- envergure
  local limbs = {}
  for i = 1, nPair do
    local t = (i - 1) / max(1, nPair - 1)
    local kneeY = 20 + round(t * 13)
    local footY = 51 + round(t * 6)
    local kneeX = round(span * 0.5 * (0.5 + t * 0.5))
    local footX = round(span * (0.55 + t * 0.45))
    tube(g, { { 32, cy }, { 32 - kneeX, kneeY }, { 32 - footX, footY } }, 2, 1, p.sh)
    tube(g, { { 32, cy }, { 32 + kneeX, kneeY }, { 32 + footX, footY } }, 2, 1, p.sh)
    disc(g, 32 - kneeX, kneeY, 1, p.deep); disc(g, 32 + kneeX, kneeY, 1, p.deep)
    limbs[#limbs + 1] = { 32 - footX, footY }; limbs[#limbs + 1] = { 32 + footX, footY }
  end
  mass(g, 32, cy, br, br, p)
  eyeP(g, 30, cy - 2, 1, p); eyeP(g, 34, cy - 2, 1, p)
  return { head = { x = 32, y = cy - 1, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, cy - br }, { 32, cy }, { 32, cy + br } },
    limbs = limbs, belly = { x = 32, y = cy + round(br * 0.5) }, mass = { { 32, cy, br } }, tailBase = nil, flesh = true }
end
function ARCH.aFleshCrawler(g, rnd, p)
  local bw = 15 + floor(rnd() * 7)        -- longueur du corps 15..21
  local bh = 7 + floor(rnd() * 3)
  local cx = 29 + floor(rnd() * 4)
  local nLeg = 4 + floor(rnd() * 3)       -- 4..6 pattes-tentacules
  mass(g, cx, 44, bw, bh, p)
  local left = cx - bw + 2
  for i = 0, nLeg - 1 do
    local lx = left + i * ((2 * bw - 4) / max(1, nLeg - 1))
    tentacle(g, lx, 50, 7 + floor(rnd() * 6), (i - nLeg / 2) * 0.4, 2, 2, 1, p.sh)
  end
  local hx = cx + bw - 4
  local hr = 6 + floor(rnd() * 2)
  mass(g, hx, 42, hr, hr - 1, p); maw(g, min(60, hx + 3), 43, 3, p)
  return { head = { x = hx, y = 42, r = hr }, faceDir = { 1, 0 }, spine = { { hx, 38 }, { cx, 38 }, { left, 40 } },
    limbs = { { left, 56 }, { cx, 56 }, { cx + bw - 6, 56 } }, belly = { x = cx, y = 48 }, mass = { { cx, 44, bw - 9 }, { hx, 42, hr - 1 } }, tailBase = { x = max(2, left - 3), y = 44 }, flesh = true }
end

-- ── MORT-VIVANT (vrais os) ──
function ARCH.aSkeleton(g, rnd, p)
  local sway = round((rnd() - 0.5) * 5)      -- inclinaison du crane
  local sr = 4 + floor(rnd() * 3)            -- crane 4..6
  local shY = 24 + floor(rnd() * 3)          -- hauteur d'epaule (longueur du tronc)
  local hipY = 38 + floor(rnd() * 3)         -- bassin
  local stance = 4 + floor(rnd() * 3)        -- ecartement des jambes
  local armOut = 9 + floor(rnd() * 4)        -- ecartement des bras
  boneLimb(g, { { 32 - stance + 1, hipY + 2 }, { 32 - stance, 48 }, { 32 - stance - 1, 56 } }, p)
  boneLimb(g, { { 32 + stance - 1, hipY + 2 }, { 32 + stance, 48 }, { 32 + stance + 1, 56 } }, p)
  set(g, 31 - stance - 2, 56, p.bone); set(g, 30 - stance - 2, 56, p.bone); set(g, 33 + stance + 2, 56, p.bone); set(g, 34 + stance + 2, 56, p.bone)
  ellipse(g, 32, hipY + 2, 5, 3, p.bone); ellipse(g, 32, hipY + 3, 3, 2, p.deep)
  spineRibs(g, 32, shY, hipY + 1, p, 6 + floor(rnd() * 3))
  boneLimb(g, { { 27, shY + 2 }, { 32 - armOut, shY + 9 }, { 32 - armOut - 1, shY + 17 } }, p)
  boneLimb(g, { { 37, shY + 2 }, { 32 + armOut, shY + 9 }, { 32 + armOut + 1, shY + 17 } }, p)
  disc(g, 32 - armOut - 1, shY + 18, 1, p.bone); disc(g, 32 + armOut + 1, shY + 18, 1, p.bone)
  line(g, 26, shY + 2, 38, shY + 2, p.bone); disc(g, 32, shY - 1, 1, p.bone)
  local skY = shY - sr - 2
  skull(g, 32 + sway, skY, sr, p)
  return { head = { x = 32 + sway, y = skY, r = sr }, faceDir = { 0, -1 }, spine = { { 32, shY }, { 32, round((shY + hipY) / 2) }, { 32, hipY } },
    limbs = { { 32 - armOut - 1, shY + 17 }, { 32 + armOut + 1, shY + 17 }, { 32 - stance - 1, 56 }, { 32 + stance + 1, 56 } },
    belly = { x = 32, y = round((shY + hipY) / 2) }, mass = { { 32, round((shY + hipY) / 2), 6 } }, tailBase = nil, flesh = false }
end
function ARCH.aSkeletonQuad(g, rnd, p)
  local x0 = 18 + floor(rnd() * 4)           -- arriere (croupe)
  local x1 = 42 + floor(rnd() * 4)           -- avant (epaule)
  local legLen = 13 + floor(rnd() * 5)       -- longueur des pattes
  local sr = 3 + floor(rnd() * 2)            -- crane 3..4
  local neck = 4 + floor(rnd() * 4)          -- longueur du cou
  for x = x0, x1, 2 do disc(g, x, 38, 1, p.bone) end -- echine horizontale
  local nrib = 4 + floor(rnd() * 2)
  for i = 0, nrib - 1 do
    local rx = x0 + 4 + i * round((x1 - x0 - 6) / max(1, nrib - 1))
    tube(g, { { rx, 38 }, { rx - 2, 42 }, { rx - 1, 45 } }, 1, 1, p.bone)
    tube(g, { { rx, 38 }, { rx + 1, 42 }, { rx, 45 } }, 1, 1, p.bone)
  end
  ellipse(g, x0, 38, 3, 3, p.bone); ellipse(g, x1, 38, 3, 2, p.bone) -- croupe + epaule
  local footY = 38 + legLen
  boneLimb(g, { { x0 + 2, 40 }, { x0 + 1, 38 + round(legLen / 2) }, { x0, footY } }, p)
  boneLimb(g, { { x0 + 6, 40 }, { x0 + 5, 38 + round(legLen / 2) }, { x0 + 4, footY } }, p)
  boneLimb(g, { { x1 - 2, 40 }, { x1 - 1, 38 + round(legLen / 2) }, { x1, footY } }, p)
  boneLimb(g, { { x1, 40 }, { x1 + 1, 38 + round(legLen / 2) }, { x1 + 2, footY } }, p)
  local hx = x1 + neck + 1
  boneLimb(g, { { x1 + 2, 37 }, { hx - 1, 34 } }, p); skull(g, hx, 32, sr, p) -- cou + crane en avant
  ellipse(g, hx + sr, 33, 3, 2, p.bone); set(g, hx + sr + 2, 33, p.deep) -- museau
  local tx = x0
  while tx >= max(8, x0 - 9) do if tx % 2 == 0 then disc(g, tx, 38 + round((x0 - tx) / 2), 1, p.bone) end; tx = tx - 1 end -- queue
  return { head = { x = hx, y = 32, r = sr }, faceDir = { 1, 0 }, spine = { { x1, 38 }, { round((x0 + x1) / 2), 38 }, { x0, 38 } },
    limbs = { { x0, footY }, { x0 + 4, footY }, { x1, footY }, { x1 + 2, footY } }, belly = { x = round((x0 + x1) / 2), y = 42 },
    mass = { { round((x0 + x1) / 2), 38, round((x1 - x0) / 2) } }, tailBase = { x = x0, y = 38 }, flesh = false }
end
function ARCH.aRevenant(g, rnd, p)
  local rx = 7 + floor(rnd() * 3)            -- carrure 7..9
  local ry = 9 + floor(rnd() * 3)
  local cy = 35 + floor(rnd() * 3)
  local hr = 4 + floor(rnd() * 2)            -- tete
  local lean = round((rnd() - 0.5) * 5)      -- penche la tete (decharne)
  tube(g, { { 30, cy + 6 }, { 28, cy + 13 }, { 28, 56 } }, 3, 2, p.sh); tube(g, { { 36, cy + 6 }, { 38, cy + 13 }, { 38, 56 } }, 3, 2, p.sh)
  disc(g, 28, 56, 2, p.deep); disc(g, 38, 56, 2, p.deep)
  mass(g, 33, cy, rx, ry, p)
  tube(g, { { 28, cy - 5 }, { 24, cy + 4 }, { 24, cy + 12 } }, 2, 2, p.sh); tube(g, { { 38, cy - 5 }, { 42, cy + 4 }, { 43, cy + 12 } }, 2, 2, p.sh)
  disc(g, 24, cy + 13, 2, p.deep); disc(g, 43, cy + 13, 2, p.deep)
  mass(g, 34 + lean, cy - ry - 1, hr, hr, p)
  return { head = { x = 34 + lean, y = cy - ry - 1, r = hr }, faceDir = { 1, -0.3 }, spine = { { 33, cy - 6 }, { 33, cy }, { 33, cy + 6 } },
    limbs = { { 24, cy + 12 }, { 43, cy + 12 }, { 28, 56 }, { 38, 56 } }, belly = { x = 33, y = cy + 2 }, mass = { { 33, cy, rx }, { 34 + lean, cy - ry - 1, hr } }, tailBase = nil, flesh = true }
end

-- ── BETE ──
function ARCH.aDragon(g, rnd, p)
  local bulk = 12 + floor(rnd() * 4)          -- carrure du corps
  local wtx = 9 + floor(rnd() * 6)            -- pointe d'aile (envergure)
  local wty = 12 + floor(rnd() * 6)
  local hx = 49 + floor(rnd() * 4)            -- avancee de la tete
  local hy = 14 + floor(rnd() * 6)
  polygon(g, { { 31, 32 }, { wtx, wty }, { 24, 44 } }, p.sh) -- aile
  line(g, 31, 32, wtx, wty, p.deep); line(g, 31, 32, 24, 44, p.deep); line(g, 31, 32, round((31 + wtx) / 2 - 4), round((32 + wty) / 2 + 2), p.deep)
  tube(g, { { 23, 45 }, { 23, 55 } }, 3, 2, p.sh); tube(g, { { 33, 45 }, { 33, 55 } }, 3, 2, p.sh)
  tube(g, { { 26, 42 }, { 16, 46 }, { 9, 44 }, { 6, 38 }, { 8, 33 } }, 4, 1, p.sh) -- queue
  polygon(g, { { 8, 33 }, { 4, 30 }, { 7, 29 } }, p.bone)
  mass(g, 28, 39, bulk, 8, p)
  tube(g, { { 37, 34 }, { round((37 + hx) / 2 + 2), round((34 + hy) / 2) }, { hx - 2, hy + 2 }, { hx, hy } }, 5, 3, p.sh) -- col
  mass(g, hx + 2, hy, 6, 5, p)
  ellipse(g, hx + 8, hy + 1, 4, 3, p.base); ellipse(g, hx + 8, hy + 2, 4, 2, p.sh) -- museau
  for k = 0, floor(rnd() * 3) do line(g, hx - 2 + k * 3, hy - 5, hx - 4 + k * 3, hy - 11 - floor(rnd() * 3), p.bone) end -- 1..3 cornes
  eyeP(g, hx + 3, hy - 1, 1, p)
  return { head = { x = hx + 2, y = hy, r = 5 }, faceDir = { 1, -0.2 }, spine = { { 37, 32 }, { round((37 + hx) / 2), round((32 + hy) / 2) }, { hx, hy } },
    limbs = { { 23, 55 }, { 33, 55 } }, belly = { x = 28, y = 44 }, mass = { { 28, 39, bulk - 1 }, { hx + 2, hy, 5 } }, tailBase = { x = 26, y = 42 }, flesh = true }
end
function ARCH.aCentaur(g, rnd, p)
  local bodyRx = 12 + floor(rnd() * 4)        -- longueur du corps equin
  local torsoTop = 16 + floor(rnd() * 5)      -- hauteur du buste (bas = buste plus grand)
  local hr = 4 + floor(rnd() * 2)
  tube(g, { { 20, 40 }, { 20, 54 } }, 2, 2, p.deep); tube(g, { { 34, 40 }, { 34, 54 } }, 2, 2, p.deep) -- pattes arriere
  tube(g, { { 13, 36 }, { 9, 41 }, { 7, 48 }, { 8, 53 } }, 3, 1, p.sh) -- queue
  mass(g, 26, 38, bodyRx, 7, p)
  tube(g, { { 16, 40 }, { 16, 54 } }, 2, 2, p.sh); tube(g, { { 30, 40 }, { 30, 54 } }, 2, 2, p.sh)
  disc(g, 16, 55, 2, p.deep); disc(g, 30, 55, 2, p.deep); disc(g, 20, 55, 1, p.deep); disc(g, 34, 55, 1, p.deep)
  tube(g, { { 36, 33 }, { 37, round((33 + torsoTop) / 2) }, { 37, torsoTop + 2 } }, 3, 3, p.sh) -- buste
  mass(g, 38, torsoTop - hr, hr, hr, p)
  tube(g, { { 34, torsoTop + 4 }, { 32, torsoTop + 10 }, { 31, torsoTop + 13 } }, 2, 1, p.sh)
  tube(g, { { 39, torsoTop + 4 }, { 41, torsoTop + 9 }, { 42, torsoTop + 13 } }, 2, 1, p.sh) -- bras
  eyeP(g, 38, torsoTop - hr - 1, 1, p)
  return { head = { x = 38, y = torsoTop - hr, r = hr }, faceDir = { 0, -1 }, spine = { { 24, 36 }, { 32, round((36 + torsoTop) / 2) }, { 37, torsoTop } },
    limbs = { { 16, 54 }, { 30, 54 }, { 31, torsoTop + 13 }, { 42, torsoTop + 13 } }, belly = { x = 26, y = 42 }, mass = { { 26, 38, bodyRx - 1 }, { 38, torsoTop - hr, hr } }, tailBase = { x = 13, y = 36 }, flesh = true }
end
function ARCH.aWolf(g, rnd, p)
  local bodyRx = 12 + floor(rnd() * 4)
  local legBot = 53 + floor(rnd() * 4)        -- longueur des pattes
  local hx = 50 + floor(rnd() * 4)            -- avancee du museau
  local ear = 3 + floor(rnd() * 3)            -- taille d'oreille
  mass(g, 30, 38, bodyRx, 8, p)
  tube(g, { { 21, 42 }, { 20, legBot } }, 2, 3, p.sh); tube(g, { { 26, 42 }, { 25, legBot } }, 2, 3, p.sh)
  tube(g, { { 40, 42 }, { 41, legBot } }, 2, 3, p.sh); tube(g, { { 44, 42 }, { 45, legBot } }, 2, 3, p.sh)
  disc(g, 20, legBot, 2, p.deep); disc(g, 25, legBot, 2, p.deep); disc(g, 41, legBot, 2, p.deep); disc(g, 45, legBot, 2, p.deep)
  mass(g, 42, 40, 5, 5, p)
  tube(g, { { 44, 36 }, { hx - 3, 31 } }, 3, 3, p.sh)
  mass(g, hx, 29, 6, 5, p)
  ellipse(g, hx + 5, 30, 3, 2, p.base); ellipse(g, hx + 5, 31, 3, 2, p.sh); set(g, hx + 7, 30, p.deep) -- museau
  polygon(g, { { hx - 3, 25 }, { hx - 1, 25 }, { hx - 2, 25 - ear } }, p.sh); polygon(g, { { hx + 1, 25 }, { hx + 3, 25 }, { hx + 2, 25 - ear } }, p.sh) -- oreilles
  tube(g, { { 18, 36 }, { 12, 33 }, { 9, 37 } }, 4, 2, p.sh) -- queue
  eyeP(g, hx - 1, 28, 1, p)
  return { head = { x = hx, y = 29, r = 5 }, faceDir = { 1, 0 }, spine = { { 44, 33 }, { 32, 34 }, { 20, 35 } },
    limbs = { { 20, legBot }, { 25, legBot }, { 41, legBot }, { 45, legBot } }, belly = { x = 32, y = 42 }, mass = { { 30, 38, bodyRx - 1 }, { hx, 29, 5 } }, tailBase = { x = 18, y = 36 }, flesh = true }
end

-- ── DEMON (cornes intrinseques au crane) ──
function ARCH.aBrute(g, rnd, p)
  local bx = 8 + floor(rnd() * 3)            -- carrure 8..10
  local by = 10 + floor(rnd() * 3)
  local cy = 32 + floor(rnd() * 3)
  local armX = 19 + floor(rnd() * 4)         -- ecartement des bras massifs
  local hr = 5 + floor(rnd() * 2)            -- tete
  local horn = 4 + floor(rnd() * 4)          -- longueur de corne
  tube(g, { { 27, cy + 7 }, { 25, cy + 15 }, { 27, 56 } }, 4, 3, p.sh); tube(g, { { 37, cy + 7 }, { 39, cy + 15 }, { 37, 56 } }, 4, 3, p.sh)
  disc(g, 26, 56, 2, p.deep); disc(g, 37, 56, 2, p.deep)
  mass(g, 32, cy, bx, by, p)
  tube(g, { { 24, cy - 6 }, { armX, cy + 3 }, { armX, cy + 12 } }, 3, 3, p.sh); tube(g, { { 40, cy - 6 }, { 64 - armX, cy + 3 }, { 64 - armX, cy + 12 } }, 3, 3, p.sh)
  disc(g, armX, cy + 13, 3, p.deep); disc(g, 64 - armX, cy + 13, 3, p.deep)
  local hy = cy - by - hr + 2
  mass(g, 32, hy, hr, hr - 1, p)
  line(g, 28, hy - 3, 24, hy - 3 - horn, p.bone); line(g, 24, hy - 3 - horn, 25, hy - 7 - horn, p.bone)
  line(g, 36, hy - 3, 40, hy - 3 - horn, p.bone); line(g, 40, hy - 3 - horn, 39, hy - 7 - horn, p.bone)
  eyeP(g, 30, hy, 1, p); eyeP(g, 34, hy, 1, p)
  return { head = { x = 32, y = hy, r = hr }, faceDir = { 0, -1 }, spine = { { 32, cy - by }, { 32, cy }, { 32, cy + by } },
    limbs = { { armX, cy + 12 }, { 64 - armX, cy + 12 }, { 26, 56 }, { 37, 56 } }, belly = { x = 32, y = cy + 3 }, mass = { { 32, cy, bx }, { 32, hy, hr - 1 } }, tailBase = { x = 32, y = cy + by }, flesh = true }
end
function ARCH.aHellhound(g, rnd, p)
  local bodyRx = 12 + floor(rnd() * 4)
  local legBot = 53 + floor(rnd() * 4)
  local hx = 50 + floor(rnd() * 4)
  local horn = 4 + floor(rnd() * 3)
  mass(g, 30, 38, bodyRx, 8, p)
  tube(g, { { 21, 42 }, { 20, legBot } }, 2, 3, p.sh); tube(g, { { 26, 42 }, { 25, legBot } }, 2, 3, p.sh)
  tube(g, { { 40, 42 }, { 41, legBot } }, 2, 3, p.sh); tube(g, { { 44, 42 }, { 45, legBot } }, 2, 3, p.sh)
  disc(g, 20, legBot, 2, p.deep); disc(g, 25, legBot, 2, p.deep); disc(g, 41, legBot, 2, p.deep); disc(g, 45, legBot, 2, p.deep)
  tube(g, { { 44, 36 }, { hx - 3, 31 } }, 3, 3, p.sh)
  mass(g, hx, 29, 6, 5, p)
  ellipse(g, hx + 5, 30, 3, 2, p.base)
  line(g, hx - 2, 25, hx - 4, 25 - horn, p.bone); line(g, hx + 2, 25, hx + 4, 25 - horn, p.bone) -- cornes
  maw(g, hx + 4, 32, 2, p); eyeP(g, hx, 28, 1, p)
  tube(g, { { 18, 36 }, { 12, 33 }, { 9, 37 } }, 3, 1, p.sh)
  return { head = { x = hx, y = 29, r = 5 }, faceDir = { 1, 0 }, spine = { { 44, 33 }, { 32, 34 }, { 20, 35 } },
    limbs = { { 20, legBot }, { 25, legBot }, { 41, legBot }, { 45, legBot } }, belly = { x = 32, y = 42 }, mass = { { 30, 38, bodyRx - 1 } }, tailBase = { x = 18, y = 36 }, flesh = true }
end
function ARCH.aImp(g, rnd, p)
  local wing = 10 + floor(rnd() * 7)         -- envergure (ecart de la pointe d'aile)
  local wy = 13 + floor(rnd() * 5)           -- hauteur de la pointe d'aile
  local br = 5 + floor(rnd() * 3)            -- corps
  local horn = 4 + floor(rnd() * 3)
  local legBot = 50 + floor(rnd() * 5)
  polygon(g, { { 27, 28 }, { 32 - wing, wy }, { 22, 40 } }, p.sh); polygon(g, { { 37, 28 }, { 32 + wing, wy }, { 42, 40 } }, p.sh) -- ailes
  line(g, 27, 28, 32 - wing, wy, p.deep); line(g, 37, 28, 32 + wing, wy, p.deep)
  mass(g, 32, 34, br, 8, p)
  tube(g, { { 30, 40 }, { 29, legBot } }, 1, 2, p.sh); tube(g, { { 34, 40 }, { 35, legBot } }, 1, 2, p.sh)
  disc(g, 29, legBot, 1, p.deep); disc(g, 35, legBot, 1, p.deep)
  mass(g, 32, 24, 4, 4, p)
  line(g, 30, 21, 28, 21 - horn, p.bone); line(g, 34, 21, 36, 21 - horn, p.bone) -- cornes
  eyeP(g, 31, 24, 1, p); eyeP(g, 34, 24, 1, p)
  tube(g, { { 32, 41 }, { 36, 47 }, { 40, 45 } }, 2, 1, p.sh) -- queue
  polygon(g, { { 40, 45 }, { 44, 44 }, { 42, 48 } }, p.bone) -- dard
  return { head = { x = 32, y = 24, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 34 }, { 32, 40 } },
    limbs = { { 29, legBot }, { 35, legBot } }, belly = { x = 32, y = 36 }, mass = { { 32, 34, br } }, tailBase = { x = 32, y = 41 }, flesh = true }
end

-- ── INSECTOIDE (mandibules + antennes intrinseques a la tete) ──
function ARCH.aInsectoid(g, rnd, p)
  local abx = 9 + floor(rnd() * 4)           -- abdomen
  local thx = 6 + floor(rnd() * 3)           -- thorax
  local hr = 4 + floor(rnd() * 2)            -- tete
  local nLeg = 3 + floor(rnd() * 2)          -- 3..4 pattes
  local ant = 5 + floor(rnd() * 4)           -- longueur d'antenne
  mass(g, 22, 40, abx, 7, p); mass(g, 34, 39, thx, 6, p) -- abdomen + thorax
  for i = 0, nLeg - 1 do
    local lx = 36 - i * 3
    tube(g, { { lx, 42 }, { lx - 4, 50 }, { lx - 6, 56 } }, 1, 1, p.sh)
  end
  local hx = 40 + thx
  mass(g, hx, 38, hr, hr - 1, p) -- tete
  tube(g, { { hx + 4, 39 }, { hx + 7, 41 }, { hx + 5, 43 } }, 1, 1, p.bone); tube(g, { { hx + 4, 37 }, { hx + 7, 35 }, { hx + 5, 33 } }, 1, 1, p.bone) -- mandibules
  line(g, hx + 1, 35, hx + 5, 35 - ant, p.sh); line(g, hx + 3, 35, hx + 8, 37 - ant, p.sh) -- antennes
  for a = 0, 2 do for b = 0, 1 do set(g, hx - 1 + a, 37 + b, p.eye) end end -- oeil compose
  return { head = { x = hx, y = 38, r = hr }, faceDir = { 1, 0 }, spine = { { hx, 36 }, { 34, 35 }, { 22, 35 } },
    limbs = { { 30, 56 }, { 24, 56 }, { 18, 56 } }, belly = { x = 26, y = 44 }, mass = { { 22, 40, abx - 1 }, { 34, 39, thx } }, tailBase = { x = max(2, 22 - abx), y = 40 }, flesh = true }
end
function ARCH.aMantis(g, rnd, p)
  local abx = 7 + floor(rnd() * 3)           -- abdomen
  local thTop = 24 + floor(rnd() * 5)        -- hauteur du thorax dresse
  local hr = 3 + floor(rnd() * 2)
  local reach = 42 + floor(rnd() * 4)        -- allonge des bras ravisseurs
  mass(g, 28, 42, abx, 6, p)
  tube(g, { { 32, 42 }, { 34, round((42 + thTop) / 2) }, { 35, thTop + 2 } }, 3, 3, p.sh) -- thorax dresse
  tube(g, { { 26, 46 }, { 22, 52 }, { 20, 56 } }, 1, 1, p.sh)
  tube(g, { { 30, 46 }, { 28, 52 }, { 27, 56 } }, 1, 1, p.sh)
  tube(g, { { 34, 46 }, { 36, 52 }, { 37, 56 } }, 1, 1, p.sh)
  tube(g, { { 35, thTop + 4 }, { reach, thTop + 6 }, { reach + 2, thTop + 2 }, { reach, thTop - 2 } }, 2, 1, p.bone) -- bras ravisseur
  tube(g, { { 35, thTop + 5 }, { reach - 2, thTop + 9 }, { reach + 2, thTop + 8 } }, 2, 1, p.bone)
  mass(g, 36, thTop - hr, hr, hr, p)
  line(g, 35, thTop - hr - 3, 32, thTop - hr - 9, p.sh); line(g, 37, thTop - hr - 3, 40, thTop - hr - 9, p.sh) -- antennes
  set(g, 34, thTop - hr - 1, p.eye); set(g, 35, thTop - hr - 1, p.eye); set(g, 37, thTop - hr - 1, p.eye); set(g, 38, thTop - hr - 1, p.eye)
  return { head = { x = 36, y = thTop - hr, r = hr }, faceDir = { 1, -0.4 }, spine = { { 32, 40 }, { 34, round((40 + thTop) / 2) }, { 35, thTop } },
    limbs = { { 20, 56 }, { 27, 56 }, { 37, 56 } }, belly = { x = 28, y = 44 }, mass = { { 28, 42, abx - 1 }, { 36, thTop - hr, hr } }, tailBase = { x = 22, y = 42 }, flesh = true }
end
function ARCH.aSwarmflyer(g, rnd, p)
  local wing = 16 + floor(rnd() * 8)         -- envergure (pointe d'aile)
  local wyTop = 20 + floor(rnd() * 4)
  local bw = 4 + floor(rnd() * 2)            -- largeur du corps
  local ant = 6 + floor(rnd() * 3)
  polygon(g, { { 28, 30 }, { 32 - wing, wyTop }, { 24, 38 } }, p.hi); polygon(g, { { 36, 30 }, { 32 + wing, wyTop }, { 40, 38 } }, p.hi) -- ailes claires
  polygon(g, { { 28, 32 }, { 32 - wing + 4, wyTop + 8 }, { 26, 40 } }, p.sh); polygon(g, { { 36, 32 }, { 32 + wing - 4, wyTop + 8 }, { 38, 40 } }, p.sh)
  mass(g, 32, 40, bw + 1, 7, p); mass(g, 32, 32, bw, 4, p); mass(g, 32, 26, bw - 1, 3, p) -- corps segmente
  tube(g, { { 30, 38 }, { 29, 48 } }, 1, 1, p.sh); tube(g, { { 34, 38 }, { 35, 48 } }, 1, 1, p.sh); tube(g, { { 32, 40 }, { 32, 50 } }, 1, 1, p.sh)
  line(g, 31, 24, 29, 24 - ant, p.sh); line(g, 33, 24, 35, 24 - ant, p.sh) -- antennes
  set(g, 30, 26, p.eye); set(g, 31, 26, p.eye); set(g, 33, 26, p.eye); set(g, 34, 26, p.eye)
  return { head = { x = 32, y = 26, r = 3 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 36 }, { 32, 44 } },
    limbs = { { 29, 48 }, { 35, 48 } }, belly = { x = 32, y = 42 }, mass = { { 32, 40, bw + 1 }, { 32, 32, bw } }, tailBase = { x = 32, y = 46 }, flesh = true }
end

-- ── CEPHALOPODE (bulbe + couronne radiale de tentacules) ──
function ARCH.aOctopus(g, rnd, p)
  mass(g, 32, 26, 12, 12, p)
  local n = 8
  for i = 0, n - 1 do
    local ang = 0.45 + (math.pi - 0.9) * (i / (n - 1))
    radTentacle(g, 32, 36, ang, 16 + floor(rnd() * 8), 3, 3, 1, p.sh)
  end
  eyeP(g, 27, 25, 2, p); eyeP(g, 37, 25, 2, p)
  return { head = { x = 32, y = 24, r = 10 }, faceDir = { 0, -1 }, spine = { { 32, 18 }, { 32, 32 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 26, 11 } }, tailBase = nil, flesh = true }
end
function ARCH.aSquid(g, rnd, p)
  mass(g, 32, 26, 7, 12, p)
  polygon(g, { { 26, 17 }, { 38, 17 }, { 32, 7 } }, p.base); polygon(g, { { 27, 16 }, { 37, 16 }, { 32, 9 } }, p.sh)
  polygon(g, { { 25, 22 }, { 19, 26 }, { 25, 30 } }, p.sh); polygon(g, { { 39, 22 }, { 45, 26 }, { 39, 30 } }, p.sh)
  eyeP(g, 28, 28, 2, p); eyeP(g, 36, 28, 2, p)
  for i = 0, 5 do
    local bx = 27 + i * 2
    radTentacle(g, bx, 37, 1.3 + (bx - 32) * 0.05, 10 + floor(rnd() * 4), 2, 2, 1, p.sh)
  end
  radTentacle(g, 29, 37, 1.45, 22, 2, 2, 1, p.sh); radTentacle(g, 35, 37, 1.69, 22, 2, 2, 1, p.sh)
  return { head = { x = 32, y = 24, r = 7 }, faceDir = { 0, -1 }, spine = { { 32, 12 }, { 32, 30 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 26, 7 } }, tailBase = nil, flesh = true }
end
function ARCH.aReef(g, rnd, p)
  mass(g, 32, 34, 14, 9, p); maw(g, 32, 34, 4, p)
  local n = 10
  for i = 0, n - 1 do
    local ang = 6.283 * (i / n)
    radTentacle(g, 32 + cos(ang) * 9, 34 + sin(ang) * 5, ang, 10 + floor(rnd() * 6), 3, 2, 1, p.sh)
  end
  eyeP(g, 26, 30, 1, p); eyeP(g, 38, 31, 1, p); eyeP(g, 32, 27, 1, p)
  return { head = { x = 32, y = 30, r = 6 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 38 } },
    limbs = {}, belly = { x = 32, y = 36 }, mass = { { 32, 34, 13 } }, tailBase = nil, flesh = true }
end

-- ═══════════════════════════ TRAITEMENTS (legers, ancres sur l'anatomie) ═══════════════════════════
function TREAT.treatEldritch(g, rnd, p, A)
  for _ = 1, 2 + floor(rnd() * 5) do local pt = onMass(rnd, pickMass(rnd, A)); eyeP(g, pt[1], pt[2], 1 + (rnd() < 0.25 and 1 or 0), p) end
  for _ = 1, 1 + floor(rnd() * 4) do local gp = onMass(rnd, pickMass(rnd, A)); growth(g, gp[1], gp[2], p, rnd) end
  if rnd() < 0.55 then local mp = onMass(rnd, pickMass(rnd, A)); maw(g, mp[1], mp[2], 1 + floor(rnd() * 2), p) end
  if rnd() < 0.5 then
    local lp = onMass(rnd, pickMass(rnd, A))
    local dx = (rnd() - 0.5) * 22; local dy = -(rnd() * 14 + 4)
    tube(g, { { lp[1], lp[2] }, { lp[1] + dx * 0.5, lp[2] + dy * 0.6 }, { lp[1] + dx, lp[2] + dy } }, 3, 1, p.sh)
  end
end
function TREAT.treatUndead(g, rnd, p, A)
  local h = A.head; local so = round(h.r * 0.45)
  set(g, h.x - so, h.y - 1, p.eye); set(g, h.x + so, h.y - 1, p.eye) -- lueurs aux orbites
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, pickMass(rnd, A)); rstreak(g, pt[1], pt[2], 2, p.deep, rnd) end
  if A.flesh then -- revenant pourri : trous de chair + os a vif + viscere qui pend
    for _ = 1, 1 + floor(rnd() * 3) do
      local hp = onMass(rnd, pickMass(rnd, A)); local hr = 1 + floor(rnd() * 2)
      for dy = -hr, hr do for dx = -hr, hr do if dx * dx + dy * dy <= hr * hr then set(g, hp[1] + dx, hp[2] + dy, nil) end end end
    end
    for _ = 1, 2 + floor(rnd() * 3) do local bp = onMass(rnd, pickMass(rnd, A)); rstreak(g, bp[1], bp[2], 3, p.bone, rnd) end
    eyeP(g, h.x - 2, h.y, 1, p); eyeP(g, h.x + 2, h.y, 1, p)
    for _ = 1, 2 + floor(rnd() * 2) do
      local b = A.belly
      tube(g, { { b.x + round((rnd() - 0.5) * 8), b.y }, { b.x + round((rnd() - 0.5) * 10), b.y + 5 + floor(rnd() * 4) } }, 1, 1, p.deep)
    end
  else -- squelette : un os manque parfois
    if rnd() < 0.5 and #A.limbs > 0 then local l = A.limbs[1 + floor(rnd() * #A.limbs)]; disc(g, l[1], l[2], 1, nil) end
  end
end
function TREAT.treatBeast(g, rnd, p, A)
  for _ = 1, 2 + floor(rnd() * 4) do local pt = onMass(rnd, pickMass(rnd, A)); rstreak(g, pt[1], pt[2], 2.5, p.scar, rnd) end -- cicatrices
  if rnd() < 0.6 then local w = A.belly; disc(g, w.x + round((rnd() - 0.5) * 6), w.y, 2, p.wound) end -- plaie
  if rnd() < 0.5 and #A.limbs > 0 then -- bandage sur un membre
    local l = A.limbs[1 + floor(rnd() * #A.limbs)]
    for k = -3, 3 do set(g, l[1] + k, l[2] - 3, p.bone); set(g, l[1] + k, l[2] - 2, p.bone) end
  end
  for _ = 1, 2 + floor(rnd() * 3) do -- mouchetures de fourrure (dither)
    local pp = onMass(rnd, pickMass(rnd, A))
    for dy = -2, 2 do for dx = -2, 2 do
      if ((pp[1] + dx + pp[2] + dy) % 2 == 1) and (dx * dx + dy * dy <= 4) then set(g, pp[1] + dx, pp[2] + dy, p.deep) end
    end end
  end
end
function TREAT.treatDemon(g, rnd, p, A)
  local h = A.head
  if rnd() < 0.45 then -- petites cornes supplementaires au crane
    line(g, h.x - 1, h.y - h.r + 1, h.x - 3, h.y - h.r - 4, p.bone); line(g, h.x + 1, h.y - h.r + 1, h.x + 3, h.y - h.r - 4, p.bone)
  end
  for s = 1, #A.spine - 1 do -- echines dorsales le long de la colonne
    local a, b = A.spine[s], A.spine[s + 1]
    local t = 0
    while t <= 1 do
      local x = a[1] + (b[1] - a[1]) * t; local y = a[2] + (b[2] - a[2]) * t
      polygon(g, { { x - 2, y }, { x + 2, y }, { x, y - 4 } }, p.deep)
      t = t + 0.5
    end
  end
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, pickMass(rnd, A)); rstreak(g, pt[1], pt[2], 3, p.eye, rnd) end -- braise
  if A.tailBase and rnd() < 0.5 then
    local tb = A.tailBase
    tube(g, { { tb.x, tb.y }, { tb.x - 6, tb.y + 6 }, { tb.x - 9, tb.y + 3 } }, 2, 1, p.sh); disc(g, tb.x - 9, tb.y + 3, 1, p.eye)
  end
end
function TREAT.treatInsect(g, rnd, p, A)
  for i = 1, #A.mass do -- segmentation chitineuse (liseres clair/sombre)
    local m = A.mass[i]
    line(g, m[1] - m[3] + 1, m[2] - round(m[3] * 0.4), m[1] + m[3] - 1, m[2] - round(m[3] * 0.4), p.hi)
    line(g, m[1] - m[3] + 1, m[2] + 1, m[1] + m[3] - 1, m[2] + 1, p.deep)
  end
  for _ = 1, 2 + floor(rnd() * 2) do -- filaments d'abdomen
    local b = A.belly
    tube(g, { { b.x + round((rnd() - 0.5) * 10), b.y }, { b.x + round((rnd() - 0.5) * 14), b.y + 8 + floor(rnd() * 3) } }, 1, 1, p.sh)
  end
end
-- ── V1 ténèbres part A : traitements ──
function TREAT.treatCephalo(g, rnd, p, A)
  local m = A.mass[1]
  line(g, m[1] - m[3] + 2, m[2] - round(m[3] * 0.5), m[1] + m[3] - 2, m[2] - round(m[3] * 0.5), p.hi)
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.eye) end
  if rnd() < 0.5 then local e = onMass(rnd, m); eyeP(g, e[1], e[2], 1, p) end
end

-- ═══════════════════════════ V1 ténèbres part A (reste) : gelatine/oeil/spore/ombre/essaim/annelide ═══════
-- palettes
local GELATIN = {
  { deep = 0x1e4a2a, sh = 0x2e6a3e, base = 0x46a05e, hi = 0x9ae0a8, bone = 0xe8ffe0, eye = 0xeaffd0, eyeDim = 0xa8d88a, out = 0x0e2a18 },
  { deep = 0x143a4a, sh = 0x1e5a6e, base = 0x2e8aa0, hi = 0x7ad0e0, bone = 0xe0fbff, eye = 0xd0faff, eyeDim = 0x8ad0e0, out = 0x08222e },
  { deep = 0x2a1a4a, sh = 0x3e2a6e, base = 0x5a3ea0, hi = 0x9a7ad0, bone = 0xede0ff, eye = 0xe0d0ff, eyeDim = 0xb09ad8, out = 0x160a2e },
  { deep = 0x4a1414, sh = 0x6e1e1e, base = 0xa02e2e, hi = 0xe07a7a, bone = 0xffe0e0, eye = 0xffd0d0, eyeDim = 0xd88a8a, out = 0x2a0808 },
  { deep = 0x4a4214, sh = 0x6e6220, base = 0xa09a2e, hi = 0xe0d87a, bone = 0xfffbe0, eye = 0xfdffd0, eyeDim = 0xd8d08a, out = 0x2a2608 },
}
local EYEPAL = {
  { deep = 0x241820, sh = 0x3e2e38, base = 0x5e4a56, hi = 0x8a727e, bone = 0xf0ece0, eye = 0xff5a4a, eyeDim = 0xa83a3a, out = 0x120a10 },
  { deep = 0x221a24, sh = 0x3a2e40, base = 0x564a60, hi = 0x80728a, bone = 0xf0ece0, eye = 0xffd23a, eyeDim = 0xc8a01a, out = 0x100a12 },
  { deep = 0x1a2420, sh = 0x2e3e36, base = 0x4a5e54, hi = 0x728a80, bone = 0xeef0e8, eye = 0x6aff9a, eyeDim = 0x3aa860, out = 0x0a120e },
  { deep = 0x1a2028, sh = 0x2e3a44, base = 0x4a5a66, hi = 0x728590, bone = 0xe8eef0, eye = 0x6ad0ff, eyeDim = 0x3a90c0, out = 0x0a1014 },
}
local SPORE = {
  { deep = 0x1e3014, sh = 0x345220, base = 0x567a32, hi = 0x86a850, bone = 0xd0d8a0, eye = 0xaeff5a, eyeDim = 0x6ac83a, out = 0x0e1808 },
  { deep = 0x241a30, sh = 0x3e2e52, base = 0x624a7a, hi = 0x9a7ab0, bone = 0xd0c0d8, eye = 0xe08aff, eyeDim = 0xa84ac8, out = 0x120c18 },
  { deep = 0x2e2614, sh = 0x4e4222, base = 0x7a6638, hi = 0xa89050, bone = 0xe0d0a0, eye = 0xffe05a, eyeDim = 0xc8a83a, out = 0x161008 },
  { deep = 0x142a30, sh = 0x244a52, base = 0x3a7a86, hi = 0x6ab0c0, bone = 0xc0e0e8, eye = 0x6affe0, eyeDim = 0x3ac8b0, out = 0x081618 },
}
local SHADOW = {
  { deep = 0x0e0c14, sh = 0x141220, base = 0x1b1828, hi = 0x2a2640, bone = 0x4a4560, eye = 0x9a7aff, eyeDim = 0x5a3aa8, out = 0x3a3552 },
  { deep = 0x120c0c, sh = 0x1c1414, base = 0x241a1a, hi = 0x3a2a2a, bone = 0x5a4545, eye = 0xff5a4a, eyeDim = 0xa83a2a, out = 0x4a3535 },
  { deep = 0x0c120c, sh = 0x141c14, base = 0x1a241a, hi = 0x2a3a2a, bone = 0x455a45, eye = 0x6aff9a, eyeDim = 0x3aa860, out = 0x35523a },
}
local SWARM = {
  { deep = 0x1e1810, sh = 0x34281a, base = 0x56402a, hi = 0x7c5e3e, bone = 0xc0a880, eye = 0xffce5a, eyeDim = 0xc8983a, out = 0x0e0a06 },
  { deep = 0x14201a, sh = 0x24382a, base = 0x3a5a42, hi = 0x5a8a64, bone = 0xb0c0a0, eye = 0x9aff6a, eyeDim = 0x5ac83a, out = 0x080e0a },
  { deep = 0x1a141e, sh = 0x2e2434, base = 0x4a3a52, hi = 0x6e5a7a, bone = 0xb0a0c0, eye = 0xc08aff, eyeDim = 0x7a4ac8, out = 0x0c0810 },
}
local WORM = {
  { deep = 0x2e1a1a, sh = 0x4e2e2e, base = 0x7a4a4a, hi = 0xb07a7a, bone = 0xe0c0c0, eye = 0xff8a8a, eyeDim = 0xc85a5a, out = 0x160a0a },
  { deep = 0x22201e, sh = 0x3a3632, base = 0x585250, hi = 0x807672, bone = 0xc0b8b0, eye = 0xffae8a, eyeDim = 0xc8805a, out = 0x100e0c },
  { deep = 0x3a2a30, sh = 0x5e4450, base = 0x8a6470, hi = 0xb89098, bone = 0xf0d8e0, eye = 0xff9ab0, eyeDim = 0xc86a80, out = 0x1c1016 },
  { deep = 0x2a2a14, sh = 0x464622, base = 0x707038, hi = 0x9c9c5a, bone = 0xd8d8a0, eye = 0xeaff6a, eyeDim = 0xa8a83a, out = 0x141408 },
}
-- archetypes : GELATINEUX (rond mou, subverti)
function ARCH.aSlime(g, rnd, p)
  blob(g, 32, 40, 13, 11, p, rnd)
  eyeP(g, 28, 40, 1, p); eyeP(g, 36, 40, 1, p)
  set(g, 31, 45, p.deep); set(g, 32, 45, p.deep); set(g, 33, 45, p.deep); set(g, 32, 46, p.deep)
  return { head = { x = 32, y = 38, r = 8 }, faceDir = { 0, -1 }, spine = { { 32, 32 }, { 32, 44 } },
    limbs = {}, belly = { x = 32, y = 42 }, mass = { { 32, 40, 12 } }, tailBase = nil, flesh = true }
end
function ARCH.aOoze(g, rnd, p)
  ellipse(g, 32, 48, 18, 5, p.sh); ellipse(g, 32, 47, 16, 4, p.base)
  blob(g, 32, 38, 12, 10, p, rnd)
  tube(g, { { 20, 44 }, { 14, 46 }, { 10, 44 } }, 3, 1, p.base); tube(g, { { 44, 44 }, { 50, 46 }, { 54, 44 } }, 3, 1, p.base)
  for i = 0, 2 do
    local dx = 22 + i * 9; local dl = 48 + floor(rnd() * 4)
    tube(g, { { dx, 44 }, { dx, dl } }, 1, 1, p.base); disc(g, dx, dl, 1, p.base)
  end
  eyeP(g, 29, 36, 1, p); eyeP(g, 36, 37, 1, p)
  return { head = { x = 32, y = 36, r = 7 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 42 } },
    limbs = {}, belly = { x = 32, y = 40 }, mass = { { 32, 38, 11 } }, tailBase = nil, flesh = true }
end
function ARCH.aBlobMonster(g, rnd, p)
  blob(g, 32, 38, 15, 13, p, rnd)
  disc(g, 26, 40, 1, p.deep); disc(g, 30, 44, 1, p.deep); disc(g, 36, 36, 1, p.deep)
  line(g, 33, 42, 37, 44, p.bone)
  eyeP(g, 28, 34, 1, p); eyeP(g, 35, 33, 1, p); eyeP(g, 32, 40, 2, p)
  return { head = { x = 32, y = 34, r = 9 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 44 } },
    limbs = {}, belly = { x = 32, y = 42 }, mass = { { 32, 38, 14 } }, tailBase = nil, flesh = true }
end
-- archetypes : ŒIL AILÉ (grappe radiale flottante)
function ARCH.aEyeball(g, rnd, p)
  polygon(g, { { 26, 28 }, { 10, 18 }, { 22, 38 } }, p.sh); polygon(g, { { 38, 28 }, { 54, 18 }, { 42, 38 } }, p.sh)
  line(g, 26, 28, 10, 18, p.deep); line(g, 38, 28, 54, 18, p.deep)
  local r = 11
  disc(g, 32, 28, r, p.deep); disc(g, 32, 28, r - 1, p.bone)
  for _ = 1, 5 do local a = rnd() * 6.283; line(g, 32, 28, 32 + cos(a) * (r - 3), 28 + sin(a) * (r - 3), p.eyeDim) end
  disc(g, 32, 28, 5, p.eye); disc(g, 32, 28, 2, p.out); set(g, 30, 26, p.bone)
  for i = 0, 3 do local tx = 26 + i * 4; tentacle(g, tx, 38, 10 + floor(rnd() * 6), (i - 1.5) * 0.3, 2, 2, 1, p.sh) end
  return { head = { x = 32, y = 28, r = r }, faceDir = { 0, -1 }, spine = { { 32, 20 }, { 32, 36 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 28, 10 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aEyeCluster(g, rnd, p)
  mass(g, 32, 30, 11, 10, p)
  polygon(g, { { 24, 28 }, { 12, 22 }, { 22, 36 } }, p.sh); polygon(g, { { 40, 28 }, { 52, 22 }, { 42, 36 } }, p.sh)
  local spots = { { 26, 26, 2 }, { 36, 25, 2 }, { 30, 32, 1 }, { 37, 33, 2 }, { 24, 34, 1 }, { 33, 28, 3 }, { 40, 30, 1 } }
  for i = 1, #spots do eyeP(g, spots[i][1], spots[i][2], spots[i][3], p) end
  for i = 0, 4 do local tx = 24 + i * 4; tentacle(g, tx, 40, 8 + floor(rnd() * 6), (i - 2) * 0.3, 2, 2, 1, p.sh) end
  return { head = { x = 33, y = 28, r = 3 }, faceDir = { 0, -1 }, spine = { { 32, 24 }, { 32, 38 } },
    limbs = {}, belly = { x = 32, y = 36 }, mass = { { 32, 30, 10 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aEyeSwarm(g, rnd, p)
  local es = { { 32, 24, 3 }, { 24, 30, 2 }, { 40, 30, 2 }, { 28, 38, 2 }, { 37, 38, 2 }, { 32, 33, 2 } }
  for i = 2, #es do line(g, es[1][1], es[1][2], es[i][1], es[i][2], p.sh) end
  for i = 1, #es do eyeP(g, es[i][1], es[i][2], es[i][3], p) end
  return { head = { x = 32, y = 24, r = 3 }, faceDir = { 0, -1 }, spine = { { 32, 24 }, { 32, 38 } },
    limbs = {}, belly = { x = 32, y = 33 }, mass = { { 32, 30, 9 } }, tailBase = nil, flesh = true, float = true }
end
-- archetypes : ENGEANCE FONGIQUE (enraciné, chapeaux, spores)
function ARCH.aSporeWalker(g, rnd, p)
  tube(g, { { 29, 40 }, { 28, 56 } }, 2, 2, p.base); tube(g, { { 35, 40 }, { 36, 56 } }, 2, 2, p.base)
  disc(g, 28, 56, 2, p.deep); disc(g, 36, 56, 2, p.deep)
  mass(g, 32, 36, 7, 8, p)
  tube(g, { { 27, 32 }, { 22, 30 }, { 18, 32 } }, 2, 1, p.base); tube(g, { { 37, 32 }, { 42, 30 }, { 46, 32 } }, 2, 1, p.base)
  mushroomCap(g, 18, 32, 3, 2, p); mushroomCap(g, 46, 32, 3, 2, p); mushroomCap(g, 32, 24, 9, 7, p)
  eyeP(g, 30, 26, 1, p); eyeP(g, 34, 26, 1, p)
  for _ = 1, 5 do set(g, 24 + floor(rnd() * 16), 12 + floor(rnd() * 6), p.eye) end
  return { head = { x = 32, y = 24, r = 7 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 40 } },
    limbs = { { 28, 56 }, { 36, 56 } }, belly = { x = 32, y = 38 }, mass = { { 32, 36, 7 } }, tailBase = nil, flesh = true }
end
function ARCH.aMyconid(g, rnd, p)
  mass(g, 32, 46, 15, 8, p)
  mushroomCap(g, 24, 38, 4, 4, p); mushroomCap(g, 40, 40, 5, 4, p); mushroomCap(g, 32, 32, 8, 7, p)
  mushroomCap(g, 18, 42, 3, 3, p); mushroomCap(g, 46, 44, 3, 3, p)
  eyeP(g, 30, 36, 1, p); eyeP(g, 34, 36, 1, p)
  for _ = 1, 6 do set(g, 20 + floor(rnd() * 24), 20 + floor(rnd() * 8), p.eye) end
  return { head = { x = 32, y = 34, r = 7 }, faceDir = { 0, -1 }, spine = { { 32, 36 }, { 32, 46 } },
    limbs = {}, belly = { x = 32, y = 46 }, mass = { { 32, 44, 13 } }, tailBase = nil, flesh = true }
end
function ARCH.aInfectedHost(g, rnd, p)
  tube(g, { { 28, 42 }, { 27, 56 } }, 3, 2, p.sh); tube(g, { { 37, 42 }, { 38, 56 } }, 3, 2, p.sh)
  disc(g, 27, 56, 2, p.deep); disc(g, 38, 56, 2, p.deep)
  mass(g, 33, 36, 8, 10, p)
  tube(g, { { 28, 30 }, { 24, 40 }, { 24, 48 } }, 2, 2, p.sh); tube(g, { { 39, 30 }, { 43, 40 }, { 43, 48 } }, 2, 2, p.sh)
  mass(g, 35, 24, 5, 5, p); eyeP(g, 34, 24, 1, p)
  tube(g, { { 30, 30 }, { 28, 24 } }, 1, 1, p.base); mushroomCap(g, 28, 24, 4, 3, p)
  tube(g, { { 36, 30 }, { 39, 25 } }, 1, 1, p.base); mushroomCap(g, 39, 25, 3, 2, p); mushroomCap(g, 33, 30, 3, 2, p)
  for _ = 1, 5 do set(g, 26 + floor(rnd() * 16), 16 + floor(rnd() * 6), p.eye) end
  return { head = { x = 35, y = 24, r = 5 }, faceDir = { 1, -0.3 }, spine = { { 33, 30 }, { 33, 42 } },
    limbs = { { 24, 48 }, { 43, 48 } }, belly = { x = 33, y = 38 }, mass = { { 33, 36, 8 } }, tailBase = nil, flesh = true }
end
-- archetypes : OMBRE DU NÉANT (silhouette noire, yeux flottants)
function ARCH.aShade(g, rnd, p)
  ellipse(g, 32, 40, 7, 9, p.base); ellipse(g, 32, 24, 5, 5, p.base)
  tube(g, { { 28, 32 }, { 24, 44 } }, 3, 2, p.base); tube(g, { { 36, 32 }, { 40, 44 } }, 3, 2, p.base)
  tube(g, { { 30, 46 }, { 29, 56 } }, 3, 2, p.base); tube(g, { { 35, 46 }, { 36, 56 } }, 3, 2, p.base)
  eyeP(g, 30, 23, 1, p); eyeP(g, 34, 23, 1, p)
  return { head = { x = 32, y = 24, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 42 } },
    limbs = { { 24, 44 }, { 40, 44 }, { 29, 56 }, { 36, 56 } }, belly = { x = 32, y = 40 }, mass = { { 32, 40, 8 }, { 32, 24, 4 } }, tailBase = nil, flesh = false }
end
function ARCH.aVoidMaw(g, rnd, p)
  ellipse(g, 32, 38, 14, 12, p.base); ellipse(g, 32, 38, 6, 7, p.deep)
  eyeP(g, 24, 32, 1, p); eyeP(g, 40, 34, 1, p); eyeP(g, 30, 46, 1, p); eyeP(g, 38, 44, 1, p); eyeP(g, 32, 28, 2, p)
  return { head = { x = 32, y = 32, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 44 } },
    limbs = {}, belly = { x = 32, y = 40 }, mass = { { 32, 38, 13 } }, tailBase = nil, flesh = false }
end
-- archetypes : ESSAIM VERMINE (nuage cohérent de petits corps)
function ARCH.aSwarm(g, rnd, p)
  local cx, cy, rx, ry = 32, 34, 16, 14
  for _ = 1, 34 do
    local a = rnd() * 6.283; local rr = sqrt(rnd())
    miniBug(g, round(cx + cos(a) * rx * rr), round(cy + sin(a) * ry * rr), p, rnd)
  end
  return { head = { x = 32, y = 30, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 40 } },
    limbs = {}, belly = { x = 32, y = 38 }, mass = { { 32, 34, 14 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aHive(g, rnd, p)
  for _ = 1, 40 do
    local a = rnd() * 6.283; local rr = sqrt(rnd())
    miniBug(g, round(32 + cos(a) * 9 * rr), round(34 + sin(a) * 16 * rr), p, rnd)
  end
  disc(g, 28, 30, 2, p.base); eyeP(g, 28, 30, 1, p); disc(g, 36, 40, 2, p.base); eyeP(g, 36, 40, 1, p)
  return { head = { x = 32, y = 24, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 26 }, { 32, 44 } },
    limbs = {}, belly = { x = 32, y = 40 }, mass = { { 32, 34, 10 } }, tailBase = nil, flesh = true, float = true }
end
-- archetypes : ANNÉLIDE FOREUR (anneaux segmentés, gueule ronde)
function ARCH.aGraboid(g, rnd, p)
  local pts = {}
  for i = 0, 7 do local t = i / 7; pts[#pts + 1] = { round(32 + sin(t * 2) * 4), round(56 - t * 34) } end
  segChain(g, pts, 6, 4, p)
  local hx, hy = pts[8][1], pts[8][2]
  polygon(g, { { hx - 5, hy }, { hx - 9, hy - 4 }, { hx - 3, hy - 3 } }, p.sh)
  polygon(g, { { hx + 5, hy }, { hx + 9, hy - 4 }, { hx + 3, hy - 3 } }, p.sh)
  ringMaw(g, hx, hy, 4, p)
  return { head = { x = hx, y = hy, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 50 } },
    limbs = {}, belly = { x = 32, y = 44 }, mass = { { 32, 42, 8 } }, tailBase = { x = 32, y = 56 }, flesh = true }
end
function ARCH.aLeech(g, rnd, p)
  local pts = {}
  for i = 0, 8 do local t = i / 8; pts[#pts + 1] = { round(10 + t * 44), round(40 + sin(t * 6) * 8) } end
  segChain(g, pts, 3, 5, p)
  local hx, hy = pts[9][1], pts[9][2]
  ringMaw(g, hx, hy, 4, p)
  return { head = { x = hx, y = hy, r = 4 }, faceDir = { 1, 0 }, spine = { { 20, 40 }, { 44, 40 } },
    limbs = {}, belly = { x = 32, y = 42 }, mass = { { 32, 40, 8 } }, tailBase = { x = 10, y = 40 }, flesh = true }
end
-- traitements V1 reste
function TREAT.treatGelatin(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, m); disc(g, pt[1], pt[2], 1, p.deep); set(g, pt[1] - 1, pt[2] - 1, p.hi) end
  if rnd() < 0.6 then local e = onMass(rnd, m); eyeP(g, e[1], e[2], 1, p) end
  if rnd() < 0.4 then
    local d = A.belly
    tube(g, { { d.x + round((rnd() - 0.5) * 10), d.y + 2 }, { d.x + round((rnd() - 0.5) * 10), d.y + 6 + floor(rnd() * 4) } }, 1, 1, p.base)
  end
end
function TREAT.treatEye(g, rnd, p, A)
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, A.mass[1]); eyeP(g, pt[1], pt[2], 1, p) end
  if rnd() < 0.5 then local t = A.belly; tentacle(g, t.x + round((rnd() - 0.5) * 8), t.y, 8 + floor(rnd() * 5), (rnd() - 0.5) * 0.6, 2, 2, 1, p.sh) end
end
function TREAT.treatSpore(g, rnd, p, A)
  for _ = 1, 5 + floor(rnd() * 5) do set(g, round(A.head.x + (rnd() - 0.5) * 22), round(A.head.y - 8 + (rnd() - 0.5) * 10), p.eye) end
  if rnd() < 0.5 then local pt = onMass(rnd, A.mass[1]); mushroomCap(g, pt[1], pt[2], 2, 2, p) end
  for _ = 1, 2 do local d = onMass(rnd, A.mass[1]); disc(g, d[1], d[2], 1, p.hi) end
end
function TREAT.treatShadow(g, rnd, p, A)
  for _ = 1, 2 + floor(rnd() * 4) do local pt = onMass(rnd, pickMass(rnd, A)); eyeP(g, pt[1], pt[2], 1, p) end
  local b = A.belly
  for _ = 1, 2 do
    tube(g, { { b.x + round((rnd() - 0.5) * 10), b.y }, { b.x + round((rnd() - 0.5) * 12), b.y + 5 + floor(rnd() * 4) } }, 1, 1, p.base)
  end
end
function TREAT.treatSwarm(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 8 + floor(rnd() * 8) do
    local a = rnd() * 6.283; local rr = sqrt(rnd())
    miniBug(g, round(m[1] + cos(a) * m[3] * rr * 1.1), round(m[2] + sin(a) * m[3] * rr * 1.1), p, rnd)
  end
end
function TREAT.treatWorm(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 3 do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.hi) end
  if rnd() < 0.4 then eyeP(g, A.head.x, A.head.y, 1, p) end
end

-- ═══════════════════════════ V3 : archetypes v7 des familles EXISTANTES (bete/demon) ═══════════════════════
-- bete = {dragon (conservé, paramétrique), behemoth, direcat} ; demon = {fiend, serpent, imp (conservé)}.
-- Les treats restent treatBeast/treatDemon. Réutilise palettes BEAST/DEMON. (insecte/cauchemar : juste maj des archs.)
function ARCH.aBehemoth(g, rnd, p)
  mass(g, 32, 38, 17, 10, p); mass(g, 24, 32, 7, 6, p)
  tube(g, { { 22, 46 }, { 20, 56 } }, 5, 4, p.sh); tube(g, { { 29, 46 }, { 28, 56 } }, 5, 4, p.sh)
  tube(g, { { 38, 46 }, { 39, 56 } }, 5, 4, p.sh); tube(g, { { 44, 46 }, { 45, 56 } }, 5, 4, p.sh)
  disc(g, 20, 56, 3, p.deep); disc(g, 28, 56, 3, p.deep); disc(g, 39, 56, 3, p.deep); disc(g, 45, 56, 3, p.deep)
  tube(g, { { 48, 40 }, { 54, 42 }, { 56, 38 } }, 2, 1, p.sh)
  mass(g, 18, 34, 6, 5, p)
  polygon(g, { { 14, 33 }, { 8, 28 }, { 12, 34 } }, p.bone); polygon(g, { { 18, 31 }, { 20, 24 }, { 15, 30 } }, p.bone)
  eyeP(g, 15, 33, 1, p); set(g, 12, 36, p.deep)
  return { head = { x = 16, y = 34, r = 6 }, faceDir = { -1, 0 }, spine = { { 24, 34 }, { 34, 38 }, { 44, 40 } },
    limbs = { { 20, 56 }, { 28, 56 }, { 39, 56 }, { 45, 56 } }, belly = { x = 34, y = 46 }, mass = { { 32, 38, 16 }, { 18, 34, 5 } }, tailBase = { x = 48, y = 40 }, flesh = true }
end
function ARCH.aDirecat(g, rnd, p)
  mass(g, 31, 40, 14, 6, p); mass(g, 22, 36, 6, 5, p)
  tube(g, { { 20, 44 }, { 18, 55 } }, 2, 2, p.sh); tube(g, { { 26, 45 }, { 25, 56 } }, 2, 2, p.sh)
  tube(g, { { 37, 45 }, { 38, 56 } }, 2, 2, p.sh); tube(g, { { 42, 44 }, { 44, 55 } }, 2, 2, p.sh)
  disc(g, 18, 55, 2, p.deep); disc(g, 25, 56, 2, p.deep); disc(g, 38, 56, 2, p.deep); disc(g, 44, 55, 2, p.deep)
  tube(g, { { 44, 38 }, { 52, 34 }, { 56, 28 }, { 54, 24 } }, 2, 1, p.sh)
  mass(g, 17, 34, 5, 4, p)
  polygon(g, { { 14, 33 }, { 16, 28 }, { 18, 33 } }, p.base); polygon(g, { { 19, 33 }, { 21, 28 }, { 22, 33 } }, p.base)
  polygon(g, { { 15, 37 }, { 16, 42 }, { 17, 37 } }, p.bone); polygon(g, { { 19, 37 }, { 20, 42 }, { 21, 37 } }, p.bone)
  eyeP(g, 15, 34, 1, p); eyeP(g, 19, 34, 1, p)
  return { head = { x = 17, y = 34, r = 5 }, faceDir = { -1, 0 }, spine = { { 24, 36 }, { 32, 39 }, { 42, 40 } },
    limbs = { { 18, 55 }, { 25, 56 }, { 38, 56 }, { 44, 55 } }, belly = { x = 32, y = 46 }, mass = { { 31, 40, 13 }, { 17, 34, 4 } }, tailBase = { x = 44, y = 38 }, flesh = true }
end
function ARCH.aFiend(g, rnd, p)
  tube(g, { { 28, 40 }, { 27, 48 }, { 28, 56 } }, 2, 2, p.sh); tube(g, { { 36, 40 }, { 37, 48 }, { 36, 56 } }, 2, 2, p.sh)
  polygon(g, { { 26, 55 }, { 28, 55 }, { 27, 58 } }, p.deep); polygon(g, { { 36, 55 }, { 38, 55 }, { 37, 58 } }, p.deep)
  polygon(g, { { 22, 23 }, { 42, 23 }, { 37, 42 }, { 27, 42 } }, p.base); polygon(g, { { 27, 36 }, { 37, 36 }, { 37, 42 }, { 27, 42 } }, p.sh)
  line(g, 25, 25, 39, 25, p.hi)
  tube(g, { { 24, 25 }, { 19, 35 }, { 18, 45 } }, 2, 2, p.sh); tube(g, { { 40, 25 }, { 45, 35 }, { 46, 45 } }, 2, 2, p.sh)
  polygon(g, { { 17, 45 }, { 19, 45 }, { 18, 49 } }, p.bone); polygon(g, { { 45, 45 }, { 47, 45 }, { 46, 49 } }, p.bone)
  polygon(g, { { 29, 14 }, { 35, 14 }, { 34, 22 }, { 30, 22 } }, p.base)
  line(g, 30, 15, 34, 15, p.hi)
  tube(g, { { 30, 15 }, { 25, 10 }, { 23, 4 } }, 2, 1, p.bone); tube(g, { { 34, 15 }, { 39, 10 }, { 41, 4 } }, 2, 1, p.bone)
  for i = 0, 3 do local sy = 25 + i * 4; polygon(g, { { 30, sy }, { 34, sy }, { 32, sy - 4 } }, p.deep) end
  set(g, 30, 19, p.eye); set(g, 33, 19, p.eye); set(g, 30, 18, p.eyeDim); set(g, 33, 18, p.eyeDim)
  tube(g, { { 32, 42 }, { 37, 48 }, { 42, 46 } }, 2, 1, p.sh); polygon(g, { { 42, 46 }, { 46, 45 }, { 44, 49 } }, p.bone)
  return { head = { x = 32, y = 19, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 24 }, { 32, 32 }, { 32, 40 } },
    limbs = { { 18, 45 }, { 46, 45 }, { 28, 56 }, { 36, 56 } }, belly = { x = 32, y = 34 }, mass = { { 32, 32, 8 } }, tailBase = { x = 32, y = 42 }, flesh = true }
end
function ARCH.aSerpent(g, rnd, p)
  tube(g, { { 20, 54 }, { 14, 48 }, { 18, 42 }, { 28, 40 }, { 33, 34 }, { 32, 27 } }, 5, 3, p.base)
  tube(g, { { 20, 54 }, { 30, 52 }, { 36, 48 }, { 30, 46 }, { 22, 48 } }, 3, 2, p.sh)
  polygon(g, { { 28, 21 }, { 36, 21 }, { 35, 28 }, { 29, 28 } }, p.base)
  tube(g, { { 29, 22 }, { 25, 17 }, { 24, 11 } }, 2, 1, p.bone); tube(g, { { 35, 22 }, { 39, 17 }, { 40, 11 } }, 2, 1, p.bone)
  polygon(g, { { 28, 23 }, { 22, 19 }, { 24, 27 } }, p.sh); polygon(g, { { 36, 23 }, { 42, 19 }, { 40, 27 } }, p.sh)
  set(g, 30, 25, p.eye); set(g, 34, 25, p.eye)
  polygon(g, { { 26, 40 }, { 30, 40 }, { 28, 36 } }, p.deep); polygon(g, { { 31, 33 }, { 35, 33 }, { 33, 29 } }, p.deep)
  line(g, 32, 28, 32, 31, p.eye)
  return { head = { x = 32, y = 24, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 27 }, { 30, 34 }, { 24, 44 } },
    limbs = {}, belly = { x = 28, y = 44 }, mass = { { 28, 42, 7 }, { 32, 30, 5 } }, tailBase = { x = 20, y = 54 }, flesh = true }
end

-- ═══════════════════════════ V2 ténèbres part B : golem/spectre/culte/abyssal/cristal/aile/colosse ═══════
local GOLEM = {
  { deep = 0x26262e, sh = 0x3e3e48, base = 0x5e5e6a, hi = 0x86868e, bone = 0xb0b0b8, eye = 0x7ad0ff, eyeDim = 0x3a8ac0, out = 0x121216 },
  { deep = 0x3a2e1c, sh = 0x5e4a2e, base = 0x8a6e44, hi = 0xb89a64, bone = 0xe0c898, eye = 0xffce5a, eyeDim = 0xc8983a, out = 0x1c1408 },
  { deep = 0x16161e, sh = 0x26262e, base = 0x3a3a44, hi = 0x5a5a64, bone = 0x8a8a94, eye = 0xc08aff, eyeDim = 0x7a4ac8, out = 0x0a0a10 },
  { deep = 0x202a22, sh = 0x34463a, base = 0x506a52, hi = 0x7a8c6a, bone = 0xb0bc98, eye = 0x9aff7a, eyeDim = 0x5ac83a, out = 0x0e140e },
}
local SPECTRE = {
  { deep = 0x1a2e3a, sh = 0x2e4a5e, base = 0x4a7a92, hi = 0x9ad0e8, bone = 0xe0f4ff, eye = 0xaef0ff, eyeDim = 0x6ac0e0, out = 0x0c1822 },
  { deep = 0x1a3a2e, sh = 0x2e5e4a, base = 0x4a927a, hi = 0x9ae8d0, bone = 0xe0fff4, eye = 0xaeffd0, eyeDim = 0x6ae0b0, out = 0x0c2218 },
  { deep = 0x2a1a3a, sh = 0x46305e, base = 0x724a92, hi = 0xc09ae8, bone = 0xf0e0ff, eye = 0xe0aeff, eyeDim = 0xb06ae0, out = 0x160c22 },
}
local CULT = {
  { deep = 0x1a0810, sh = 0x3a1420, base = 0x5e1e30, hi = 0x8a3048, bone = 0xd0b0a0, eye = 0xff5a4a, eyeDim = 0xc83a2a, out = 0x0e0408 },
  { deep = 0x160a1e, sh = 0x2e1640, base = 0x4a2666, hi = 0x724a92, bone = 0xc0b0d0, eye = 0xc08aff, eyeDim = 0x7a4ac8, out = 0x0a040e },
  { deep = 0x121016, sh = 0x222026, base = 0x36343c, hi = 0x56545c, bone = 0xb0aca0, eye = 0xffce5a, eyeDim = 0xc8983a, out = 0x08080a },
}
local ABYSSAL = {
  { deep = 0x0e1a30, sh = 0x1a2e52, base = 0x2e4a7a, hi = 0x5a7ab0, bone = 0xc0d0e8, eye = 0x9affd0, eyeDim = 0x5ac8a0, out = 0x060e1a },
  { deep = 0x0e2a2e, sh = 0x1a4a4e, base = 0x2e7a7e, hi = 0x5ab0b0, bone = 0xc0e8e0, eye = 0xaef0ff, eyeDim = 0x6ac0e0, out = 0x061416 },
  { deep = 0x1a0e30, sh = 0x2e1a52, base = 0x4a2e7a, hi = 0x7a5ab0, bone = 0xd0c0e8, eye = 0xff6ad0, eyeDim = 0xc83aa0, out = 0x0c061a },
  { deep = 0x14161e, sh = 0x242a36, base = 0x3a4452, hi = 0x5a6a7a, bone = 0xa0b0c0, eye = 0x7affd0, eyeDim = 0x3ac8a0, out = 0x080a10 },
}
local CRYSTAL = {
  { deep = 0x162a4a, sh = 0x26467a, base = 0x3a6ab0, hi = 0x7a9ae0, bone = 0xc0d8ff, eye = 0xaef0ff, eyeDim = 0x6ac0e0, out = 0x0a1428 },
  { deep = 0x2a1a4a, sh = 0x46307a, base = 0x724ab0, hi = 0xa87ae0, bone = 0xd8c0ff, eye = 0xe0aeff, eyeDim = 0xb06ae0, out = 0x160c28 },
  { deep = 0x0e3a2a, sh = 0x1a6248, base = 0x2e9a6e, hi = 0x6ad0a0, bone = 0xc0ffe0, eye = 0xaeffd0, eyeDim = 0x6ae0b0, out = 0x061c14 },
  { deep = 0x3a2a0e, sh = 0x624a1a, base = 0x9a7a2e, hi = 0xd0a85a, bone = 0xffe0a0, eye = 0xffce5a, eyeDim = 0xc8983a, out = 0x1c1408 },
}
local WINGED = {
  { deep = 0x241810, sh = 0x3e2c1c, base = 0x5e4632, hi = 0x86684a, bone = 0xc0a888, eye = 0xffae5a, eyeDim = 0xc8804a, out = 0x120a06 },
  { deep = 0x1e1e24, sh = 0x34343c, base = 0x52525c, hi = 0x76767e, bone = 0xb0aca0, eye = 0xe8c24a, eyeDim = 0xa8843a, out = 0x0e0e12 },
  { deep = 0x14141a, sh = 0x24242c, base = 0x3a3a44, hi = 0x5a5a64, bone = 0x9a9aa0, eye = 0xc08aff, eyeDim = 0x7a4ac8, out = 0x08080c },
  { deep = 0x2a2620, sh = 0x464034, base = 0x6e6450, hi = 0x988c70, bone = 0xe0d4b0, eye = 0x9aff7a, eyeDim = 0x5ac83a, out = 0x141008 },
}
local COLOSSUS = {
  { deep = 0x1e2a18, sh = 0x34462a, base = 0x52703e, hi = 0x7a9c5a, bone = 0xd0c8a0, eye = 0xe8c24a, eyeDim = 0xa8843a, out = 0x0e1408 },
  { deep = 0x222024, sh = 0x3a363e, base = 0x585260, hi = 0x7e7686, bone = 0xc0b8c0, eye = 0xffae5a, eyeDim = 0xc8804a, out = 0x101016 },
  { deep = 0x2e1a1a, sh = 0x4e2e2e, base = 0x7a4a4a, hi = 0xa87070, bone = 0xe0c0b0, eye = 0xffce5a, eyeDim = 0xc8983a, out = 0x160a0a },
  { deep = 0x2a2620, sh = 0x46403a, base = 0x70645a, hi = 0x9c8c7e, bone = 0xe0d0c0, eye = 0xaef0ff, eyeDim = 0x6ac0e0, out = 0x141008 },
}
-- archetypes : GOLEM RUNIQUE (blocs géométriques, runes lumineuses)
function ARCH.aGolem(g, rnd, p)
  rect(g, 26, 44, 5, 12, p.base); rect(g, 34, 44, 5, 12, p.base)
  rect(g, 26, 44, 2, 12, p.sh); rect(g, 34, 44, 2, 12, p.sh)
  rect(g, 25, 55, 7, 2, p.deep); rect(g, 33, 55, 7, 2, p.deep)
  rect(g, 23, 24, 18, 21, p.base); rect(g, 23, 24, 5, 21, p.sh); rect(g, 23, 24, 18, 2, p.hi)
  rect(g, 20, 24, 5, 8, p.base); rect(g, 40, 24, 5, 8, p.base)
  rect(g, 18, 30, 5, 16, p.base); rect(g, 42, 30, 5, 16, p.base)
  rect(g, 18, 30, 2, 16, p.sh); rect(g, 42, 30, 2, 16, p.sh)
  rect(g, 17, 44, 7, 4, p.deep); rect(g, 41, 44, 7, 4, p.deep)
  rect(g, 28, 14, 9, 10, p.base); rect(g, 28, 14, 3, 10, p.sh); rect(g, 28, 14, 9, 2, p.hi)
  rect(g, 30, 18, 5, 2, p.eye); set(g, 29, 18, p.eyeDim); set(g, 35, 18, p.eyeDim)
  line(g, 32, 28, 32, 38, p.eye); line(g, 28, 33, 36, 33, p.eye); disc(g, 32, 33, 1, p.eye)
  return { head = { x = 32, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 26 }, { 32, 34 }, { 32, 42 } },
    limbs = { { 20, 46 }, { 44, 46 }, { 28, 56 }, { 36, 56 } }, belly = { x = 32, y = 34 }, mass = { { 32, 34, 9 } }, tailBase = nil, flesh = false }
end
function ARCH.aSentinel(g, rnd, p)
  crystal(g, 32, 28, 9, 13, p, 0); eyeP(g, 32, 28, 2, p)
  local sh = { { 14, 22, 4 }, { 48, 24, 4 }, { 18, 40, 3 }, { 46, 38, 3 }, { 32, 10, 3 }, { 30, 46, 3 } }
  for i = 1, #sh do
    rect(g, sh[i][1], sh[i][2], sh[i][3], sh[i][3], p.base); rect(g, sh[i][1], sh[i][2], 1, sh[i][3], p.sh); set(g, sh[i][1], sh[i][2], p.hi)
  end
  return { head = { x = 32, y = 28, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 20 }, { 32, 36 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 28, 8 } }, tailBase = nil, flesh = false, float = true }
end
function ARCH.aIdol(g, rnd, p)
  rect(g, 22, 18, 20, 38, p.base); rect(g, 22, 18, 6, 38, p.sh); rect(g, 22, 18, 20, 2, p.hi)
  rect(g, 20, 52, 24, 4, p.deep); rect(g, 27, 24, 10, 12, p.deep)
  eyeP(g, 30, 29, 1, p); eyeP(g, 34, 29, 1, p); line(g, 29, 33, 35, 33, p.eyeDim)
  line(g, 24, 40, 40, 44, p.sh); line(g, 24, 44, 40, 40, p.sh)
  for y = 20, 51, 4 do set(g, 24, y, p.eye); set(g, 40, y, p.eye) end
  return { head = { x = 32, y = 29, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 22 }, { 32, 40 } },
    limbs = {}, belly = { x = 32, y = 44 }, mass = { { 32, 36, 10 } }, tailBase = nil, flesh = false }
end
-- archetypes : SPECTRE VOILÉ (vapeur verticale, bas dissous)
function ARCH.aWraith(g, rnd, p)
  ghostBody(g, 32, 16, 52, 9, p, rnd)
  ellipse(g, 32, 18, 5, 5, p.sh); eyeP(g, 30, 18, 1, p); eyeP(g, 34, 18, 1, p)
  tube(g, { { 26, 24 }, { 20, 30 }, { 18, 38 } }, 2, 1, p.base); tube(g, { { 38, 24 }, { 44, 30 }, { 46, 38 } }, 2, 1, p.base)
  return { head = { x = 32, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 22 }, { 32, 36 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 28, 8 } }, tailBase = nil, flesh = false, float = true }
end
function ARCH.aVeiledLady(g, rnd, p)
  ghostBody(g, 32, 12, 54, 8, p, rnd)
  polygon(g, { { 26, 14 }, { 38, 14 }, { 40, 30 }, { 24, 30 } }, p.hi)
  ellipse(g, 32, 16, 4, 5, p.sh); eyeP(g, 30, 17, 1, p); eyeP(g, 34, 17, 1, p)
  return { head = { x = 32, y = 16, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 20 }, { 32, 40 } },
    limbs = {}, belly = { x = 32, y = 36 }, mass = { { 32, 28, 8 } }, tailBase = nil, flesh = false, float = true }
end
-- archetypes : CULTE et HÉRAUT (robe drapée triangulaire, capuche vide)
function ARCH.aCultist(g, rnd, p)
  polygon(g, { { 26, 22 }, { 38, 22 }, { 44, 54 }, { 20, 54 } }, p.base)
  polygon(g, { { 26, 22 }, { 32, 22 }, { 30, 54 }, { 20, 54 } }, p.sh)
  line(g, 32, 24, 32, 52, p.deep); rect(g, 20, 53, 24, 2, p.deep)
  polygon(g, { { 27, 12 }, { 37, 12 }, { 39, 24 }, { 25, 24 } }, p.base)
  ellipse(g, 32, 18, 5, 6, p.deep); eyeP(g, 30, 18, 1, p); eyeP(g, 34, 18, 1, p)
  tube(g, { { 26, 28 }, { 22, 38 }, { 24, 44 } }, 3, 2, p.sh); tube(g, { { 38, 28 }, { 42, 38 }, { 40, 44 } }, 3, 2, p.sh)
  disc(g, 24, 44, 2, p.hi); disc(g, 40, 44, 2, p.hi)
  return { head = { x = 32, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 24 }, { 32, 38 }, { 32, 50 } },
    limbs = { { 24, 44 }, { 40, 44 } }, belly = { x = 32, y = 36 }, mass = { { 32, 36, 9 } }, tailBase = nil, flesh = true }
end
function ARCH.aHierophant(g, rnd, p)
  polygon(g, { { 24, 20 }, { 40, 20 }, { 46, 55 }, { 18, 55 } }, p.base)
  polygon(g, { { 24, 20 }, { 32, 20 }, { 30, 55 }, { 18, 55 } }, p.sh)
  rect(g, 18, 54, 28, 2, p.deep)
  tube(g, { { 26, 24 }, { 18, 18 }, { 14, 12 } }, 3, 2, p.sh); tube(g, { { 38, 24 }, { 46, 18 }, { 50, 12 } }, 3, 2, p.sh)
  disc(g, 14, 12, 2, p.hi); disc(g, 50, 12, 2, p.hi)
  polygon(g, { { 27, 14 }, { 37, 14 }, { 35, 4 }, { 29, 4 } }, p.base)
  tube(g, { { 29, 8 }, { 26, 3 } }, 1, 1, p.bone); tube(g, { { 35, 8 }, { 38, 3 } }, 1, 1, p.bone)
  ellipse(g, 32, 17, 4, 5, p.hi); eyeP(g, 30, 17, 1, p); eyeP(g, 34, 17, 1, p); line(g, 31, 20, 33, 20, p.deep)
  return { head = { x = 32, y = 17, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 22 }, { 32, 40 } },
    limbs = { { 14, 12 }, { 50, 12 } }, belly = { x = 32, y = 38 }, mass = { { 32, 38, 10 } }, tailBase = nil, flesh = true }
end
function ARCH.aPossessed(g, rnd, p)
  polygon(g, { { 26, 24 }, { 38, 24 }, { 43, 54 }, { 21, 54 } }, p.base)
  polygon(g, { { 26, 24 }, { 32, 24 }, { 30, 54 }, { 21, 54 } }, p.sh)
  rect(g, 21, 53, 22, 2, p.deep)
  ellipse(g, 33, 18, 5, 5, p.deep); eyeP(g, 31, 18, 1, p); eyeP(g, 35, 17, 2, p)
  tentacle(g, 30, 32, 16, 0.6, 4, 3, 1, p.sh); eyeP(g, 30, 34, 1, p)
  tube(g, { { 27, 30 }, { 23, 42 }, { 24, 48 } }, 2, 2, p.sh); tube(g, { { 38, 30 }, { 42, 42 }, { 41, 48 } }, 2, 2, p.sh)
  return { head = { x = 33, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 26 }, { 32, 40 }, { 32, 50 } },
    limbs = { { 24, 48 }, { 41, 48 } }, belly = { x = 32, y = 38 }, mass = { { 32, 36, 9 } }, tailBase = nil, flesh = true }
end
-- archetypes : PROFOND ABYSSAL (fuselé, mâchoire, leurre)
function ARCH.aAnglerfish(g, rnd, p)
  mass(g, 34, 36, 15, 11, p)
  polygon(g, { { 20, 30 }, { 10, 26 }, { 14, 36 }, { 10, 46 }, { 20, 42 } }, p.sh)
  polygon(g, { { 34, 25 }, { 30, 18 }, { 40, 22 } }, p.sh)
  polygon(g, { { 34, 47 }, { 30, 54 }, { 40, 50 } }, p.sh)
  polygon(g, { { 44, 30 }, { 58, 28 }, { 58, 44 }, { 44, 42 } }, p.deep)
  for i = 0, 6 do
    local tx = 45 + i * 2
    polygon(g, { { tx, 30 }, { tx + 1, 30 }, { tx + 0.5, 33 } }, p.bone)
    polygon(g, { { tx, 42 }, { tx + 1, 42 }, { tx + 0.5, 39 } }, p.bone)
  end
  eyeP(g, 42, 32, 2, p)
  tube(g, { { 40, 26 }, { 44, 18 }, { 50, 16 } }, 1, 1, p.base); disc(g, 51, 16, 2, p.eye); disc(g, 51, 16, 1, p.bone)
  return { head = { x = 46, y = 34, r = 7 }, faceDir = { 1, 0 }, spine = { { 44, 32 }, { 34, 34 }, { 22, 34 } },
    limbs = {}, belly = { x = 34, y = 42 }, mass = { { 34, 36, 14 } }, tailBase = { x = 16, y = 36 }, flesh = true }
end
function ARCH.aDeepOne(g, rnd, p)
  tube(g, { { 28, 42 }, { 26, 55 } }, 3, 2, p.sh); tube(g, { { 37, 42 }, { 39, 55 } }, 3, 2, p.sh)
  polygon(g, { { 24, 55 }, { 28, 55 }, { 26, 58 } }, p.sh); polygon(g, { { 37, 55 }, { 41, 55 }, { 39, 58 } }, p.sh)
  mass(g, 32, 34, 8, 11, p)
  for _ = 1, 6 do local sp = onMass(rnd, { 32, 34, 7 }); set(g, sp[1], sp[2], p.hi) end
  tube(g, { { 27, 28 }, { 22, 38 }, { 22, 46 } }, 2, 2, p.sh); tube(g, { { 37, 28 }, { 42, 38 }, { 42, 46 } }, 2, 2, p.sh)
  polygon(g, { { 22, 38 }, { 18, 40 }, { 22, 44 } }, p.sh); polygon(g, { { 42, 38 }, { 46, 40 }, { 42, 44 } }, p.sh)
  mass(g, 32, 22, 6, 5, p)
  polygon(g, { { 36, 22 }, { 42, 20 }, { 40, 25 } }, p.base)
  eyeP(g, 29, 21, 2, p); eyeP(g, 35, 21, 2, p); line(g, 28, 25, 30, 25, p.deep); line(g, 28, 27, 30, 27, p.deep)
  polygon(g, { { 30, 16 }, { 34, 16 }, { 32, 10 } }, p.sh)
  return { head = { x = 32, y = 22, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 26 }, { 32, 34 }, { 32, 42 } },
    limbs = { { 22, 46 }, { 42, 46 }, { 26, 55 }, { 39, 55 } }, belly = { x = 32, y = 38 }, mass = { { 32, 34, 8 } }, tailBase = nil, flesh = true }
end
function ARCH.aMoray(g, rnd, p)
  tube(g, { { 20, 56 }, { 18, 48 }, { 26, 42 }, { 34, 36 }, { 36, 28 } }, 5, 3, p.base)
  polygon(g, { { 34, 22 }, { 44, 20 }, { 44, 30 }, { 34, 30 } }, p.deep)
  for i = 0, 5 do local tx = 35 + i * 1.5; set(g, round(tx), 22, p.bone); set(g, round(tx), 29, p.bone) end
  eyeP(g, 34, 24, 1, p)
  polygon(g, { { 28, 40 }, { 26, 36 }, { 30, 38 } }, p.sh); polygon(g, { { 33, 34 }, { 31, 30 }, { 35, 32 } }, p.sh)
  return { head = { x = 38, y = 25, r = 5 }, faceDir = { 1, -0.3 }, spine = { { 36, 30 }, { 26, 42 }, { 20, 52 } },
    limbs = {}, belly = { x = 28, y = 44 }, mass = { { 30, 40, 8 }, { 36, 28, 5 } }, tailBase = { x = 20, y = 56 }, flesh = true }
end
-- archetypes : ENGEANCE CRISTALLINE (facettes minérales anguleuses)
function ARCH.aCrystalCluster(g, rnd, p)
  mass(g, 32, 48, 14, 6, p)
  crystal(g, 30, 34, 5, 14, p, -2); crystal(g, 38, 32, 4, 16, p, 1); crystal(g, 24, 38, 4, 11, p, -1)
  crystal(g, 44, 40, 3, 9, p, 2); crystal(g, 32, 30, 6, 18, p, 0)
  set(g, 32, 38, p.eye); set(g, 38, 38, p.eye); set(g, 30, 40, p.eye)
  return { head = { x = 32, y = 34, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 32 }, { 32, 44 } },
    limbs = {}, belly = { x = 32, y = 44 }, mass = { { 32, 40, 11 } }, tailBase = nil, flesh = false }
end
function ARCH.aShardWalker(g, rnd, p)
  crystal(g, 28, 48, 3, 9, p, 0); crystal(g, 36, 48, 3, 9, p, 0); crystal(g, 32, 32, 7, 12, p, 0)
  crystal(g, 22, 34, 3, 9, p, -2); crystal(g, 42, 34, 3, 9, p, 2); crystal(g, 32, 18, 4, 7, p, 0)
  eyeP(g, 32, 32, 2, p); set(g, 32, 20, p.eye)
  return { head = { x = 32, y = 19, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 26 }, { 32, 32 }, { 32, 40 } },
    limbs = { { 22, 42 }, { 42, 42 }, { 28, 56 }, { 36, 56 } }, belly = { x = 32, y = 34 }, mass = { { 32, 32, 7 } }, tailBase = nil, flesh = false }
end
function ARCH.aPrism(g, rnd, p)
  crystal(g, 32, 28, 10, 15, p, 0); eyeP(g, 32, 28, 3, p)
  local sh = { { 16, 24, 3 }, { 46, 26, 3 }, { 20, 40, 2 }, { 44, 38, 2 } }
  for i = 1, #sh do crystal(g, sh[i][1], sh[i][2], sh[i][3], sh[i][3] * 2, p, 0) end
  return { head = { x = 32, y = 28, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 20 }, { 32, 36 } },
    limbs = {}, belly = { x = 32, y = 34 }, mass = { { 32, 28, 9 } }, tailBase = nil, flesh = false, float = true }
end
-- archetypes : BYAKHEE AILÉ (grande envergure, serres)
function ARCH.aByakhee(g, rnd, p)
  bigWing(g, 27, 30, -1, 18, p); bigWing(g, 37, 30, 1, 18, p)
  mass(g, 32, 34, 5, 7, p)
  tube(g, { { 29, 40 }, { 27, 50 } }, 1, 1, p.sh); tube(g, { { 35, 40 }, { 37, 50 } }, 1, 1, p.sh)
  mass(g, 32, 26, 4, 4, p); tube(g, { { 32, 28 }, { 33, 33 } }, 1, 1, p.base)
  line(g, 30, 23, 28, 18, p.sh); line(g, 34, 23, 36, 18, p.sh)
  eyeP(g, 30, 26, 1, p); eyeP(g, 34, 26, 1, p); eyeP(g, 32, 24, 1, p)
  return { head = { x = 32, y = 26, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 38 } },
    limbs = { { 27, 50 }, { 37, 50 } }, belly = { x = 32, y = 36 }, mass = { { 32, 34, 6 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aHarpy(g, rnd, p)
  featherWing(g, 28, 28, -1, 16, p); featherWing(g, 36, 28, 1, 16, p)
  mass(g, 32, 32, 5, 8, p)
  tube(g, { { 30, 40 }, { 28, 49 }, { 27, 54 } }, 2, 1, p.sh); tube(g, { { 34, 40 }, { 36, 49 }, { 37, 54 } }, 2, 1, p.sh)
  polygon(g, { { 24, 54 }, { 28, 54 }, { 26, 57 } }, p.bone); polygon(g, { { 36, 54 }, { 40, 54 }, { 38, 57 } }, p.bone)
  for i = 0, 2 do
    polygon(g, { { 27, 52 + i * 2 }, { 24 - i, 54 + i * 2 }, { 27, 54 + i * 2 } }, p.bone)
    polygon(g, { { 37, 52 + i * 2 }, { 40 + i, 54 + i * 2 }, { 37, 54 + i * 2 } }, p.bone)
  end
  mass(g, 32, 23, 4, 4, p); ellipse(g, 32, 24, 3, 4, p.hi); set(g, 30, 23, p.deep); set(g, 34, 23, p.deep)
  polygon(g, { { 32, 25 }, { 31, 28 }, { 33, 28 } }, p.bone)
  for i = 0, 3 do line(g, 30 + i, 19, 28 + i, 14, p.sh) end
  return { head = { x = 32, y = 23, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 38 } },
    limbs = { { 27, 54 }, { 37, 54 } }, belly = { x = 32, y = 34 }, mass = { { 32, 32, 6 } }, tailBase = nil, flesh = true, float = true }
end
-- archetypes : COLOSSE DIFFORME (pyramide top-heavy, brute)
function ARCH.aOgre(g, rnd, p)
  tube(g, { { 27, 46 }, { 26, 56 } }, 4, 3, p.sh); tube(g, { { 37, 46 }, { 38, 56 } }, 4, 3, p.sh)
  disc(g, 26, 56, 3, p.deep); disc(g, 38, 56, 3, p.deep)
  mass(g, 32, 32, 15, 12, p); mass(g, 20, 26, 5, 4, p); mass(g, 44, 26, 5, 4, p)
  tube(g, { { 20, 28 }, { 16, 40 }, { 18, 52 } }, 4, 3, p.sh); tube(g, { { 44, 28 }, { 48, 40 }, { 46, 52 } }, 4, 3, p.sh)
  disc(g, 18, 53, 3, p.deep); disc(g, 46, 53, 3, p.deep)
  mass(g, 32, 24, 4, 3, p); eyeP(g, 30, 24, 1, p); eyeP(g, 34, 24, 1, p); maw(g, 32, 27, 2, p)
  return { head = { x = 32, y = 24, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 36 }, { 32, 44 } },
    limbs = { { 18, 52 }, { 46, 52 }, { 26, 56 }, { 38, 56 } }, belly = { x = 32, y = 38 }, mass = { { 32, 32, 14 } }, tailBase = nil, flesh = true }
end
function ARCH.aCyclops(g, rnd, p)
  tube(g, { { 27, 46 }, { 26, 56 } }, 4, 3, p.sh); tube(g, { { 37, 46 }, { 38, 56 } }, 4, 3, p.sh)
  disc(g, 26, 56, 3, p.deep); disc(g, 38, 56, 3, p.deep)
  mass(g, 32, 33, 14, 12, p)
  tube(g, { { 44, 26 }, { 50, 38 }, { 48, 50 } }, 5, 3, p.sh); disc(g, 48, 51, 4, p.deep)
  tube(g, { { 20, 28 }, { 17, 40 }, { 19, 50 } }, 3, 2, p.sh); disc(g, 19, 51, 2, p.deep)
  mass(g, 32, 22, 5, 4, p); eyeP(g, 32, 22, 3, p)
  polygon(g, { { 30, 25 }, { 31, 25 }, { 30, 28 } }, p.bone); polygon(g, { { 34, 25 }, { 33, 25 }, { 34, 28 } }, p.bone)
  return { head = { x = 32, y = 22, r = 5 }, faceDir = { 0, -1 }, spine = { { 32, 28 }, { 32, 36 }, { 32, 44 } },
    limbs = { { 48, 50 }, { 19, 50 }, { 26, 56 }, { 38, 56 } }, belly = { x = 32, y = 38 }, mass = { { 32, 33, 13 } }, tailBase = nil, flesh = true }
end
-- traitements V2
function TREAT.treatGolem(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, m); rstreak(g, pt[1], pt[2], 3, p.deep, rnd) end
  for _ = 1, 2 + floor(rnd() * 2) do local r = onMass(rnd, m); set(g, r[1], r[2], p.eye) end
  if rnd() < 0.5 then local c = onMass(rnd, m); for k = 0, 2 do set(g, c[1] + k, c[2], nil) end end
end
function TREAT.treatSpectre(g, rnd, p, A)
  local b = A.belly
  for _ = 1, 2 + floor(rnd() * 2) do
    tube(g, { { b.x + round((rnd() - 0.5) * 12), b.y }, { b.x + round((rnd() - 0.5) * 16), b.y + 6 + floor(rnd() * 5) } }, 1, 1, p.base)
  end
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, A.mass[1]); set(g, pt[1], pt[2], nil) end
  if rnd() < 0.4 then local e = onMass(rnd, A.mass[1]); eyeP(g, e[1], e[2], 1, p) end
end
function TREAT.treatCult(g, rnd, p, A)
  local h = A.head
  if rnd() < 0.4 then eyeP(g, h.x - 2, h.y, 1, p); eyeP(g, h.x + 2, h.y, 1, p) end
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, A.mass[1]); set(g, pt[1], pt[2], p.eye) end
  if rnd() < 0.35 then tentacle(g, h.x, h.y + 4, 12, (rnd() - 0.5), 3, 2, 1, p.sh) end
  if #A.limbs > 0 and rnd() < 0.5 then
    local l = A.limbs[1 + floor(rnd() * #A.limbs)]
    for k = 0, 2 do set(g, l[1] + round((rnd() - 0.5) * 3), l[2] + 1 + k, p.deep) end
  end
end
function TREAT.treatAbyssal(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.eye) end
  line(g, m[1] - m[3] + 2, m[2] - round(m[3] * 0.5), m[1] + m[3] - 2, m[2] - round(m[3] * 0.5), p.hi)
  if rnd() < 0.5 then local f = onMass(rnd, m); polygon(g, { { f[1], f[2] }, { f[1] - 3, f[2] - 4 }, { f[1] + 1, f[2] - 2 } }, p.sh) end
end
function TREAT.treatCrystalline(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 2 + floor(rnd() * 2) do local pt = onMass(rnd, m); crystal(g, pt[1], pt[2], 2, 4, p, round((rnd() - 0.5) * 2)) end
  for _ = 1, 3 do local s = onMass(rnd, m); set(g, s[1], s[2], p.eye) end
end
function TREAT.treatWinged(g, rnd, p, A)
  for _ = 1, 3 + floor(rnd() * 3) do
    local x = round(A.head.x + (rnd() - 0.5) * 40); local y = round(A.head.y + (rnd() * 16 - 4))
    set(g, x, y, nil)
  end
  for _ = 1, 3 do local pt = onMass(rnd, A.mass[1]); rstreak(g, pt[1], pt[2], 2, p.sh, rnd) end
end
function TREAT.treatColossus(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 3 + floor(rnd() * 4) do local pt = onMass(rnd, m); disc(g, pt[1], pt[2], 1, p.sh) end
  if rnd() < 0.5 then local w = A.belly; disc(g, w.x + round((rnd() - 0.5) * 8), w.y, 2, p.deep) end
  if rnd() < 0.4 then local pt2 = onMass(rnd, m); growth(g, pt2[1], pt2[2], p, rnd) end
end

-- ═══════════════════════════ V4 lumière/Inquisition + V5 gredins/bêtes classiques ═══════════════════════
local LUMEN = {
  { deep = 0x6e5318, sh = 0x9a7d2e, base = 0xd8b54e, hi = 0xf3e4a0, bone = 0xf7f1dd, eye = 0xfff1b0, eyeDim = 0x7a2a20, out = 0x241c0e },
  { deep = 0x5b5640, sh = 0x8a8460, base = 0xcfc8a0, hi = 0xf0ecd6, bone = 0xfbf8ec, eye = 0xffe9a8, eyeDim = 0x6e2a22, out = 0x201d12 },
  { deep = 0x4a4a2c, sh = 0x73734a, base = 0xa8a772, hi = 0xd8d6a8, bone = 0xe8e6c8, eye = 0xe6d48a, eyeDim = 0x5e241c, out = 0x1c1c10 },
}
local INQUIS = {
  { deep = 0x5a4a2a, sh = 0x857043, base = 0xc2ad6a, hi = 0xecdca0, bone = 0xf4eed8, eye = 0xffe6a0, eyeDim = 0x6e241c, out = 0x1e1a0e },
  { deep = 0x3c3c3a, sh = 0x5e5e58, base = 0x9a988c, hi = 0xcfccbc, bone = 0xe8e4d2, eye = 0xf2d68a, eyeDim = 0x6a221a, out = 0x161614 },
  { deep = 0x4a2820, sh = 0x7a4030, base = 0xb06a4a, hi = 0xe0b48a, bone = 0xf0e4d0, eye = 0xffd98a, eyeDim = 0x7e2418, out = 0x1c0e0a },
}
local SERAPH = {
  { deep = 0x6a5a2a, sh = 0x9a8440, base = 0xdcc468, hi = 0xfaecb0, bone = 0xfdf8e6, eye = 0xfff4c0, eyeDim = 0x7a281e, out = 0x15110a },
  { deep = 0x445268, sh = 0x6a7c98, base = 0xa8bcd8, hi = 0xe0ecf8, bone = 0xf4f8ff, eye = 0xfff0c0, eyeDim = 0x742820, out = 0x12161e },
  { deep = 0x5c4418, sh = 0x8a6a28, base = 0xc69a40, hi = 0xeccf88, bone = 0xf6ead0, eye = 0xffe8a0, eyeDim = 0x7c2618, out = 0x1a1208 },
}
local GRYPHON = {
  { deep = 0x5a3e1e, sh = 0x8a6432, base = 0xc08a44, hi = 0xe6c084, bone = 0xf2ead4, eye = 0xffd86a, eyeDim = 0x742a1c, out = 0x1c120a },
  { deep = 0x56503c, sh = 0x82795c, base = 0xb8ac84, hi = 0xe6dcb8, bone = 0xfaf4e2, eye = 0xffcf5a, eyeDim = 0x6e281a, out = 0x1a160e },
  { deep = 0x44423c, sh = 0x6a675c, base = 0x9a9684, hi = 0xccc7ac, bone = 0xe8e2cc, eye = 0xecc25a, eyeDim = 0x682418, out = 0x161410 },
}
local BANDIT = {
  { deep = 0x3a2a1c, sh = 0x5e442c, base = 0x8a6a44, hi = 0xb89366, bone = 0xcdbb9a, eye = 0xcfc3a0, eyeDim = 0x6e2a1e, out = 0x1e160e },
  { deep = 0x33312a, sh = 0x544f44, base = 0x7d7763, hi = 0xa59d84, bone = 0xc2bca6, eye = 0xc8c2ac, eyeDim = 0x6a281c, out = 0x1a1812 },
  { deep = 0x2e3424, sh = 0x4c5638, base = 0x74805a, hi = 0x9da883, bone = 0xc4c2a4, eye = 0xcabfa0, eyeDim = 0x6c2a1c, out = 0x181a12 },
  { deep = 0x2c241e, sh = 0x473a30, base = 0x6e5a48, hi = 0x94795f, bone = 0xbca890, eye = 0xc4b89a, eyeDim = 0x702a1c, out = 0x161208 },
}
local CANID = {
  { deep = 0x2e3236, sh = 0x4a4f55, base = 0x71777e, hi = 0x9aa0a6, bone = 0xd8d2c2, eye = 0xd8b24a, eyeDim = 0x7a2a1c, out = 0x15171a },
  { deep = 0x382a1e, sh = 0x574030, base = 0x825f44, hi = 0xad8460, bone = 0xd4c4a6, eye = 0xcaa83e, eyeDim = 0x742818, out = 0x181208 },
  { deep = 0x2a2620, sh = 0x443d33, base = 0x6e6150, hi = 0x998a72, bone = 0xcabf9e, eye = 0xd4ad44, eyeDim = 0x702616, out = 0x141008 },
}
local REPTILE = {
  { deep = 0x1e3220, sh = 0x345236, base = 0x537a52, hi = 0x82a878, bone = 0xd6cf9a, eye = 0xe0c244, eyeDim = 0x7a2a18, out = 0x0e1a0e },
  { deep = 0x2c3018, sh = 0x4a5028, base = 0x737a3e, hi = 0xa0a868, bone = 0xd2cc98, eye = 0xdcc23e, eyeDim = 0x742818, out = 0x121408 },
  { deep = 0x2c2824, sh = 0x48433a, base = 0x736a58, hi = 0x9c9078, bone = 0xcdc4a0, eye = 0xd8b84a, eyeDim = 0x762616, out = 0x141210 },
}
local RODENT = {
  { deep = 0x332620, sh = 0x523e30, base = 0x7a5d46, hi = 0xa3805e, bone = 0xcdbf9c, eye = 0xcaa03e, eyeDim = 0x9a5848, out = 0x161008 },
  { deep = 0x2e2c28, sh = 0x4c4840, base = 0x736d60, hi = 0x9c9582, bone = 0xc8c0a4, eye = 0xc69a3c, eyeDim = 0x96564a, out = 0x141210 },
  { deep = 0x28281e, sh = 0x444330, base = 0x6a684a, hi = 0x928f68, bone = 0xc4c098, eye = 0xbe9636, eyeDim = 0x925040, out = 0x121208 },
}
function ARCH.aCrusader(g, rnd, p)
  tube(g, { { 29, 42 }, { 28, 55 } }, 3, 2, p.sh); tube(g, { { 36, 42 }, { 37, 55 } }, 3, 2, p.sh)
  rect(g, 26, 54, 5, 3, p.deep); rect(g, 35, 54, 5, 3, p.deep)
  mass(g, 33, 34, 7, 11, p)
  rect(g, 30, 28, 8, 15, p.base); rect(g, 30, 28, 8, 2, p.hi)
  line(g, 34, 30, 34, 42, p.bone); line(g, 31, 35, 37, 35, p.bone)
  tube(g, { { 39, 30 }, { 44, 24 }, { 47, 17 } }, 2, 2, p.sh)
  polygon(g, { { 47, 17 }, { 45, 4 }, { 49, 5 } }, p.bone); line(g, 47, 17, 47, 6, p.hi)
  mass(g, 33, 22, 5, 5, p); rect(g, 29, 20, 9, 3, p.sh)
  eyeP(g, 31, 22, 1, p); eyeP(g, 35, 22, 1, p); set(g, 33, 24, p.deep)
  disc(g, 21, 38, 7, p.base); disc(g, 21, 38, 7, p.deep); disc(g, 21, 38, 5, p.sh); disc(g, 21, 38, 2, p.hi)
  line(g, 21, 33, 21, 43, p.bone); line(g, 16, 38, 26, 38, p.bone); tube(g, { { 30, 30 }, { 24, 34 } }, 2, 2, p.sh)
  return { head = { x = 33, y = 22, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 28 }, { 33, 38 } },
    limbs = { { 28, 55 }, { 37, 55 } }, belly = { x = 33, y = 36 }, mass = { { 33, 34, 8 } }, tailBase = nil, flesh = true }
end
function ARCH.aSentinelShield(g, rnd, p)
  tube(g, { { 31, 44 }, { 30, 56 } }, 3, 2, p.sh); tube(g, { { 37, 44 }, { 38, 56 } }, 3, 2, p.sh)
  rect(g, 28, 55, 5, 2, p.deep); rect(g, 36, 55, 5, 2, p.deep)
  mass(g, 34, 36, 7, 10, p)
  rect(g, 31, 30, 8, 14, p.base); rect(g, 31, 30, 8, 2, p.hi)
  mass(g, 34, 24, 5, 5, p); rect(g, 31, 22, 7, 3, p.sh)
  set(g, 33, 24, p.deep); set(g, 36, 24, p.deep); line(g, 34, 20, 34, 15, p.bone)
  tube(g, { { 41, 32 }, { 46, 30 }, { 48, 26 } }, 2, 1, p.sh); disc(g, 49, 24, 2, p.base)
  rect(g, 18, 28, 9, 28, p.base); rect(g, 18, 28, 9, 2, p.hi); rect(g, 18, 28, 2, 28, p.sh)
  line(g, 22, 30, 22, 54, p.bone); line(g, 20, 40, 26, 40, p.bone); disc(g, 22, 40, 2, p.hi)
  return { head = { x = 34, y = 24, r = 5 }, faceDir = { 0, -1 }, spine = { { 34, 30 }, { 34, 40 } },
    limbs = { { 30, 56 }, { 38, 56 } }, belly = { x = 34, y = 38 }, mass = { { 34, 36, 8 } }, tailBase = nil, flesh = true }
end
function ARCH.aPaladin(g, rnd, p)
  polygon(g, { { 26, 26 }, { 40, 26 }, { 44, 55 }, { 22, 55 } }, p.sh)
  tube(g, { { 29, 42 }, { 28, 55 } }, 3, 2, p.base); tube(g, { { 37, 42 }, { 38, 55 } }, 3, 2, p.base)
  rect(g, 26, 54, 5, 3, p.deep); rect(g, 35, 54, 5, 3, p.deep)
  mass(g, 33, 33, 7, 11, p)
  rect(g, 30, 27, 8, 15, p.base); rect(g, 30, 27, 8, 2, p.hi)
  mass(g, 33, 20, 5, 5, p); eyeP(g, 31, 20, 1, p); eyeP(g, 35, 20, 1, p); rect(g, 29, 18, 9, 2, p.sh)
  halo(g, 33, 11, 7, p)
  rect(g, 32, 24, 3, 24, p.bone); rect(g, 32, 24, 1, 24, p.hi)
  rect(g, 28, 30, 11, 2, p.base); rect(g, 28, 30, 11, 1, p.hi)
  polygon(g, { { 32, 48 }, { 35, 48 }, { 33, 53 } }, p.bone)
  tube(g, { { 30, 32 }, { 33, 30 } }, 1, 1, p.sh); tube(g, { { 36, 32 }, { 33, 30 } }, 1, 1, p.sh)
  return { head = { x = 33, y = 20, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 38 } },
    limbs = { { 28, 55 }, { 38, 55 } }, belly = { x = 33, y = 36 }, mass = { { 33, 33, 8 } }, tailBase = nil, flesh = true, halo = true }
end
function ARCH.aInquisitor(g, rnd, p)
  polygon(g, { { 26, 24 }, { 40, 24 }, { 44, 54 }, { 22, 54 } }, p.base)
  polygon(g, { { 26, 24 }, { 33, 24 }, { 31, 54 }, { 22, 54 } }, p.sh)
  rect(g, 22, 53, 22, 2, p.deep); line(g, 33, 26, 33, 52, p.bone)
  tube(g, { { 28, 28 }, { 24, 40 }, { 26, 46 } }, 3, 2, p.sh); tube(g, { { 38, 28 }, { 42, 38 }, { 41, 44 } }, 3, 2, p.sh)
  rect(g, 38, 40, 6, 7, p.bone); line(g, 41, 40, 41, 47, p.deep)
  mass(g, 33, 20, 5, 5, p); polygon(g, { { 29, 18 }, { 37, 18 }, { 33, 6 } }, p.base)
  line(g, 33, 16, 33, 8, p.bone); eyeP(g, 31, 20, 1, p); eyeP(g, 35, 20, 1, p); halo(g, 33, 12, 6, p)
  return { head = { x = 33, y = 20, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 24 }, { 33, 40 } },
    limbs = { { 26, 46 }, { 41, 44 } }, belly = { x = 33, y = 38 }, mass = { { 33, 34, 9 } }, tailBase = nil, flesh = true, halo = true }
end
function ARCH.aZealot(g, rnd, p)
  tube(g, { { 29, 40 }, { 28, 55 } }, 3, 2, p.base); tube(g, { { 36, 40 }, { 37, 55 } }, 3, 2, p.base)
  polygon(g, { { 28, 40 }, { 37, 40 }, { 39, 54 }, { 26, 54 } }, p.sh)
  mass(g, 33, 32, 7, 10, p)
  for i = 0, 3 do line(g, 29, 28 + i * 3, 37, 28 + i * 3, p.deep) end
  tube(g, { { 28, 28 }, { 22, 32 }, { 20, 40 } }, 2, 1, p.sh); tube(g, { { 38, 28 }, { 44, 24 }, { 48, 28 } }, 2, 1, p.sh)
  tube(g, { { 48, 28 }, { 50, 38 }, { 47, 44 } }, 1, 1, p.eyeDim)
  mass(g, 33, 22, 4, 5, p); rect(g, 30, 21, 7, 2, p.sh)
  eyeP(g, 31, 22, 1, p); eyeP(g, 35, 22, 1, p); set(g, 33, 18, p.eyeDim); set(g, 32, 17, p.eyeDim)
  return { head = { x = 33, y = 22, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 38 } },
    limbs = { { 20, 40 }, { 47, 44 } }, belly = { x = 33, y = 34 }, mass = { { 33, 32, 8 } }, tailBase = nil, flesh = true }
end
function ARCH.aConfessor(g, rnd, p)
  polygon(g, { { 25, 22 }, { 41, 22 }, { 45, 55 }, { 21, 55 } }, p.base)
  polygon(g, { { 25, 22 }, { 33, 22 }, { 31, 55 }, { 21, 55 } }, p.sh)
  rect(g, 21, 54, 24, 2, p.deep); line(g, 33, 24, 33, 53, p.bone)
  tube(g, { { 27, 26 }, { 20, 30 }, { 18, 38 } }, 3, 2, p.sh); tube(g, { { 39, 26 }, { 46, 22 }, { 50, 16 } }, 2, 2, p.sh)
  line(g, 50, 16, 50, 30, p.deep); disc(g, 50, 32, 3, p.base); disc(g, 50, 32, 1, p.eye)
  for i = 0, 2 do set(g, 50, 34 + i, p.eye) end
  mass(g, 33, 19, 5, 6, p); ellipse(g, 33, 20, 4, 5, p.hi)
  set(g, 31, 19, p.deep); set(g, 35, 19, p.deep); line(g, 31, 22, 35, 22, p.deep); halo(g, 33, 11, 6, p)
  return { head = { x = 33, y = 19, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 24 }, { 33, 40 } },
    limbs = { { 18, 38 }, { 50, 30 } }, belly = { x = 33, y = 38 }, mass = { { 33, 36, 9 } }, tailBase = nil, flesh = true, halo = true }
end
function ARCH.aSeraph(g, rnd, p)
  featherWing(g, 30, 26, -1, 16, p); featherWing(g, 36, 26, 1, 16, p)
  featherWing(g, 30, 34, -1, 12, p); featherWing(g, 36, 34, 1, 12, p)
  mass(g, 33, 34, 5, 11, p); rect(g, 31, 26, 5, 18, p.hi)
  mass(g, 33, 20, 4, 5, p); ellipse(g, 33, 20, 3, 4, p.hi)
  set(g, 31, 20, p.eye); set(g, 35, 20, p.eye); halo(g, 33, 12, 7, p)
  eyeP(g, 30, 30, 1, p); eyeP(g, 36, 32, 1, p); eyeP(g, 33, 38, 1, p)
  return { head = { x = 33, y = 20, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 40 } },
    limbs = {}, belly = { x = 33, y = 36 }, mass = { { 33, 34, 7 } }, tailBase = nil, flesh = true, float = true, halo = true }
end
function ARCH.aThrone(g, rnd, p)
  for a = 0, 23 do
    local an = a / 24 * 6.283
    set(g, round(33 + cos(an) * 12), round(30 + sin(an) * 12), p.base)
    set(g, round(33 + cos(an) * 9), round(30 + sin(an) * 9), p.hi)
  end
  for a = 0, 7 do
    local an2 = a / 8 * 6.283
    eyeP(g, round(33 + cos(an2) * 10.5), round(30 + sin(an2) * 10.5), 1, p)
  end
  featherWing(g, 24, 28, -1, 12, p); featherWing(g, 42, 28, 1, 12, p); eyeP(g, 33, 30, 3, p)
  return { head = { x = 33, y = 30, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 22 }, { 33, 38 } },
    limbs = {}, belly = { x = 33, y = 34 }, mass = { { 33, 30, 11 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aGryphon(g, rnd, p)
  mass(g, 30, 40, 13, 8, p)
  tube(g, { { 22, 44 }, { 20, 55 } }, 3, 2, p.sh); tube(g, { { 27, 44 }, { 26, 55 } }, 3, 2, p.sh)
  tube(g, { { 36, 44 }, { 37, 55 } }, 3, 2, p.sh); tube(g, { { 41, 44 }, { 42, 55 } }, 3, 2, p.sh)
  disc(g, 20, 55, 2, p.bone); disc(g, 26, 55, 2, p.bone); disc(g, 37, 55, 2, p.bone); disc(g, 42, 55, 2, p.bone)
  tube(g, { { 18, 38 }, { 12, 36 }, { 9, 40 }, { 12, 43 } }, 3, 1, p.sh)
  featherWing(g, 32, 34, 1, 16, p)
  tube(g, { { 40, 36 }, { 45, 30 }, { 48, 25 } }, 3, 2, p.sh)
  mass(g, 50, 23, 5, 4, p); polygon(g, { { 53, 23 }, { 59, 24 }, { 53, 27 } }, p.bone)
  line(g, 53, 25, 58, 25, p.deep); eyeP(g, 50, 22, 1, p); polygon(g, { { 47, 19 }, { 49, 19 }, { 48, 15 } }, p.hi)
  return { head = { x = 51, y = 23, r = 5 }, faceDir = { 1, -0.2 }, spine = { { 40, 34 }, { 30, 38 }, { 20, 40 } },
    limbs = { { 20, 55 }, { 26, 55 }, { 37, 55 }, { 42, 55 } }, belly = { x = 30, y = 46 }, mass = { { 30, 40, 12 }, { 50, 23, 4 } }, tailBase = { x = 18, y = 38 }, flesh = true }
end
function ARCH.aHippogriff(g, rnd, p)
  mass(g, 30, 41, 12, 7, p)
  tube(g, { { 23, 45 }, { 22, 55 } }, 2, 2, p.sh); tube(g, { { 28, 45 }, { 27, 55 } }, 2, 2, p.sh)
  tube(g, { { 37, 45 }, { 38, 55 } }, 2, 2, p.sh); tube(g, { { 41, 45 }, { 42, 55 } }, 2, 2, p.sh)
  disc(g, 22, 55, 2, p.bone); disc(g, 27, 55, 2, p.bone); disc(g, 38, 55, 2, p.bone); disc(g, 42, 55, 2, p.bone)
  tube(g, { { 19, 40 }, { 13, 42 }, { 10, 47 } }, 2, 1, p.sh)
  featherWing(g, 31, 36, 1, 14, p)
  tube(g, { { 39, 38 }, { 44, 31 }, { 47, 25 } }, 2, 2, p.sh)
  mass(g, 49, 23, 4, 4, p); polygon(g, { { 52, 23 }, { 58, 24 }, { 52, 26 } }, p.bone)
  eyeP(g, 49, 22, 1, p); polygon(g, { { 46, 19 }, { 48, 19 }, { 47, 15 } }, p.hi)
  return { head = { x = 50, y = 23, r = 4 }, faceDir = { 1, -0.2 }, spine = { { 39, 37 }, { 30, 40 }, { 20, 41 } },
    limbs = { { 22, 55 }, { 27, 55 }, { 38, 55 }, { 42, 55 } }, belly = { x = 30, y = 46 }, mass = { { 30, 41, 11 }, { 49, 23, 4 } }, tailBase = { x = 19, y = 40 }, flesh = true }
end
function ARCH.aCutthroat(g, rnd, p)
  tube(g, { { 29, 43 }, { 27, 55 } }, 3, 2, p.sh); tube(g, { { 36, 43 }, { 38, 55 } }, 3, 2, p.sh)
  rect(g, 25, 54, 5, 3, p.deep); rect(g, 36, 54, 5, 3, p.deep)
  mass(g, 33, 36, 7, 9, p)
  polygon(g, { { 27, 30 }, { 39, 30 }, { 40, 44 }, { 26, 44 } }, p.base)
  set(g, 30, 34, p.eyeDim); set(g, 36, 38, p.eyeDim)
  tube(g, { { 28, 32 }, { 23, 40 }, { 22, 46 } }, 2, 2, p.sh); tube(g, { { 38, 32 }, { 43, 40 }, { 44, 46 } }, 2, 2, p.sh)
  dagger(g, 22, 46, -1, p); dagger(g, 44, 46, 1, p)
  mass(g, 33, 24, 4, 4, p); polygon(g, { { 29, 23 }, { 37, 23 }, { 37, 27 }, { 29, 27 } }, p.sh)
  line(g, 29, 26, 37, 26, p.deep); eyeP(g, 31, 24, 1, p); eyeP(g, 35, 24, 1, p)
  return { head = { x = 33, y = 24, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 30 }, { 33, 40 } },
    limbs = { { 22, 46 }, { 44, 46 } }, belly = { x = 33, y = 38 }, mass = { { 33, 36, 8 } }, tailBase = nil, flesh = true }
end
function ARCH.aBrigand(g, rnd, p)
  tube(g, { { 28, 42 }, { 26, 55 } }, 4, 3, p.sh); tube(g, { { 37, 42 }, { 39, 55 } }, 4, 3, p.sh)
  rect(g, 24, 54, 6, 3, p.deep); rect(g, 36, 54, 6, 3, p.deep)
  mass(g, 33, 34, 9, 11, p); rect(g, 30, 28, 7, 5, p.sh)
  for i = 0, 2 do set(g, 29 + i * 3, 30, p.bone) end
  line(g, 27, 38, 39, 40, p.eyeDim)
  tube(g, { { 26, 30 }, { 20, 38 }, { 19, 44 } }, 3, 2, p.sh); tube(g, { { 40, 30 }, { 46, 36 }, { 47, 42 } }, 3, 2, p.sh)
  polygon(g, { { 17, 44 }, { 15, 40 }, { 21, 38 }, { 22, 43 } }, p.bone); line(g, 18, 40, 16, 37, p.deep)
  dagger(g, 47, 42, 1, p)
  mass(g, 33, 22, 5, 5, p); rect(g, 29, 21, 9, 2, p.sh); line(g, 31, 20, 31, 18, p.eyeDim)
  eyeP(g, 31, 22, 1, p); eyeP(g, 35, 22, 1, p)
  return { head = { x = 33, y = 22, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 28 }, { 33, 38 } },
    limbs = { { 19, 44 }, { 47, 42 } }, belly = { x = 33, y = 36 }, mass = { { 33, 34, 9 } }, tailBase = nil, flesh = true }
end
function ARCH.aCutpurse(g, rnd, p)
  tube(g, { { 30, 42 }, { 28, 55 } }, 2, 2, p.sh); tube(g, { { 35, 42 }, { 37, 55 } }, 2, 2, p.sh)
  rect(g, 26, 54, 4, 3, p.deep); rect(g, 36, 54, 4, 3, p.deep)
  mass(g, 33, 36, 5, 9, p)
  polygon(g, { { 28, 31 }, { 38, 31 }, { 39, 44 }, { 27, 44 } }, p.base)
  disc(g, 42, 44, 4, p.sh); disc(g, 42, 44, 3, p.base); line(g, 40, 40, 44, 40, p.deep)
  tube(g, { { 29, 33 }, { 24, 40 }, { 23, 45 } }, 2, 1, p.sh); tube(g, { { 37, 33 }, { 41, 38 }, { 41, 42 } }, 2, 1, p.sh)
  dagger(g, 23, 45, -1, p)
  mass(g, 33, 25, 4, 4, p); rect(g, 30, 24, 7, 3, p.sh)
  set(g, 31, 25, p.deep); set(g, 35, 25, p.deep); set(g, 30, 33, p.eyeDim)
  return { head = { x = 33, y = 25, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 31 }, { 33, 40 } },
    limbs = { { 23, 45 }, { 41, 42 } }, belly = { x = 33, y = 38 }, mass = { { 33, 36, 7 } }, tailBase = nil, flesh = true }
end
function ARCH.aHound(g, rnd, p)
  mass(g, 32, 40, 13, 8, p)
  tube(g, { { 24, 44 }, { 23, 55 } }, 3, 2, p.sh); tube(g, { { 29, 44 }, { 28, 55 } }, 3, 2, p.sh)
  tube(g, { { 38, 44 }, { 39, 55 } }, 3, 2, p.sh); tube(g, { { 43, 44 }, { 44, 55 } }, 3, 2, p.sh)
  disc(g, 23, 55, 3, p.deep); disc(g, 28, 55, 3, p.deep); disc(g, 39, 55, 3, p.deep); disc(g, 44, 55, 3, p.deep)
  tube(g, { { 45, 42 }, { 49, 44 }, { 50, 40 } }, 2, 1, p.sh)
  mass(g, 20, 40, 7, 6, p); tube(g, { { 14, 40 }, { 10, 44 } }, 4, 2, p.sh)
  polygon(g, { { 16, 44 }, { 13, 50 }, { 19, 48 } }, p.sh); polygon(g, { { 18, 38 }, { 16, 33 }, { 20, 37 } }, p.sh)
  ellipse(g, 12, 42, 2, 2, p.deep); eyeP(g, 16, 39, 1, p); line(g, 11, 43, 15, 44, p.deep)
  for i = 0, 2 do set(g, 13 + i, 45, p.eyeDim) end
  return { head = { x = 17, y = 40, r = 6 }, faceDir = { -1, 0 }, spine = { { 25, 39 }, { 33, 40 }, { 41, 41 } },
    limbs = { { 23, 55 }, { 28, 55 }, { 39, 55 }, { 44, 55 } }, belly = { x = 32, y = 47 }, mass = { { 32, 40, 12 }, { 20, 40, 6 } }, tailBase = { x = 45, y = 42 }, flesh = true }
end
function ARCH.aJackal(g, rnd, p)
  mass(g, 31, 42, 10, 5, p)
  tube(g, { { 24, 45 }, { 23, 55 } }, 2, 2, p.sh); tube(g, { { 28, 46 }, { 27, 55 } }, 2, 2, p.sh)
  tube(g, { { 36, 46 }, { 37, 55 } }, 2, 2, p.sh); tube(g, { { 40, 45 }, { 41, 55 } }, 2, 2, p.sh)
  disc(g, 23, 55, 1, p.deep); disc(g, 27, 55, 1, p.deep); disc(g, 37, 55, 1, p.deep); disc(g, 41, 55, 1, p.deep)
  tube(g, { { 40, 40 }, { 46, 42 }, { 48, 38 } }, 2, 1, p.sh)
  mass(g, 22, 38, 4, 4, p)
  polygon(g, { { 19, 38 }, { 14, 30 }, { 20, 35 } }, p.base); polygon(g, { { 24, 38 }, { 28, 30 }, { 24, 35 } }, p.base)
  tube(g, { { 18, 39 }, { 13, 43 } }, 2, 1, p.sh); eyeP(g, 19, 38, 1, p); set(g, 14, 43, p.deep)
  return { head = { x = 20, y = 38, r = 4 }, faceDir = { -1, 0 }, spine = { { 25, 39 }, { 32, 41 }, { 39, 42 } },
    limbs = { { 23, 55 }, { 27, 55 }, { 37, 55 }, { 41, 55 } }, belly = { x = 32, y = 47 }, mass = { { 31, 42, 9 }, { 22, 38, 4 } }, tailBase = { x = 40, y = 40 }, flesh = true }
end
function ARCH.aCoilSerpent(g, rnd, p)
  local r = 13
  while r >= 5 do
    for a = 0, 47 do
      local an = a / 48 * 6.283
      set(g, round(33 + cos(an) * r), round(42 + sin(an) * r * 0.6), r > 9 and p.sh or p.base)
    end
    r = r - 4
  end
  disc(g, 33, 42, 3, p.base)
  tube(g, { { 33, 40 }, { 36, 30 }, { 40, 24 } }, 3, 2, p.base)
  mass(g, 42, 22, 4, 3, p); polygon(g, { { 45, 22 }, { 50, 21 }, { 45, 24 } }, p.sh)
  line(g, 46, 22, 52, 22, p.eye); set(g, 52, 21, p.eye); set(g, 52, 23, p.eye); eyeP(g, 41, 21, 1, p)
  return { head = { x = 43, y = 22, r = 4 }, faceDir = { 1, -0.3 }, spine = { { 36, 32 }, { 33, 40 }, { 33, 46 } },
    limbs = {}, belly = { x = 33, y = 42 }, mass = { { 33, 42, 12 } }, tailBase = { x = 28, y = 46 }, flesh = true }
end
function ARCH.aCobra(g, rnd, p)
  tube(g, { { 28, 56 }, { 34, 50 }, { 30, 44 }, { 33, 38 } }, 4, 3, p.base)
  for y = 24, 36 do
    local w = round(9 - math.abs(y - 30) * 0.5)
    for x = -w, w do
      set(g, 33 + x, y, math.abs(x) > w - 1 and p.deep or (x < 0 and p.sh or p.base))
    end
  end
  ellipse(g, 33, 33, 3, 2, p.hi); disc(g, 33, 33, 1, p.eyeDim)
  mass(g, 33, 24, 4, 3, p); polygon(g, { { 35, 24 }, { 40, 24 }, { 35, 26 } }, p.sh)
  line(g, 36, 25, 42, 25, p.eye); set(g, 42, 24, p.eye); set(g, 42, 26, p.eye)
  eyeP(g, 31, 23, 1, p); eyeP(g, 35, 23, 1, p); polygon(g, { { 32, 26 }, { 33, 29 }, { 34, 26 } }, p.bone)
  return { head = { x = 33, y = 24, r = 4 }, faceDir = { 1, -0.2 }, spine = { { 33, 30 }, { 33, 40 }, { 31, 50 } },
    limbs = {}, belly = { x = 33, y = 46 }, mass = { { 33, 30, 8 } }, tailBase = { x = 28, y = 56 }, flesh = true }
end
function ARCH.aLizard(g, rnd, p)
  mass(g, 30, 42, 13, 5, p)
  for i = 0, 6 do polygon(g, { { 22 + i * 3, 38 }, { 24 + i * 3, 33 }, { 26 + i * 3, 38 } }, p.sh) end
  tube(g, { { 20, 42 }, { 14, 46 }, { 18, 40 } }, 3, 2, p.sh)
  tube(g, { { 26, 44 }, { 22, 50 }, { 26, 52 } }, 2, 1, p.sh); tube(g, { { 36, 44 }, { 40, 50 }, { 36, 52 } }, 2, 1, p.sh)
  tube(g, { { 24, 40 }, { 20, 36 }, { 24, 38 } }, 2, 1, p.sh); tube(g, { { 38, 40 }, { 42, 36 }, { 38, 38 } }, 2, 1, p.sh)
  tube(g, { { 42, 42 }, { 52, 44 }, { 58, 40 }, { 56, 44 } }, 3, 1, p.base)
  mass(g, 17, 42, 5, 4, p); polygon(g, { { 13, 42 }, { 8, 41 }, { 13, 44 } }, p.sh)
  eyeP(g, 15, 41, 1, p); eyeP(g, 15, 43, 1, p); set(g, 10, 42, p.deep)
  return { head = { x = 16, y = 42, r = 5 }, faceDir = { -1, 0 }, spine = { { 24, 41 }, { 32, 42 }, { 40, 42 } },
    limbs = { { 22, 50 }, { 36, 52 }, { 20, 38 }, { 42, 38 } }, belly = { x = 32, y = 46 }, mass = { { 30, 42, 12 }, { 17, 42, 4 } }, tailBase = { x = 42, y = 42 }, flesh = true }
end
function ARCH.aRatGiant(g, rnd, p)
  mass(g, 31, 40, 11, 7, p)
  tube(g, { { 25, 45 }, { 24, 55 } }, 2, 2, p.sh); tube(g, { { 29, 46 }, { 28, 55 } }, 2, 2, p.sh)
  tube(g, { { 36, 46 }, { 37, 55 } }, 2, 2, p.sh); tube(g, { { 40, 45 }, { 41, 55 } }, 2, 2, p.sh)
  disc(g, 24, 55, 1, p.deep); disc(g, 28, 55, 1, p.deep); disc(g, 37, 55, 1, p.deep); disc(g, 41, 55, 1, p.deep)
  tube(g, { { 41, 38 }, { 50, 36 }, { 57, 40 }, { 60, 46 } }, 2, 1, p.eyeDim)
  mass(g, 22, 38, 5, 4, p); disc(g, 19, 35, 2, p.sh); disc(g, 25, 34, 2, p.sh)
  tube(g, { { 18, 38 }, { 12, 40 } }, 2, 1, p.bone); polygon(g, { { 16, 40 }, { 12, 42 }, { 16, 42 } }, p.bone)
  eyeP(g, 19, 38, 1, p)
  for i = 0, 2 do line(g, 17, 39 + i, 11, 40 + i * 2, p.sh) end
  return { head = { x = 19, y = 38, r = 5 }, faceDir = { -1, 0 }, spine = { { 24, 39 }, { 32, 40 }, { 40, 40 } },
    limbs = { { 24, 55 }, { 28, 55 }, { 37, 55 }, { 41, 55 } }, belly = { x = 32, y = 46 }, mass = { { 31, 40, 10 }, { 22, 38, 4 } }, tailBase = { x = 41, y = 38 }, flesh = true }
end
function ARCH.aRatKing(g, rnd, p)
  local pos = { { 26, 40 }, { 40, 40 }, { 33, 34 }, { 24, 46 }, { 42, 46 }, { 33, 48 } }
  for k = 1, #pos do mass(g, pos[k][1], pos[k][2], 5, 4, p) end
  for k = 1, #pos do tube(g, { { pos[k][1], pos[k][2] }, { 33, 42 } }, 1, 1, p.eyeDim) end
  for k = 1, #pos do
    local hx = pos[k][1] + (pos[k][1] < 33 and -4 or (pos[k][1] > 33 and 4 or 0))
    local hy = pos[k][2] - 3
    disc(g, hx, hy, 2, p.sh); eyeP(g, hx, hy, 1, p)
  end
  disc(g, 33, 42, 2, p.deep)
  return { head = { x = 33, y = 34, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 38 }, { 33, 46 } },
    limbs = {}, belly = { x = 33, y = 42 }, mass = { { 33, 42, 12 } }, tailBase = nil, flesh = true }
end
function TREAT.treatCorrupt(g, rnd, p, A)
  local m = pickMass(rnd, A)
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.eyeDim); set(g, pt[1], pt[2] + 1, p.eyeDim) end
  for _ = 1, 3 do local q = onMass(rnd, m); if rnd() < 0.5 then disc(g, q[1], q[2], 1, p.sh) end end
  if A.halo and rnd() < 0.7 then
    local hx, hy = A.head.x, A.head.y - 9
    set(g, hx - 3, hy, p.out); set(g, hx - 2, hy + 1, p.out); set(g, hx + 4, hy, p.out)
  end
  if rnd() < 0.5 then set(g, A.head.x + (rnd() < 0.5 and -2 or 2), A.head.y, p.out) end
end
function TREAT.treatGrime(g, rnd, p, A)
  local m = pickMass(rnd, A)
  for _ = 1, 3 + floor(rnd() * 3) do local pt = onMass(rnd, m); disc(g, pt[1], pt[2], 1, p.sh) end
  for _ = 1, 3 do local q = onMass(rnd, m); set(g, q[1], q[2], rnd() < 0.5 and p.deep or p.eyeDim) end
  for _ = 1, 2 do local e = onMass(rnd, m); if rnd() < 0.6 then set(g, e[1], e[2], p.out) end end
  local lim = A.limbs
  if #lim > 0 and rnd() < 0.4 then local L = lim[1 + floor(rnd() * #lim)]; set(g, L[1], L[2] - 1, p.eyeDim) end
end
function TREAT.treatFeral(g, rnd, p, A)
  for _ = 1, 2 + floor(rnd() * 3) do local pt = onMass(rnd, pickMass(rnd, A)); rstreak(g, pt[1], pt[2], 2.5, p.deep, rnd) end
  for _ = 1, 3 do local q = onMass(rnd, pickMass(rnd, A)); if rnd() < 0.5 then disc(g, q[1], q[2], 1, p.sh) end end
  if rnd() < 0.6 then set(g, A.head.x, A.head.y, p.eyeDim) end
  if rnd() < 0.3 then set(g, A.head.x + 2, A.head.y + 3, p.bone); set(g, A.head.x + 3, A.head.y + 4, p.bone) end
end

-- ═══════════════════════════ V6a vivier (1/2) : arachnide/crustace/meduse/echassier/wendigo/hydre/kraken ═══
-- palettes
local SPIDER = {
  { deep = 0x1a1620, sh = 0x2e2838, base = 0x4a4258, hi = 0x6f6584, bone = 0xc2b8c8, eye = 0xd23a3a, eyeDim = 0x7a1e1e, out = 0x0c0a10 },
  { deep = 0x241c16, sh = 0x3e3024, base = 0x634c38, hi = 0x8a6a4e, bone = 0xc2b294, eye = 0xcaa23e, eyeDim = 0x6e2418, out = 0x100c08 },
  { deep = 0x201828, sh = 0x382c44, base = 0x564468, hi = 0x7e6894, bone = 0xc4b6cc, eye = 0xe0b83e, eyeDim = 0x7a2222, out = 0x0e0a12 },
}
local CRUST = {
  { deep = 0x5a1e14, sh = 0x8a3422, base = 0xbd5436, hi = 0xe08a5e, bone = 0xecd2a8, eye = 0xffe06a, eyeDim = 0x4a160e, out = 0x1a0a06 },
  { deep = 0x16304e, sh = 0x2a4e76, base = 0x447099, hi = 0x7aa0c6, bone = 0xdce2ea, eye = 0xffd24a, eyeDim = 0x102438, out = 0x0a1018 },
  { deep = 0x2c3a1a, sh = 0x4c602c, base = 0x748a40, hi = 0xa4bc6a, bone = 0xe0d8a8, eye = 0xff7a3a, eyeDim = 0x3a2410, out = 0x121808 },
}
local JELLY = {
  { deep = 0x16283e, sh = 0x284a66, base = 0x3f6e8e, hi = 0x9ad0e6, bone = 0xdff0f6, eye = 0x7af0ff, eyeDim = 0x5a86a0, out = 0x0a141e },
  { deep = 0x241838, sh = 0x3e2c5a, base = 0x5e4880, hi = 0xa888c8, bone = 0xe4d8f0, eye = 0xe08aff, eyeDim = 0x7a5e96, out = 0x0e0a16 },
  { deep = 0x283440, sh = 0x465662, base = 0x6f828e, hi = 0xb6c6ce, bone = 0xe6eef0, eye = 0xaef0e0, eyeDim = 0x62767e, out = 0x10161a },
}
local STILT = {
  { deep = 0x2c2e30, sh = 0x4a4d50, base = 0x71767a, hi = 0x9ba0a4, bone = 0xd8d2c0, eye = 0xd8c24a, eyeDim = 0x6e2a1c, out = 0x141618 },
  { deep = 0x332c22, sh = 0x534736, base = 0x7c6c52, hi = 0xa89072, bone = 0xdcd0b2, eye = 0xd0b23e, eyeDim = 0x6a2618, out = 0x161208 },
  { deep = 0x2a2824, sh = 0x46423a, base = 0x6e6858, hi = 0x968e78, bone = 0xcdc6a8, eye = 0xcab84a, eyeDim = 0x682616, out = 0x121210 },
}
local WENDIGO = {
  { deep = 0x28282c, sh = 0x444450, base = 0x6a6a76, hi = 0x9292a0, bone = 0xe2dcc8, eye = 0xbfe04a, eyeDim = 0x7a2a1c, out = 0x101014 },
  { deep = 0x2a3236, sh = 0x465256, base = 0x6e7c7e, hi = 0x9eb0b0, bone = 0xe6e6d4, eye = 0xa8f0d0, eyeDim = 0x6e2a1e, out = 0x10161a },
  { deep = 0x2c261e, sh = 0x483e30, base = 0x6e604c, hi = 0x988670, bone = 0xddd2b6, eye = 0xc8d048, eyeDim = 0x6a2618, out = 0x141008 },
}
local HYDRA = {
  { deep = 0x16301e, sh = 0x2c5034, base = 0x4a7a52, hi = 0x7aa878, bone = 0xd2d098, eye = 0xe0d23a, eyeDim = 0x7a2a18, out = 0x0c180e },
  { deep = 0x201838, sh = 0x382c58, base = 0x564080, hi = 0x8468a8, bone = 0xccc0d8, eye = 0xcaf03a, eyeDim = 0x762620, out = 0x0e0a16 },
  { deep = 0x123034, sh = 0x245256, base = 0x3e7e82, hi = 0x72b0b2, bone = 0xcfe0d8, eye = 0xe6e23a, eyeDim = 0x6e2818, out = 0x08181a },
}
local KRAKEN = {
  { deep = 0x101e34, sh = 0x1e3a5e, base = 0x345e88, hi = 0x6a96c0, bone = 0xcfdce8, eye = 0x5af0d0, eyeDim = 0x0e1a2e, out = 0x060c18 },
  { deep = 0x3a1420, sh = 0x5e2434, base = 0x8a3a50, hi = 0xbc6e80, bone = 0xe2ccc8, eye = 0xffca4a, eyeDim = 0x260a12, out = 0x140609 },
  { deep = 0x1c1632, sh = 0x322852, base = 0x4e3e74, hi = 0x7c64a0, bone = 0xcabfd6, eye = 0x8af0e0, eyeDim = 0x120a20, out = 0x0a0814 },
}
-- archetypes : ARACHNIDE (8 pattes radiales, corps bas)
function ARCH.aSpider(g, rnd, p)
  for s = 0, 3 do
    local ly = 34 + s * 3
    tube(g, { { 28, ly }, { 18, ly - 4 }, { 10, ly + 2 } }, 2, 1, p.sh)
    tube(g, { { 38, ly }, { 48, ly - 4 }, { 56, ly + 2 } }, 2, 1, p.sh)
  end
  mass(g, 33, 44, 8, 7, p); mass(g, 33, 34, 5, 4, p)
  for i = 0, 5 do set(g, 30 + (i % 3) * 2, 33 + floor(i / 3), p.eye) end
  polygon(g, { { 31, 37 }, { 30, 41 }, { 32, 38 } }, p.bone); polygon(g, { { 35, 37 }, { 36, 41 }, { 34, 38 } }, p.bone)
  return { head = { x = 33, y = 34, r = 5 }, faceDir = { 0, 1 }, spine = { { 33, 38 }, { 33, 44 } },
    limbs = { { 10, 38 }, { 56, 38 }, { 12, 44 }, { 54, 44 } }, belly = { x = 33, y = 44 }, mass = { { 33, 44, 7 }, { 33, 34, 4 } }, tailBase = nil, flesh = true }
end
function ARCH.aWidow(g, rnd, p)
  for s = 0, 3 do
    local ly = 40 + s * 2
    tube(g, { { 29, ly }, { 18, ly - 6 }, { 12, ly + 4 } }, 2, 1, p.sh)
    tube(g, { { 37, ly }, { 48, ly - 6 }, { 54, ly + 4 } }, 2, 1, p.sh)
  end
  disc(g, 33, 44, 9, p.base); disc(g, 30, 41, 3, p.hi)
  polygon(g, { { 33, 41 }, { 31, 46 }, { 35, 46 } }, p.eyeDim); polygon(g, { { 33, 48 }, { 31, 44 }, { 35, 44 } }, p.eyeDim)
  mass(g, 33, 33, 4, 4, p)
  set(g, 31, 32, p.eye); set(g, 35, 32, p.eye); set(g, 33, 31, p.eye)
  return { head = { x = 33, y = 33, r = 4 }, faceDir = { 0, 1 }, spine = { { 33, 37 }, { 33, 44 } },
    limbs = { { 12, 40 }, { 54, 40 }, { 14, 46 }, { 52, 46 } }, belly = { x = 33, y = 44 }, mass = { { 33, 44, 8 }, { 33, 33, 4 } }, tailBase = nil, flesh = true }
end
-- archetypes : CRUSTACÉ (carapace large, pinces)
function ARCH.aCrab(g, rnd, p)
  local ly = { 34, 39, 44 }
  for i = 0, 2 do
    tube(g, { { 23, ly[i + 1] }, { 14, ly[i + 1] + 2 + i }, { 7, ly[i + 1] + 6 + i } }, 2, 1, p.sh)
    tube(g, { { 43, ly[i + 1] }, { 52, ly[i + 1] + 2 + i }, { 59, ly[i + 1] + 6 + i } }, 2, 1, p.sh)
  end
  for y = -7, 5 do
    local w = round(15 * sqrt(max(0, 1 - (y * y) / 64)))
    for x = -w, w do
      set(g, 33 + x, 37 + y, (math.abs(x) > w - 1 or y >= 4) and p.deep or (y <= -4 and p.hi or (y <= 0 and p.base or p.sh)))
    end
  end
  line(g, 23, 33, 43, 33, p.sh); line(g, 25, 40, 41, 40, p.deep)
  disc(g, 27, 36, 1, p.hi); disc(g, 39, 36, 1, p.hi)
  tube(g, { { 26, 31 }, { 22, 25 }, { 20, 21 } }, 3, 2, p.base)
  for u = -3, 3 do
    local ww = 3 - floor(math.abs(u) / 2)
    for v = -ww, ww do set(g, 20 + v, 21 + u, math.abs(v) > ww - 1 and p.deep or p.base) end
  end
  set(g, 18, 19, p.deep); set(g, 18, 23, p.deep)
  tube(g, { { 40, 31 }, { 44, 25 }, { 46, 21 } }, 3, 2, p.base)
  for u2 = -3, 3 do
    local ww2 = 3 - floor(math.abs(u2) / 2)
    for v2 = -ww2, ww2 do set(g, 46 + v2, 21 + u2, math.abs(v2) > ww2 - 1 and p.deep or p.base) end
  end
  set(g, 48, 19, p.deep); set(g, 48, 23, p.deep)
  tube(g, { { 30, 31 }, { 29, 27 } }, 1, 1, p.sh); tube(g, { { 36, 31 }, { 37, 27 } }, 1, 1, p.sh)
  eyeP(g, 29, 26, 1, p); eyeP(g, 37, 26, 1, p)
  set(g, 32, 43, p.deep); set(g, 34, 43, p.deep)
  return { head = { x = 33, y = 34, r = 6 }, faceDir = { 0, -1 }, spine = { { 33, 33 }, { 33, 40 } },
    limbs = { { 7, 40 }, { 59, 40 }, { 9, 46 }, { 57, 46 } }, belly = { x = 33, y = 41 }, mass = { { 33, 37, 14 } }, tailBase = nil, flesh = true }
end
function ARCH.aMantisShrimp(g, rnd, p)
  local sp = { { 16, 46 }, { 24, 45 }, { 32, 43 }, { 40, 41 }, { 46, 38 } }
  for i = 1, #sp - 1 do tube(g, { sp[i], sp[i + 1] }, max(2, 5 - (i - 1)), max(1, 4 - (i - 1)), p.base) end
  for i = 0, 5 do
    local sx, sy = 20 + i * 4, round(46 - i * 1.4)
    line(g, sx, sy - 5, sx, sy + 4, p.deep); line(g, sx + 1, sy - 5, sx + 1, sy + 4, p.hi)
  end
  for i = 0, 3 do
    local an = 2.0 + i * 0.4
    tube(g, { { 16, 46 }, { 16 - round(cos(an) * 7), 46 + round(sin(an) * 7) } }, 2, 1, p.sh)
  end
  mass(g, 47, 37, 5, 5, p)
  for i = 0, 2 do local bx = 44 + i * 2; tube(g, { { bx, 40 }, { bx + 4, 45 }, { bx + 1, 49 } }, 2, 1, p.base) end
  polygon(g, { { 45, 48 }, { 52, 52 }, { 47, 49 } }, p.bone); polygon(g, { { 47, 46 }, { 54, 49 }, { 48, 47 } }, p.bone)
  tube(g, { { 48, 34 }, { 51, 29 } }, 1, 1, p.sh); tube(g, { { 45, 34 }, { 47, 29 } }, 1, 1, p.sh)
  eyeP(g, 51, 28, 1, p); eyeP(g, 47, 28, 1, p)
  return { head = { x = 47, y = 37, r = 5 }, faceDir = { 1, 0 }, spine = { { 40, 40 }, { 28, 43 }, { 18, 46 } },
    limbs = { { 9, 49 }, { 49, 49 } }, belly = { x = 30, y = 44 }, mass = { { 33, 42, 12 }, { 47, 37, 4 } }, tailBase = { x = 16, y = 46 }, flesh = true }
end
-- archetypes : MÉDUSE (cloche + filaments, flottant)
function ARCH.aJelly(g, rnd, p)
  jellyBell(g, 33, 26, 12, 9, p)
  for i = 0, 4 do local tx = 23 + i * 5; tube(g, { { tx, 27 }, { tx + sin(i) * 2, 38 }, { tx - 2, 50 }, { tx + 1, 56 } }, 1, 1, p.base) end
  tube(g, { { 28, 27 }, { 26, 40 }, { 28, 52 } }, 2, 1, p.sh); tube(g, { { 38, 27 }, { 40, 40 }, { 38, 52 } }, 2, 1, p.sh)
  set(g, 30, 22, p.eye); set(g, 36, 22, p.eye)
  return { head = { x = 33, y = 24, r = 6 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 38 } },
    limbs = {}, belly = { x = 33, y = 34 }, mass = { { 33, 26, 9 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aSiphon(g, rnd, p)
  for b = 0, 3 do local by = 18 + b * 7; jellyBell(g, 33, by, round(7 - b), round(5 - b * 0.5), p) end
  for i = 0, 6 do local tx = 24 + i * 3; tube(g, { { tx, 40 }, { tx + sin(i * 1.5) * 3, 50 }, { tx, 58 } }, 1, 1, p.base) end
  set(g, 33, 16, p.eye)
  for i = 0, 4 do set(g, 26 + i * 3, 52 + (i % 2), p.eye) end
  return { head = { x = 33, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 22 }, { 33, 38 } },
    limbs = {}, belly = { x = 33, y = 36 }, mass = { { 33, 28, 7 } }, tailBase = nil, flesh = true, float = true }
end
-- archetypes : ÉCHASSIER (grand bipède maigre, long cou)
function ARCH.aStrider(g, rnd, p)
  tube(g, { { 30, 30 }, { 26, 44 }, { 24, 55 } }, 2, 1, p.sh); tube(g, { { 36, 30 }, { 40, 44 }, { 42, 55 } }, 2, 1, p.sh)
  polygon(g, { { 21, 55 }, { 27, 55 }, { 24, 57 } }, p.sh); polygon(g, { { 39, 55 }, { 45, 55 }, { 42, 57 } }, p.sh)
  mass(g, 33, 28, 5, 7, p)
  tube(g, { { 31, 26 }, { 30, 30 } }, 1, 1, p.sh); tube(g, { { 35, 26 }, { 36, 30 } }, 1, 1, p.sh)
  tube(g, { { 33, 23 }, { 34, 14 }, { 31, 8 } }, 2, 1, p.sh)
  mass(g, 30, 7, 4, 3, p)
  polygon(g, { { 27, 7 }, { 22, 6 }, { 27, 9 } }, p.bone)
  eyeP(g, 29, 6, 1, p)
  return { head = { x = 30, y = 7, r = 4 }, faceDir = { -1, 0 }, spine = { { 33, 14 }, { 33, 24 }, { 33, 30 } },
    limbs = { { 24, 55 }, { 42, 55 } }, belly = { x = 33, y = 32 }, mass = { { 33, 28, 6 }, { 30, 7, 3 } }, tailBase = nil, flesh = true }
end
function ARCH.aHeron(g, rnd, p)
  tube(g, { { 32, 32 }, { 30, 46 }, { 29, 56 } }, 2, 1, p.sh); tube(g, { { 35, 32 }, { 37, 42 }, { 40, 46 } }, 1, 1, p.sh)
  polygon(g, { { 26, 56 }, { 32, 56 }, { 29, 58 } }, p.sh)
  mass(g, 33, 30, 5, 7, p)
  tube(g, { { 34, 26 }, { 40, 18 }, { 36, 12 }, { 40, 8 } }, 2, 1, p.sh)
  mass(g, 41, 7, 3, 3, p)
  polygon(g, { { 43, 7 }, { 52, 8 }, { 43, 9 } }, p.bone)
  eyeP(g, 41, 6, 1, p)
  for i = 0, 2 do line(g, 33, 22, 29, 16 - i * 2, p.bone) end
  return { head = { x = 42, y = 7, r = 3 }, faceDir = { 1, 0 }, spine = { { 33, 14 }, { 33, 24 }, { 32, 32 } },
    limbs = { { 29, 56 }, { 40, 46 } }, belly = { x = 33, y = 34 }, mass = { { 33, 30, 6 }, { 41, 7, 3 } }, tailBase = nil, flesh = true }
end
-- archetypes : WENDIGO (cervidé émacié, ramure)
function ARCH.aWendigo(g, rnd, p)
  tube(g, { { 30, 40 }, { 27, 55 } }, 3, 2, p.sh); tube(g, { { 36, 40 }, { 39, 55 } }, 3, 2, p.sh)
  disc(g, 27, 55, 2, p.deep); disc(g, 39, 55, 2, p.deep)
  mass(g, 33, 33, 5, 11, p)
  for i = 0, 3 do
    line(g, 29, 28 + i * 3, 37, 28 + i * 3, p.deep); set(g, 29, 28 + i * 3, p.bone); set(g, 37, 28 + i * 3, p.bone)
  end
  tube(g, { { 29, 28 }, { 22, 40 }, { 19, 50 } }, 2, 1, p.sh); tube(g, { { 37, 28 }, { 44, 40 }, { 47, 50 } }, 2, 1, p.sh)
  for i = 0, 2 do line(g, 18, 50, 16 + i, 54, p.bone); line(g, 48, 50, 46 + i, 54, p.bone) end
  mass(g, 33, 21, 4, 5, p)
  polygon(g, { { 31, 24 }, { 35, 24 }, { 33, 28 } }, p.bone)
  set(g, 31, 20, p.eye); set(g, 35, 20, p.eye)
  antler(g, 30, 18, -1, p); antler(g, 36, 18, 1, p)
  return { head = { x = 33, y = 21, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 38 } },
    limbs = { { 19, 50 }, { 47, 50 } }, belly = { x = 33, y = 34 }, mass = { { 33, 33, 7 } }, tailBase = nil, flesh = true }
end
function ARCH.aStag(g, rnd, p)
  tube(g, { { 28, 42 }, { 26, 55 } }, 3, 2, p.sh); tube(g, { { 33, 42 }, { 32, 55 } }, 3, 2, p.sh); tube(g, { { 38, 42 }, { 40, 55 } }, 3, 2, p.sh)
  disc(g, 26, 55, 2, p.deep); disc(g, 32, 55, 2, p.deep); disc(g, 40, 55, 2, p.deep)
  mass(g, 33, 36, 6, 9, p)
  for i = 0, 2 do line(g, 30, 32 + i * 3, 37, 32 + i * 3, p.deep) end
  tube(g, { { 36, 30 }, { 42, 24 }, { 44, 18 } }, 3, 2, p.sh)
  mass(g, 45, 15, 4, 5, p)
  polygon(g, { { 47, 17 }, { 53, 18 }, { 47, 20 } }, p.bone)
  set(g, 44, 13, p.eye)
  antler(g, 43, 11, -1, p); antler(g, 47, 11, 1, p)
  eyeP(g, 45, 14, 1, p)
  return { head = { x = 46, y = 15, r = 5 }, faceDir = { 1, -0.3 }, spine = { { 36, 30 }, { 33, 38 }, { 31, 44 } },
    limbs = { { 26, 55 }, { 32, 55 }, { 40, 55 } }, belly = { x = 33, y = 42 }, mass = { { 33, 36, 7 }, { 45, 15, 4 } }, tailBase = nil, flesh = true }
end
-- archetypes : HYDRE (cous serpentins rayonnants)
function ARCH.aHydra(g, rnd, p)
  mass(g, 32, 46, 13, 7, p)
  tube(g, { { 24, 50 }, { 22, 56 } }, 3, 2, p.sh); tube(g, { { 40, 50 }, { 42, 56 } }, 3, 2, p.sh)
  local necks = { { 24, 18, -1 }, { 33, 12, 0 }, { 42, 18, 1 }, { 16, 28, -1 } }
  for n = 1, #necks do
    local hx, hy, dir = necks[n][1], necks[n][2], necks[n][3]
    tube(g, { { 33, 44 }, { (33 + hx) / 2, (44 + hy) / 2 + 4 }, { hx, hy + 4 } }, 3, 2, p.sh)
    mass(g, hx, hy, 4, 3, p)
    polygon(g, { { hx + dir * 3, hy }, { hx + dir * 8, hy + 1 }, { hx + dir * 3, hy + 2 } }, p.base)
    eyeP(g, hx, hy - 1, 1, p)
  end
  return { head = { x = 33, y = 12, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 30 }, { 33, 44 } },
    limbs = { { 22, 56 }, { 42, 56 } }, belly = { x = 33, y = 48 }, mass = { { 32, 46, 12 } }, tailBase = nil, flesh = true }
end
-- archetypes : KRAKEN (appendices jaillissants, bec central)
function ARCH.aKraken(g, rnd, p)
  local bases = { { 26, -1 }, { 31, -1 }, { 33, -1 }, { 35, 1 }, { 40, 1 }, { 23, -1 }, { 43, 1 } }
  for a = 0, #bases - 1 do
    local bx, dir = bases[a + 1][1], bases[a + 1][2]
    local pts = {}
    for s = 0, 7 do
      local tt = s / 7
      local xx = bx + dir * sin(tt * 2.4) * (10 + a) * 0.9
      local yy = 42 + tt * 15
      pts[#pts + 1] = { round(xx), round(yy) }
    end
    for s = 0, #pts - 2 do
      local w = max(1, 4 - s * 0.5)
      tube(g, { pts[s + 1], pts[s + 2] }, w, max(1, w - 0.5), p.base)
    end
    local s = 1
    while s < #pts - 1 do disc(g, pts[s + 1][1] + dir, pts[s + 1][2], 1, p.sh); s = s + 2 end
  end
  for y = -9, 6 do
    local ww = round(11 * sqrt(max(0, 1 - (y * y) / 95)))
    for x = -ww, ww do
      set(g, 33 + x, 34 + y, math.abs(x) > ww - 1 and p.deep or (y < -4 and p.hi or (y < 2 and p.base or p.sh)))
    end
  end
  mass(g, 33, 30, 7, 4, p)
  eyeP(g, 29, 32, 2, p); eyeP(g, 38, 32, 2, p)
  polygon(g, { { 31, 41 }, { 35, 41 }, { 33, 46 } }, p.deep)
  set(g, 33, 44, p.bone)
  return { head = { x = 33, y = 32, r = 10 }, faceDir = { 0, -1 }, spine = { { 33, 28 }, { 33, 40 } },
    limbs = {}, belly = { x = 33, y = 42 }, mass = { { 33, 34, 11 } }, tailBase = nil, flesh = true }
end
-- traitements V6a
function TREAT.treatChitin(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 2 + floor(rnd() * 2) do
    local pt = onMass(rnd, m)
    line(g, pt[1], pt[2], pt[1] + round((rnd() - 0.5) * 6), pt[2] + round((rnd() - 0.5) * 4), p.deep)
  end
  for _ = 1, 5 do
    local q = onMass(rnd, m)
    line(g, q[1], q[2], q[1] + round((rnd() - 0.5) * 3), q[2] - 2 - floor(rnd() * 2), p.sh)
  end
  for _ = 1, 2 do local e = onMass(rnd, m); if rnd() < 0.5 then set(g, e[1], e[2], p.eye) end end
end
function TREAT.treatDrift(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 4 do
    local bx = m[1] + round((rnd() - 0.5) * m[3] * 1.4)
    tube(g, { { bx, m[2] + m[3] }, { bx + round((rnd() - 0.5) * 4), m[2] + m[3] + 8 }, { bx, m[2] + m[3] + 16 } }, 1, 1, p.base)
  end
  for _ = 1, 5 do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.eye) end
  for _ = 1, 3 do local q = onMass(rnd, m); if rnd() < 0.5 then set(g, q[1], q[2], p.out) end end
end
function TREAT.treatGaunt(g, rnd, p, A)
  local m = A.mass[1]
  for i = 0, 2 do local yy = m[2] - 3 + i * 3; line(g, m[1] - 3, yy, m[1] + 3, yy, p.bone) end
  for _ = 1, 3 do local pt = onMass(rnd, m); if rnd() < 0.5 then disc(g, pt[1], pt[2], 1, p.sh) end end
  for _ = 1, 2 do local q = onMass(rnd, m); set(g, q[1], q[2], p.deep) end
  if rnd() < 0.5 then eyeP(g, A.head.x + (rnd() < 0.5 and -2 or 2), A.head.y + 2, 1, p) end
end
function TREAT.treatMany(g, rnd, p, A)
  local m = A.mass[1]
  if rnd() < 0.7 then
    local ax, ay = m[1] + round((rnd() - 0.5) * m[3] * 1.6), m[2] - floor(rnd() * 8)
    tube(g, { { m[1], m[2] }, { (m[1] + ax) / 2, (m[2] + ay) / 2 }, { ax, ay } }, 2, 1, p.sh)
    mass(g, ax, ay - 2, 3, 2, p); eyeP(g, ax, ay - 2, 1, p)
  end
  for _ = 1, 3 do local pt = onMass(rnd, m); if rnd() < 0.5 then set(g, pt[1], pt[2], p.eye) end end
  if rnd() < 0.4 then local q = onMass(rnd, m); disc(g, q[1], q[2], 1, p.deep) end
end
-- ═══════════════════════════ V6 vivier (part 2) : pendu/chimere/cocon/plante/larve/crane/automate ═══════
-- palettes
local PUPPET = {
  { deep = 0x3a2c1c, sh = 0x5c462e, base = 0x896a46, hi = 0xb69468, bone = 0xe8e0c8, eye = 0xcaa83e, eyeDim = 0x6e281a, out = 0x181206 },
  { deep = 0x2e2a2a, sh = 0x4c4544, base = 0x736866, hi = 0x9c8e8a, bone = 0xd8cdba, eye = 0xc0b84a, eyeDim = 0x6e261a, out = 0x141010 },
  { deep = 0x34322c, sh = 0x545046, base = 0x7e7868, hi = 0xa89e88, bone = 0xe6ddc4, eye = 0xcab84a, eyeDim = 0x6a2618, out = 0x161410 },
}
local CHIMERA = {
  { deep = 0x2c2418, sh = 0x4a3a26, base = 0x6e5638, hi = 0x967250, bone = 0xcdbf98, eye = 0xd23a3a, eyeDim = 0x7a2418, out = 0x141008 },
  { deep = 0x2a2018, sh = 0x4a3424, base = 0x724a38, hi = 0x9a6a50, bone = 0xc8ba94, eye = 0xaee04a, eyeDim = 0x7c2418, out = 0x120c08 },
  { deep = 0x262430, sh = 0x403c50, base = 0x5e5870, hi = 0x867e98, bone = 0xc4bcc8, eye = 0xe0b83e, eyeDim = 0x742222, out = 0x100e16 },
}
local COCOON = {
  { deep = 0x34302a, sh = 0x544e44, base = 0x7e7563, hi = 0xaaa088, bone = 0xe0d8c0, eye = 0xffb24a, eyeDim = 0x6e3a1c, out = 0x161410 },
  { deep = 0x283022, sh = 0x445238, base = 0x6a7c52, hi = 0x94a672, bone = 0xd6d2a8, eye = 0x9af04a, eyeDim = 0x5a3a18, out = 0x101408 },
  { deep = 0x2a2034, sh = 0x463658, base = 0x6a547e, hi = 0x9480a4, bone = 0xd2c8dc, eye = 0xe08aff, eyeDim = 0x6a3a3a, out = 0x120e1a },
}
local FLORA = {
  { deep = 0x1e3220, sh = 0x345234, base = 0x527a4e, hi = 0x84a874, bone = 0xd2c26a, eye = 0xe07aff, eyeDim = 0x7a3a1c, out = 0x0e180e },
  { deep = 0x22341e, sh = 0x3e5632, base = 0x647e44, hi = 0x94a866, bone = 0xe0c84a, eye = 0xff5a5a, eyeDim = 0x7a2a18, out = 0x101808 },
  { deep = 0x243020, sh = 0x425034, base = 0x6a7c4a, hi = 0x9aaa6e, bone = 0xe6cc56, eye = 0xff9a3a, eyeDim = 0x6e3a1c, out = 0x101408 },
}
local GRUB = {
  { deep = 0x4a4430, sh = 0x6e664a, base = 0x9a906a, hi = 0xc8be94, bone = 0xe8e0c0, eye = 0xcaa83e, eyeDim = 0x7a4a2a, out = 0x1c1810 },
  { deep = 0x3c3e38, sh = 0x5e6056, base = 0x888a7c, hi = 0xb4b6a4, bone = 0xe4e4d2, eye = 0xbfe04a, eyeDim = 0x6e3a2a, out = 0x161614 },
  { deep = 0x4a342e, sh = 0x704c44, base = 0x9a6c60, hi = 0xc49488, bone = 0xe6d2c4, eye = 0xcaa83e, eyeDim = 0x7a3a30, out = 0x1c1210 },
}
local SKULL = {
  { deep = 0x4a4636, sh = 0x726c52, base = 0xa09872, hi = 0xcdc49a, bone = 0xece2c4, eye = 0xff8a3a, eyeDim = 0x5a3018, out = 0x1e1a10 },
  { deep = 0x3e3e3a, sh = 0x62625a, base = 0x8e8e80, hi = 0xbcbcaa, bone = 0xe8e6d4, eye = 0x5af0d0, eyeDim = 0x52301a, out = 0x181814 },
  { deep = 0x2c2824, sh = 0x48423a, base = 0x6e665a, hi = 0x948c7c, bone = 0xcdc4ac, eye = 0xff5a3a, eyeDim = 0x3a2010, out = 0x141210 },
}
local AUTOMATON = {
  { deep = 0x2e2a28, sh = 0x4c4642, base = 0x736a62, hi = 0x9a9286, bone = 0xc2bca8, eye = 0xffb24a, eyeDim = 0x7a3a1c, out = 0x141210 },
  { deep = 0x3a2e1c, sh = 0x5e4a2c, base = 0x8a6c40, hi = 0xb89866, bone = 0xd8c8a0, eye = 0xffd24a, eyeDim = 0x7e4420, out = 0x181206 },
  { deep = 0x1e3430, sh = 0x345650, base = 0x528078, hi = 0x84b0a4, bone = 0xcdd8c8, eye = 0x7af0d0, eyeDim = 0x6e3a1c, out = 0x0e1814 },
}
-- archetypes : PENDU (suspendu, fils/corde, membres ballants — flottant)
function ARCH.aMarionette(g, rnd, p)
  rect(g, 18, 5, 28, 2, p.bone); set(g, 18, 4, p.deep); set(g, 45, 4, p.deep)
  line(g, 24, 7, 27, 17, p.sh); line(g, 42, 7, 39, 17, p.sh); line(g, 33, 7, 33, 15, p.sh)
  line(g, 22, 7, 25, 38, p.sh); line(g, 44, 7, 41, 38, p.sh)
  rect(g, 29, 24, 8, 12, p.base); rect(g, 29, 24, 8, 2, p.hi); rect(g, 29, 24, 2, 12, p.sh)
  line(g, 33, 26, 33, 34, p.deep); rect(g, 30, 35, 6, 3, p.sh)
  disc(g, 28, 25, 2, p.base); rect(g, 24, 26, 4, 3, p.base); disc(g, 24, 28, 2, p.sh); rect(g, 22, 30, 3, 8, p.base); disc(g, 23, 38, 2, p.deep)
  disc(g, 38, 25, 2, p.base); rect(g, 38, 26, 4, 3, p.base); disc(g, 42, 28, 2, p.sh); rect(g, 41, 30, 3, 8, p.base); disc(g, 42, 38, 2, p.deep)
  rect(g, 30, 38, 3, 8, p.base); disc(g, 31, 46, 2, p.sh); rect(g, 30, 47, 3, 8, p.base); disc(g, 31, 55, 2, p.deep)
  rect(g, 33, 38, 3, 8, p.base); disc(g, 34, 46, 2, p.sh); rect(g, 33, 47, 3, 8, p.base); disc(g, 34, 55, 2, p.deep)
  mass(g, 33, 19, 5, 5, p); ellipse(g, 33, 19, 4, 4, p.hi); eyeP(g, 31, 18, 1, p); eyeP(g, 35, 18, 1, p)
  line(g, 30, 22, 36, 22, p.deep); line(g, 32, 22, 31, 24, p.deep); line(g, 34, 22, 35, 24, p.deep)
  return { head = { x = 33, y = 19, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 24 }, { 33, 36 } },
    limbs = { { 23, 38 }, { 42, 38 }, { 31, 55 }, { 34, 55 } }, belly = { x = 33, y = 30 }, mass = { { 33, 29, 8 } }, tailBase = nil, flesh = true, float = true }
end
function ARCH.aHanged(g, rnd, p)
  line(g, 33, 3, 33, 13, p.sh); line(g, 32, 3, 32, 13, p.deep)
  ellipse(g, 31, 15, 3, 2, p.sh); set(g, 30, 15, p.deep); set(g, 33, 15, p.deep)
  mass(g, 30, 19, 4, 4, p); set(g, 28, 18, p.deep); set(g, 31, 19, p.deep); line(g, 28, 21, 32, 22, p.deep); set(g, 27, 20, p.eyeDim)
  mass(g, 32, 30, 5, 9, p)
  for i = 0, 2 do line(g, 28, 27 + i * 3, 37, 28 + i * 3, p.deep) end
  tube(g, { { 29, 26 }, { 26, 34 }, { 27, 43 } }, 2, 1, p.sh); tube(g, { { 36, 26 }, { 40, 33 }, { 39, 43 } }, 2, 1, p.sh)
  disc(g, 27, 44, 1, p.deep); disc(g, 39, 44, 1, p.deep)
  tube(g, { { 31, 38 }, { 29, 48 }, { 30, 57 } }, 2, 2, p.sh); tube(g, { { 35, 38 }, { 37, 48 }, { 36, 57 } }, 2, 2, p.sh)
  set(g, 30, 57, p.deep); set(g, 36, 57, p.deep)
  for i = 0, 2 do set(g, 29 + i * 3, 40, p.deep) end
  return { head = { x = 30, y = 19, r = 4 }, faceDir = { -1, -0.3 }, spine = { { 32, 26 }, { 32, 37 } },
    limbs = { { 27, 43 }, { 39, 43 } }, belly = { x = 32, y = 32 }, mass = { { 32, 30, 7 } }, tailBase = nil, flesh = true, float = true }
end
-- archetypes : CHIMÈRE (amalgame asymétrique, têtes en surnombre)
function ARCH.aChimera(g, rnd, p)
  mass(g, 32, 38, 11, 9, p)
  tube(g, { { 26, 44 }, { 24, 55 } }, 3, 3, p.sh); tube(g, { { 38, 44 }, { 40, 55 } }, 2, 2, p.sh)
  disc(g, 24, 55, 3, p.deep); disc(g, 40, 55, 2, p.deep)
  tube(g, { { 24, 32 }, { 16, 30 }, { 12, 36 } }, 4, 2, p.sh); disc(g, 11, 37, 3, p.deep)
  bigWing(g, 40, 30, 1, 14, p)
  mass(g, 26, 22, 4, 4, p); eyeP(g, 25, 22, 1, p); maw(g, 26, 25, 2, p)
  mass(g, 36, 24, 3, 3, p); eyeP(g, 36, 24, 1, p)
  tube(g, { { 33, 30 }, { 34, 20 }, { 31, 14 } }, 2, 1, p.sh)
  mass(g, 30, 12, 3, 3, p); eyeP(g, 29, 12, 1, p); eyeP(g, 31, 12, 1, p)
  return { head = { x = 30, y = 12, r = 4 }, faceDir = { 0, -1 }, spine = { { 32, 30 }, { 32, 40 } },
    limbs = { { 12, 36 }, { 24, 55 }, { 40, 55 } }, belly = { x = 32, y = 40 }, mass = { { 32, 38, 10 } }, tailBase = nil, flesh = true }
end
-- archetypes : COCON générique (ovoïde vertical fibreux, fente lumineuse).
-- ⚠️ SUPERSÉDÉ (B.2) : la famille `cocon` utilise désormais 4 formes distinctes (broodsac/bilesac/chrysalis/
-- embersac, cf. aCocoonBrood…). aCocoon n'est plus dans FAMILIES (code mort inerte, gardé en réserve).
function ARCH.aCocoon(g, rnd, p)
  for y = 14, 54 do
    local t = (y - 14) / 40
    local w = round(11 * sin(t * 3.14) * 0.9 + 3)
    for x = -w, w do set(g, 33 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  for s = 0, 6 do
    local sy = 16 + s * 5
    line(g, 33 - 9, sy, 33 + 9, sy - 3, p.deep); line(g, 33 - 9, sy + 2, 33 + 9, sy + 5, p.deep)
  end
  for y = 24, 44 do
    set(g, 33, y, p.deep)
    if y % 3 == 0 then set(g, 32, y, p.eye); set(g, 34, y, p.eye) end
  end
  eyeP(g, 33, 30, 1, p)
  return { head = { x = 33, y = 32, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 22 }, { 33, 46 } },
    limbs = {}, belly = { x = 33, y = 34 }, mass = { { 33, 34, 10 } }, tailBase = nil, flesh = true }
end
-- archetypes : PLANTE-GUEULE (gueule-fleur sur tige, vrilles)
function ARCH.aMaweed(g, rnd, p)
  tube(g, { { 33, 56 }, { 31, 46 }, { 33, 38 } }, 3, 2, p.base); disc(g, 33, 56, 4, p.sh)
  for i = 0, 3 do
    local d = (i < 2 and -1 or 1)
    tube(g, { { 33, 48 }, { 33 + d * (6 + i * 2), 44 - i * 2 }, { 33 + d * (10 + i * 2), 40 - i * 3 } }, 1, 1, p.sh)
  end
  polygon(g, { { 27, 32 }, { 39, 32 }, { 42, 24 }, { 33, 20 }, { 24, 24 } }, p.base)
  polygon(g, { { 27, 32 }, { 39, 32 }, { 36, 38 }, { 30, 38 } }, p.deep)
  for i = 0, 5 do
    polygon(g, { { 26 + i * 2.4, 32 }, { 27 + i * 2.4, 32 }, { 26.5 + i * 2.4, 36 } }, p.bone)
    polygon(g, { { 26 + i * 2.4, 24 }, { 27 + i * 2.4, 24 }, { 26.5 + i * 2.4, 28 } }, p.bone)
  end
  eyeP(g, 30, 28, 1, p); eyeP(g, 36, 28, 1, p)
  return { head = { x = 33, y = 26, r = 6 }, faceDir = { 0, -1 }, spine = { { 33, 38 }, { 33, 48 } },
    limbs = {}, belly = { x = 33, y = 40 }, mass = { { 33, 30, 9 } }, tailBase = nil, flesh = true }
end
function ARCH.aVinemaw(g, rnd, p)
  for v = 0, 4 do
    local bx = 22 + v * 5
    tube(g, { { bx, 56 }, { bx + sin(v) * 4, 46 }, { bx + cos(v) * 5, 36 + v } }, 2, 1, p.base)
  end
  disc(g, 33, 32, 7, p.base); disc(g, 33, 32, 5, p.deep)
  for i = 0, 7 do
    local an = i / 8 * 6.283
    polygon(g, { { round(33 + cos(an) * 5), round(32 + sin(an) * 5) }, { round(33 + cos(an) * 7), round(32 + sin(an) * 7) }, { round(33 + cos(an + 0.3) * 5), round(32 + sin(an + 0.3) * 5) } }, p.bone)
  end
  local pods = { { 22, 40 }, { 44, 40 }, { 26, 30 }, { 40, 28 } }
  for i = 1, #pods do
    disc(g, pods[i][1], pods[i][2], 3, p.sh); disc(g, pods[i][1], pods[i][2], 1, p.deep); eyeP(g, pods[i][1], pods[i][2] - 1, 1, p)
  end
  eyeP(g, 33, 32, 2, p)
  return { head = { x = 33, y = 32, r = 6 }, faceDir = { 0, -1 }, spine = { { 33, 38 }, { 33, 48 } },
    limbs = {}, belly = { x = 33, y = 40 }, mass = { { 33, 32, 9 } }, tailBase = nil, flesh = true }
end
-- archetypes : LARVE (corps mou en C, segments, pseudopattes)
function ARCH.aGrub(g, rnd, p)
  local pts = {}
  for i = 0, 8 do
    local t = i / 8; local ang = 3.14 * 0.2 + t * 3.14 * 1.1
    pts[#pts + 1] = { round(33 + cos(ang) * 13), round(40 + sin(ang) * 11) }
  end
  segChain(g, pts, 5, 3, p)
  for k = 2, 8, 2 do tube(g, { { pts[k][1], pts[k][2] + 3 }, { pts[k][1] - 1, pts[k][2] + 6 } }, 1, 1, p.sh) end
  local hx, hy = pts[1][1], pts[1][2]
  mass(g, hx, hy, 4, 4, p)
  polygon(g, { { hx + 2, hy - 1 }, { hx + 5, hy - 3 }, { hx + 3, hy } }, p.bone)
  polygon(g, { { hx + 2, hy + 1 }, { hx + 5, hy + 3 }, { hx + 3, hy } }, p.bone)
  eyeP(g, hx, hy - 1, 1, p)
  return { head = { x = hx, y = hy, r = 4 }, faceDir = { 1, 0 }, spine = { { 33, 30 }, { 33, 44 } },
    limbs = {}, belly = { x = 33, y = 40 }, mass = { { 33, 40, 10 } }, tailBase = nil, flesh = true }
end
-- archetypes : CRÂNE COLOSSAL (tête géante désincarnée)
function ARCH.aSkullking(g, rnd, p)
  for y = -15, 10 do
    local w = round(16 * sqrt(max(0, 1 - (y * y) / (y < 0 and 225 or 140))))
    for x = -w, w do set(g, 33 + x, 30 + y, math.abs(x) > w - 1 and p.deep or (y < -6 and p.hi or p.base)) end
  end
  ellipse(g, 26, 26, 4, 5, p.out); ellipse(g, 40, 26, 4, 5, p.out)
  eyeP(g, 26, 26, 2, p); eyeP(g, 40, 26, 2, p)
  polygon(g, { { 31, 34 }, { 35, 34 }, { 33, 40 } }, p.out)
  rect(g, 25, 40, 16, 5, p.base)
  for i = 0, 5 do line(g, 27 + i * 2.4, 40, 27 + i * 2.4, 45, p.deep) end
  for i = 0, 4 do rstreak(g, 20 + i * 6, 18, 4, p.deep, rnd) end
  return { head = { x = 33, y = 26, r = 8 }, faceDir = { 0, -1 }, spine = { { 33, 20 }, { 33, 38 } },
    limbs = {}, belly = { x = 33, y = 38 }, mass = { { 33, 28, 15 } }, tailBase = nil, flesh = false }
end
-- archetypes : AUTOMATE (mécanique rivetée, noyau luisant)
function ARCH.aAutomaton(g, rnd, p)
  rect(g, 27, 44, 5, 12, p.sh); rect(g, 34, 44, 5, 12, p.sh)
  rect(g, 26, 55, 7, 2, p.deep); rect(g, 34, 55, 7, 2, p.deep)
  rect(g, 24, 26, 18, 18, p.base); rect(g, 24, 26, 18, 2, p.hi); rect(g, 24, 26, 4, 18, p.sh)
  disc(g, 33, 35, 5, p.deep); disc(g, 33, 35, 3, p.eye)
  for a = 0, 7 do local an = a / 8 * 6.283; set(g, round(33 + cos(an) * 5), round(35 + sin(an) * 5), p.bone) end
  rect(g, 19, 28, 5, 14, p.sh); rect(g, 42, 28, 5, 14, p.sh)
  disc(g, 21, 43, 2, p.deep); disc(g, 44, 43, 2, p.deep)
  for i = 0, 2 do set(g, 26 + i * 5, 28, p.bone); set(g, 26 + i * 5, 42, p.bone) end
  rect(g, 29, 16, 8, 10, p.base); rect(g, 29, 16, 8, 2, p.hi); rect(g, 31, 20, 4, 2, p.eye)
  line(g, 28, 15, 30, 11, p.sh); line(g, 38, 15, 36, 11, p.sh)
  return { head = { x = 33, y = 20, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 26 }, { 33, 40 } },
    limbs = { { 21, 43 }, { 44, 43 }, { 28, 56 }, { 36, 56 } }, belly = { x = 33, y = 35 }, mass = { { 33, 35, 8 } }, tailBase = nil, flesh = false }
end
function ARCH.aReliquary(g, rnd, p)
  tube(g, { { 28, 46 }, { 27, 55 } }, 2, 2, p.sh); tube(g, { { 38, 46 }, { 39, 55 } }, 2, 2, p.sh)
  disc(g, 27, 55, 2, p.deep); disc(g, 39, 55, 2, p.deep)
  rect(g, 25, 28, 16, 18, p.base); rect(g, 25, 28, 16, 2, p.hi); rect(g, 25, 28, 3, 18, p.sh)
  polygon(g, { { 24, 28 }, { 42, 28 }, { 38, 22 }, { 28, 22 } }, p.base)
  line(g, 33, 22, 33, 46, p.bone); line(g, 28, 34, 38, 34, p.bone)
  disc(g, 33, 38, 3, p.deep); disc(g, 33, 38, 2, p.eye)
  for a = 0, 7 do local an = a / 8 * 6.283; line(g, 33, 38, round(33 + cos(an) * 6), round(38 + sin(an) * 6), p.hi) end
  tube(g, { { 25, 32 }, { 20, 36 }, { 20, 42 } }, 2, 2, p.sh); tube(g, { { 41, 32 }, { 46, 36 }, { 46, 42 } }, 2, 2, p.sh)
  mass(g, 33, 17, 4, 4, p); ellipse(g, 33, 17, 3, 3, p.hi); set(g, 31, 17, p.deep); set(g, 35, 17, p.deep)
  halo(g, 33, 10, 6, p)
  return { head = { x = 33, y = 17, r = 4 }, faceDir = { 0, -1 }, spine = { { 33, 24 }, { 33, 40 } },
    limbs = { { 20, 42 }, { 46, 42 } }, belly = { x = 33, y = 38 }, mass = { { 33, 36, 9 } }, tailBase = nil, flesh = false, halo = true }
end
-- ═══════════════════ B.2 : 4 VARIANTES COCON + 6 PIÈCES ELDER (port direct du HTML v3) ═══════════════════
-- Portées 1:1 depuis docs/generation/generateur-bestiaire.html (l.264-366). RNG INTERNE au builder (n'altère
-- pas la séquence des autres). Anatomie `A` IDENTIQUE à la source. eye() HTML -> eyeP() Lua ; arrays 0-idx JS
-- -> 1-idx Lua ; ternaire JS -> and/or. Les 4 cocon REMPLACENT le `aCocoon` générique (formes distinctes par
-- unité : witch/miasma/plague_bearer/venom_censer). Les 6 ELDER (imp 10) = pièces maîtresses de leur famille.

-- ── COCON : broodsac (sac d'œufs, fente lumineuse, bosses) ──
function ARCH.aCocoonBrood(g, rnd, p)
  for y = 16, 52 do
    local t = (y - 16) / 36
    local w = round(10 * sin(t * 3.14) * 0.78 + 3 + t * 2)
    for x = -w, w do set(g, 33 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  mass(g, 27, 40, 3, 3, p); mass(g, 39, 44, 3, 3, p); mass(g, 36, 26, 2, 2, p)
  for s = 0, 4 do local sy = 20 + s * 7; line(g, 24, sy, 42, sy - 3, p.deep) end
  for y = 28, 38 do
    set(g, 33, y, p.deep)
    if y % 3 == 0 then set(g, 32, y, p.eyeDim); set(g, 34, y, p.eyeDim) end
  end
  eyeP(g, 33, 32, 1, p)
  return { head = { x = 33, y = 32, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 22 }, { 33, 46 } },
    limbs = {}, belly = { x = 33, y = 36 }, mass = { { 33, 36, 11 } }, tailBase = nil, flesh = true }
end
-- ── COCON : bilesac (sac de bile, gouttes pendantes, gueule) ──
function ARCH.aCocoonBile(g, rnd, p)
  for y = 14, 50 do
    local t = (y - 14) / 36
    local w = round(5 + 9 * sin(min(1, t * 1.15) * 2.4)); if w < 2 then w = 2 end
    for x = -w, w do set(g, 33 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  for d = 0, 3 do
    local dx = 26 + d * 5
    tube(g, { { dx, 49 }, { dx - 1, 53 + (d % 2) * 2 } }, 2, 1, p.sh); disc(g, dx - 1, 55 + (d % 2), 1, p.eye)
  end
  maw(g, 33, 46, 3, p)
  for y = 20, 42 do
    set(g, 33, y, p.deep)
    if y % 2 == 0 then set(g, 32, y, p.eye); set(g, 34, y, p.eye) end
  end
  eyeP(g, 28, 28, 2, p); eyeP(g, 38, 28, 2, p); line(g, 25, 24, 41, 22, p.deep); line(g, 24, 34, 42, 33, p.deep)
  return { head = { x = 33, y = 30, r = 6 }, faceDir = { 0, -1 }, spine = { { 33, 20 }, { 33, 44 } },
    limbs = {}, belly = { x = 33, y = 40 }, mass = { { 33, 34, 12 } }, tailBase = nil, flesh = true }
end
-- ── COCON : chrysalis (chrysalide nervurée sur tige, bec percé) ──
function ARCH.aCocoonChrysalis(g, rnd, p)
  tube(g, { { 33, 3 }, { 33, 12 } }, 1, 1, p.sh)
  for y = 12, 50 do
    local t = (y - 12) / 38
    local w = round(9 * sin(t * 3.14 * 0.92) * (1 - t * 0.35) + 2); if w < 1 then w = 1 end
    for x = -w, w do set(g, 33 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  for s = 0, 6 do
    local sy = 22 + s * 4
    for x = -8, 8 do
      local yy = sy + round(math.abs(x) * 0.25)
      if g.data[yy * g.w + (33 + x)] ~= nil then set(g, 33 + x, yy, p.deep) end
    end
  end
  for y = 14, 22 do set(g, 33, y, p.deep); set(g, 32, y, p.eyeDim); set(g, 34, y, p.eyeDim) end
  eyeP(g, 31, 18, 1, p); eyeP(g, 35, 18, 1, p); polygon(g, { { 33, 16 }, { 37, 13 }, { 35, 18 } }, p.bone)
  for w2 = 0, 2 do
    local xx = 28 + w2 * 5
    for y = 28, 46 do
      if g.data[y * g.w + xx] ~= nil then set(g, xx, y, (y % 4 == 0) and p.eye or p.eyeDim) end
    end
  end
  return { head = { x = 33, y = 18, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 16 }, { 33, 40 } },
    limbs = {}, belly = { x = 33, y = 34 }, mass = { { 33, 32, 10 } }, tailBase = nil, flesh = true }
end
-- ── COCON : embersac (cocon-brasier, runes en pointillé `gl`, bras épineux + tentacules) — pièce maîtresse imp 9 ──
function ARCH.aCocoonEmber(g, rnd, p)
  for y = 12, 54 do
    local t = (y - 12) / 42
    local w = round(12 * sin(t * 3.14) * 0.92 + 3)
    for x = -w, w do set(g, 33 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  for s = 0, 7 do local sy = 16 + s * 5; line(g, 21, sy, 45, sy - 3, p.deep); line(g, 21, sy + 2, 45, sy + 5, p.deep) end
  -- `gl` : trace une rune en pointillé eye/eyeDim, UNIQUEMENT sur les pixels déjà plein (closure du HTML l.289).
  local function gl(x0, y0, x1, y1)
    local dxx, dyy = math.abs(x1 - x0), math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1; local sy2 = y0 < y1 and 1 or -1
    local err, n = dxx - dyy, 0
    while true do
      if g.data[y0 * g.w + x0] ~= nil then set(g, x0, y0, (n % 2 == 0) and p.eye or p.eyeDim) end
      if x0 == x1 and y0 == y1 then break end
      local e2 = 2 * err
      if e2 > -dyy then err = err - dyy; x0 = x0 + sx end
      if e2 < dxx then err = err + dxx; y0 = y0 + sy2 end
      n = n + 1
    end
  end
  gl(33, 18, 33, 48)
  local br = { { 33, 24, 24, 18 }, { 33, 30, 43, 26 }, { 33, 36, 23, 40 }, { 33, 42, 43, 46 }, { 33, 28, 40, 34 } }
  for b = 1, #br do gl(br[b][1], br[b][2], br[b][3], br[b][4]) end
  for y = 26, 40, 2 do set(g, 33, y, p.hi) end
  eyeP(g, 28, 26, 2, p); eyeP(g, 38, 28, 2, p); eyeP(g, 33, 38, 1, p); eyeP(g, 30, 44, 1, p)
  tube(g, { { 22, 34 }, { 16, 30 }, { 12, 24 } }, 2, 1, p.sh); polygon(g, { { 12, 24 }, { 8, 22 }, { 11, 20 } }, p.bone); polygon(g, { { 12, 24 }, { 9, 26 }, { 13, 27 } }, p.bone)
  tube(g, { { 44, 36 }, { 50, 32 }, { 54, 26 } }, 2, 1, p.sh); polygon(g, { { 54, 26 }, { 58, 24 }, { 55, 22 } }, p.bone); polygon(g, { { 54, 26 }, { 57, 28 }, { 53, 29 } }, p.bone)
  tentacle(g, 26, 52, 10, -0.4, 3, 2, 1, p.sh); tentacle(g, 33, 53, 12, 0, 2, 2, 1, p.sh); tentacle(g, 40, 52, 10, 0.4, 3, 2, 1, p.sh)
  polygon(g, { { 28, 12 }, { 33, 8 }, { 33, 14 } }, p.sh); polygon(g, { { 38, 12 }, { 33, 8 }, { 33, 14 } }, p.sh)
  return { head = { x = 33, y = 32, r = 8 }, faceDir = { 0, -1 }, spine = { { 33, 16 }, { 33, 34 }, { 33, 48 } },
    limbs = { { 12, 24 }, { 54, 26 }, { 26, 58 }, { 40, 58 } }, belly = { x = 33, y = 38 }, mass = { { 33, 34, 13 } }, tailBase = nil, flesh = true }
end

-- ── OMBRE : voidtyrant (silhouette noire massive, bouquet de tentacules, banc d'yeux flottants) — imp 10 ──
function ARCH.aVoidTyrant(g, rnd, p)
  for i = 0, 4 do local ta = (i - 2) * 0.5; tentacle(g, 32 + (i - 2) * 3, 40, 16, ta, 4, 3, 1, p.base) end
  tentacle(g, 24, 28, 16, -1.3, 5, 3, 1, p.base); tentacle(g, 40, 28, 16, 1.3, 5, 3, 1, p.base)
  for y = 12, 42 do
    local t = (y - 12) / 30
    local w = round(5 + 9 * sin(t * 3.14 * 0.92))
    for x = -w, w do set(g, 32 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
  end
  polygon(g, { { 18, 30 }, { 23, 24 }, { 24, 34 } }, p.base); polygon(g, { { 46, 30 }, { 41, 24 }, { 40, 34 } }, p.base)
  polygon(g, { { 32, 5 }, { 25, 18 }, { 39, 18 } }, p.base); polygon(g, { { 32, 7 }, { 28, 16 }, { 36, 16 } }, p.sh)
  set(g, 24, 26, p.bone); set(g, 40, 26, p.bone); set(g, 27, 20, p.bone); set(g, 37, 20, p.bone)
  disc(g, 32, 30, 6, p.out); disc(g, 32, 30, 4, p.deep)
  for an = 0, 9 do local a2 = an / 10 * 6.283; set(g, round(32 + cos(a2) * 6), round(30 + sin(a2) * 6), p.eyeDim) end
  maw(g, 32, 31, 4, p)
  local es = { { 27, 22 }, { 37, 22 }, { 32, 15 }, { 24, 28 }, { 40, 28 }, { 29, 36 }, { 35, 36 }, { 20, 20 }, { 44, 22 } }
  for i = 1, #es do eyeP(g, es[i][1], es[i][2], i <= 4 and 2 or 1, p) end
  for i = 0, 5 do local cx2 = 21 + i * 4; polygon(g, { { cx2, 41 }, { cx2 + 2, 41 }, { cx2 + 1, 45 + ((i * 5) % 4) } }, p.base) end
  return { head = { x = 32, y = 18, r = 7 }, faceDir = { 0, -1 }, spine = { { 32, 14 }, { 32, 28 }, { 32, 40 } },
    limbs = { { 10, 32 }, { 54, 32 } }, belly = { x = 32, y = 34 }, mass = { { 32, 30, 11 }, { 32, 16, 5 } }, tailBase = nil, flesh = false }
end
-- ── LARVE : devourer (grub colossal en C segmenté, gueule latérale, pattes) — imp 10 ──
function ARCH.aGrubElder(g, rnd, p)
  local pts = {}
  for i = 0, 9 do
    local t = i / 9; local ang = 3.14 * 0.12 + t * 3.14 * 1.15
    pts[#pts + 1] = { round(33 + cos(ang) * 16), round(38 + sin(ang) * 14) }
  end
  segChain(g, pts, 7, 4, p)
  for i = 2, #pts do line(g, pts[i][1], pts[i][2] - 4, pts[i][1], pts[i][2] + 4, p.deep) end
  for i = 2, #pts - 1 do
    tube(g, { { pts[i][1], pts[i][2] + 4 }, { pts[i][1] - 2, pts[i][2] + 8 } }, 1, 1, p.sh)
    tube(g, { { pts[i][1], pts[i][2] + 4 }, { pts[i][1] + 2, pts[i][2] + 8 } }, 1, 1, p.sh)
  end
  for i = 2, #pts - 1 do tube(g, { { pts[i][1], pts[i][2] - 5 }, { pts[i][1] + 1, pts[i][2] - 9 } }, 1, 1, p.deep) end
  maw(g, pts[4][1], pts[4][2], 2, p); maw(g, pts[7][1], pts[7][2], 2, p)
  local hx, hy = pts[1][1], pts[1][2]
  mass(g, hx, hy, 6, 5, p)
  polygon(g, { { hx + 3, hy - 3 }, { hx + 9, hy - 6 }, { hx + 5, hy - 1 } }, p.bone); polygon(g, { { hx + 3, hy + 3 }, { hx + 9, hy + 6 }, { hx + 5, hy + 1 } }, p.bone)
  maw(g, hx + 2, hy, 3, p); eyeP(g, hx, hy - 2, 1, p); eyeP(g, hx + 2, hy - 3, 1, p); eyeP(g, hx - 1, hy + 1, 1, p); eyeP(g, hx + 3, hy, 1, p)
  return { head = { x = hx, y = hy, r = 6 }, faceDir = { 1, 0 }, spine = { { 33, 28 }, { 33, 42 } },
    limbs = {}, belly = { x = 33, y = 42 }, mass = { { 33, 40, 14 } }, tailBase = nil, flesh = true }
end
-- ── CRÂNE : skulltitan (crâne titanesque, cornes, orbites-rayon, mâchoire dentée) — imp 10 ──
function ARCH.aSkullTitan(g, rnd, p)
  for y = -18, 12 do
    local w = round(18 * sqrt(max(0, 1 - (y * y) / (y < 0 and 324 or 160))))
    for x = -w, w do set(g, 33 + x, 30 + y, math.abs(x) > w - 1 and p.deep or (y < -8 and p.hi or p.base)) end
  end
  tube(g, { { 18, 16 }, { 12, 6 }, { 10, -2 } }, 3, 1, p.bone); tube(g, { { 48, 16 }, { 54, 6 }, { 56, -2 } }, 3, 1, p.bone)
  for i = 0, 4 do local cxp = 22 + i * 5; polygon(g, { { cxp, 14 }, { cxp + 2, 14 }, { cxp + 1, 8 - ((i % 2) * 3) } }, p.bone) end
  ellipse(g, 25, 26, 5, 6, p.out); ellipse(g, 41, 26, 5, 6, p.out); eyeP(g, 25, 26, 2, p); eyeP(g, 41, 26, 2, p); eyeP(g, 24, 29, 1, p); eyeP(g, 42, 29, 1, p)
  polygon(g, { { 30, 34 }, { 36, 34 }, { 33, 42 } }, p.out)
  rect(g, 24, 42, 18, 6, p.deep); for i = 0, 6 do line(g, round(26 + i * 2.4), 42, round(26 + i * 2.4), 47, p.bone) end
  for i = 0, 5 do set(g, round(27 + i * 2.5), 40, p.eye) end
  for i = 0, 5 do rstreak(g, 18 + i * 6, 16, 5, p.eye, rnd) end
  polygon(g, { { 14, 30 }, { 12, 28 }, { 15, 27 } }, p.bone); polygon(g, { { 52, 32 }, { 55, 30 }, { 53, 34 } }, p.bone)
  return { head = { x = 33, y = 24, r = 9 }, faceDir = { 0, -1 }, spine = { { 33, 18 }, { 33, 36 } },
    limbs = {}, belly = { x = 33, y = 38 }, mass = { { 33, 26, 16 } }, tailBase = nil, flesh = false }
end
-- ── AUTOMATE : juggernaut (carcasse mécanique lourde, noyau, bras-pistons) — imp 10 ──
function ARCH.aJuggernaut(g, rnd, p)
  rect(g, 24, 46, 7, 10, p.sh); rect(g, 36, 46, 7, 10, p.sh); rect(g, 23, 55, 9, 2, p.deep); rect(g, 35, 55, 9, 2, p.deep)
  for i = 0, 1 do set(g, 26, 48 + i * 4, p.eyeDim); set(g, 40, 48 + i * 4, p.eyeDim) end
  rect(g, 21, 24, 24, 22, p.base); rect(g, 21, 24, 24, 3, p.hi); rect(g, 21, 24, 4, 22, p.sh); rect(g, 21, 43, 24, 3, p.deep)
  for i = 0, 4 do set(g, 24 + i * 4, 27, p.bone); set(g, 24 + i * 4, 42, p.bone) end
  disc(g, 33, 35, 6, p.deep); disc(g, 33, 35, 4, p.eye); disc(g, 33, 35, 2, p.hi)
  for an = 0, 7 do local a2 = an / 8 * 6.283; set(g, round(33 + cos(a2) * 6), round(35 + sin(a2) * 6), p.bone) end
  tube(g, { { 21, 28 }, { 14, 32 }, { 10, 38 } }, 3, 2, p.sh); polygon(g, { { 10, 38 }, { 6, 40 }, { 9, 42 } }, p.bone); polygon(g, { { 10, 38 }, { 7, 36 }, { 6, 34 } }, p.bone)
  tube(g, { { 45, 28 }, { 52, 32 }, { 56, 38 } }, 3, 2, p.sh); polygon(g, { { 56, 38 }, { 60, 40 }, { 57, 42 } }, p.bone); polygon(g, { { 56, 38 }, { 59, 36 }, { 60, 34 } }, p.bone)
  tube(g, { { 22, 38 }, { 16, 42 }, { 14, 48 } }, 2, 2, p.sh); tube(g, { { 44, 38 }, { 50, 42 }, { 52, 48 } }, 2, 2, p.sh)
  rect(g, 28, 14, 10, 10, p.base); rect(g, 28, 14, 10, 2, p.hi); rect(g, 30, 18, 6, 3, p.eye)
  tube(g, { { 29, 14 }, { 26, 8 } }, 1, 1, p.sh); tube(g, { { 37, 14 }, { 40, 8 } }, 1, 1, p.sh)
  for i = 0, 2 do set(g, 26, 30 + i * 3, p.eye); set(g, 40, 30 + i * 3, p.eye) end
  return { head = { x = 33, y = 19, r = 5 }, faceDir = { 0, -1 }, spine = { { 33, 24 }, { 33, 40 } },
    limbs = { { 10, 38 }, { 56, 38 }, { 14, 48 }, { 52, 48 } }, belly = { x = 33, y = 35 }, mass = { { 33, 35, 12 } }, tailBase = nil, flesh = false }
end
-- ── SPECTRE : veiledking (roi voilé, couronne, voile qui se dissout en bas, mains spectrales) — imp 10 ──
function ARCH.aVeiledKing(g, rnd, p)
  for y = 12, 50 do
    local t = (y - 12) / 38
    local w = round(4 + 8 * sin(min(1, t) * 3.14 * 0.8) + (t > 0.7 and (t - 0.7) * 6 or 0))
    for x = -w, w do
      if not (t > 0.78 and ((x + y) % 2 == 0)) then set(g, 32 + x, y, math.abs(x) > w - 1 and p.sh or p.base) end
    end
  end
  polygon(g, { { 32, 8 }, { 23, 22 }, { 41, 22 } }, p.base); polygon(g, { { 32, 8 }, { 26, 20 }, { 38, 20 } }, p.sh)
  for i = 0, 4 do local cxp = 24 + i * 4; polygon(g, { { cxp, 12 }, { cxp + 2, 12 }, { cxp + 1, 7 - ((i % 2) * 2) } }, p.bone) end
  ellipse(g, 28, 22, 3, 4, p.out); ellipse(g, 36, 22, 3, 4, p.out); eyeP(g, 28, 22, 2, p); eyeP(g, 36, 22, 2, p)
  tube(g, { { 24, 28 }, { 16, 30 }, { 10, 36 } }, 3, 1, p.sh); tube(g, { { 40, 28 }, { 48, 30 }, { 54, 36 } }, 3, 1, p.sh)
  for i = 0, 2 do tube(g, { { 10, 36 }, { 7 + i, 40 + i } }, 1, 1, p.hi); tube(g, { { 54, 36 }, { 57 - i, 40 + i } }, 1, 1, p.hi) end
  for i = 0, 3 do set(g, 26 + i * 4, 10 - ((i * 3) % 5), p.hi) end
  for i = 0, 5 do local bx = 22 + i * 4; tube(g, { { bx, 48 }, { bx + ((i % 2 == 1) and 1 or -1), 54 + ((i * 3) % 4) } }, 1, 1, p.sh) end
  return { head = { x = 32, y = 22, r = 6 }, faceDir = { 0, -1 }, spine = { { 32, 16 }, { 32, 32 }, { 32, 46 } },
    limbs = { { 10, 36 }, { 54, 36 } }, belly = { x = 32, y = 34 }, mass = { { 32, 26, 10 } }, tailBase = nil, flesh = false }
end
-- ── ARACHNIDE : broodmother (abdomen + céphalothorax, 8 pattes en arches, banc d'yeux, chélicères, œufs) — imp 10 ──
function ARCH.aBroodmother(g, rnd, p)
  mass(g, 33, 26, 11, 10, p)
  for i = 0, 5 do local ang = i / 6 * 6.283; set(g, round(33 + cos(ang) * 5), round(26 + sin(ang) * 5), p.eyeDim) end
  disc(g, 33, 26, 2, p.deep); mass(g, 33, 42, 8, 6, p)
  local legY = { { 40, 33, 42 }, { 42, 37, 48 }, { 44, 41, 53 }, { 46, 45, 56 } }
  local legX = { { 27, 16, 7 }, { 27, 15, 6 }, { 28, 16, 8 }, { 28, 18, 11 } }
  for i = 1, 4 do
    tube(g, { { legX[i][1], legY[i][1] }, { legX[i][2], legY[i][2] }, { legX[i][3], legY[i][3] } }, 2, 1, p.sh)
    tube(g, { { 66 - legX[i][1], legY[i][1] }, { 66 - legX[i][2], legY[i][2] }, { 66 - legX[i][3], legY[i][3] } }, 2, 1, p.sh)
  end
  local es = { { 30, 40 }, { 36, 40 }, { 28, 42 }, { 38, 42 }, { 31, 43 }, { 35, 43 }, { 33, 39 } }
  for i = 1, #es do eyeP(g, es[i][1], es[i][2], 1, p) end
  polygon(g, { { 30, 47 }, { 28, 52 }, { 32, 49 } }, p.bone); polygon(g, { { 36, 47 }, { 38, 52 }, { 34, 49 } }, p.bone)
  for i = 0, 4 do set(g, round(28 + i * 2.5), 20, p.deep) end
  return { head = { x = 33, y = 42, r = 6 }, faceDir = { 0, 1 }, spine = { { 33, 34 }, { 33, 44 } },
    limbs = { { 8, 46 }, { 58, 46 }, { 10, 50 }, { 56, 50 } }, belly = { x = 33, y = 44 }, mass = { { 33, 30, 12 }, { 33, 42, 6 } }, tailBase = nil, flesh = true }
end

-- traitements V6b
function TREAT.treatHung(g, rnd, p, A)
  local lim = A.limbs
  for i = 1, #lim do
    if rnd() < 0.5 then local L = lim[i]; line(g, L[1], L[2], L[1] + round((rnd() - 0.5) * 4), L[2] + 4 + floor(rnd() * 4), p.sh) end
  end
  local m = A.mass[1]
  for _ = 1, 3 do local pt = onMass(rnd, m); if rnd() < 0.5 then set(g, pt[1], pt[2], p.deep) end end
  for _ = 1, 2 do local q = onMass(rnd, m); set(g, q[1], q[2] + m[3], p.sh) end
  if rnd() < 0.5 then set(g, A.head.x, A.head.y, p.eye) end
end
function TREAT.treatPod(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 3 do
    local yy = m[2] - m[3] + floor(rnd() * m[3] * 2); local xx = m[1] + round((rnd() - 0.5) * m[3])
    line(g, xx, yy, xx + round((rnd() - 0.5) * 4), yy + 2, p.eye)
  end
  for _ = 1, 4 do local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.deep) end
  for _ = 1, 2 do local ox = m[1] + round((rnd() - 0.5) * 6); tube(g, { { ox, m[2] + m[3] }, { ox + 1, m[2] + m[3] + 6 } }, 1, 1, p.eye) end
end
function TREAT.treatFlora(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 4 do
    local an = rnd() * 6.283; local bx = m[1] + round(cos(an) * m[3]); local by = m[2] + round(sin(an) * m[3])
    tube(g, { { bx, by }, { bx + round(cos(an) * 5), by + round(sin(an) * 5) } }, 1, 1, p.sh)
  end
  for _ = 1, 6 do local pt = onMass(rnd, m); set(g, pt[1] + round((rnd() - 0.5) * 8), pt[2] - floor(rnd() * 6), p.hi) end
  for _ = 1, 3 do local q = onMass(rnd, m); polygon(g, { { q[1], q[2] }, { q[1] + 2, q[2] - 1 }, { q[1], q[2] - 3 } }, p.bone) end
end
function TREAT.treatBone(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 4 do local pt = onMass(rnd, m); rstreak(g, pt[1], pt[2], 3, p.deep, rnd) end
  eyeP(g, A.head.x - 7, A.head.y - 2, 1, p); eyeP(g, A.head.x + 7, A.head.y - 2, 1, p)
  for _ = 1, 5 do local q = onMass(rnd, m); if rnd() < 0.4 then set(g, q[1], q[2], p.sh) end end
  if rnd() < 0.5 then set(g, m[1] - 5, m[2] + m[3] - 2, p.eye); set(g, m[1] + 5, m[2] + m[3] - 3, p.eye) end
end
function TREAT.treatRust(g, rnd, p, A)
  local m = A.mass[1]
  for _ = 1, 4 do
    local pt = onMass(rnd, m); set(g, pt[1], pt[2], p.eyeDim); set(g, pt[1], pt[2] + 1, p.eyeDim)
    if rnd() < 0.5 then set(g, pt[1], pt[2] + 2, p.eyeDim) end
  end
  for _ = 1, 3 do local q = onMass(rnd, m); if rnd() < 0.5 then set(g, q[1], q[2], p.out) end end
  for _ = 1, 3 do local e = onMass(rnd, m); if rnd() < 0.4 then set(g, e[1], e[2], p.eye) end end
  if rnd() < 0.5 then set(g, m[1], m[2], p.eye); set(g, m[2] + 1, m[2], p.hi) end
end

-- ─────────────────────────── Familles (palette + archetypes EXCLUSIFS + treat) ───────────────────────────
local FAMILIES = {
  cauchemar = { pals = ELDRITCH, treat = TREAT.treatEldritch, archs = {
    { name = "bouffi", fn = ARCH.aBouffi }, { name = "pendu", fn = ARCH.aPendu }, { name = "fleshcrawler", fn = ARCH.aFleshCrawler } } },
  mortvivant = { pals = UNDEAD, treat = TREAT.treatUndead, archs = {
    { name = "skeleton", fn = ARCH.aSkeleton }, { name = "skeletonquad", fn = ARCH.aSkeletonQuad }, { name = "revenant", fn = ARCH.aRevenant } } },
  bete = { pals = BEAST, treat = TREAT.treatBeast, archs = {
    { name = "dragon", fn = ARCH.aDragon }, { name = "behemoth", fn = ARCH.aBehemoth }, { name = "direcat", fn = ARCH.aDirecat } } },
  demon = { pals = DEMON, treat = TREAT.treatDemon, archs = {
    { name = "fiend", fn = ARCH.aFiend }, { name = "serpent", fn = ARCH.aSerpent }, { name = "imp", fn = ARCH.aImp } } },
  insecte = { pals = INSECT, treat = TREAT.treatInsect, archs = {
    { name = "insectoid", fn = ARCH.aInsectoid }, { name = "mantis", fn = ARCH.aMantis } } },
  -- ── V1 ténèbres part A ──
  cephalo = { pals = CEPHALO, treat = TREAT.treatCephalo, archs = {
    { name = "octopus", fn = ARCH.aOctopus }, { name = "squid", fn = ARCH.aSquid }, { name = "reef", fn = ARCH.aReef } } },
  gelatine = { pals = GELATIN, treat = TREAT.treatGelatin, archs = {
    { name = "slime", fn = ARCH.aSlime }, { name = "ooze", fn = ARCH.aOoze }, { name = "blobmonster", fn = ARCH.aBlobMonster } } },
  oeil = { pals = EYEPAL, treat = TREAT.treatEye, archs = {
    { name = "eyeball", fn = ARCH.aEyeball }, { name = "eyecluster", fn = ARCH.aEyeCluster }, { name = "eyeswarm", fn = ARCH.aEyeSwarm } } },
  spore = { pals = SPORE, treat = TREAT.treatSpore, archs = {
    { name = "sporewalker", fn = ARCH.aSporeWalker }, { name = "myconid", fn = ARCH.aMyconid }, { name = "infectedhost", fn = ARCH.aInfectedHost } } },
  ombre = { pals = SHADOW, treat = TREAT.treatShadow, archs = {
    { name = "shade", fn = ARCH.aShade }, { name = "voidmaw", fn = ARCH.aVoidMaw },
    { name = "voidtyrant", fn = ARCH.aVoidTyrant } } }, -- ELDER imp 10 (append-only ; PIN par nom -> golden-safe)
  essaim = { pals = SWARM, treat = TREAT.treatSwarm, archs = {
    { name = "swarm", fn = ARCH.aSwarm }, { name = "hive", fn = ARCH.aHive } } },
  annelide = { pals = WORM, treat = TREAT.treatWorm, archs = {
    { name = "graboid", fn = ARCH.aGraboid }, { name = "leech", fn = ARCH.aLeech } } },
  -- ── V2 ténèbres part B ──
  golem = { pals = GOLEM, treat = TREAT.treatGolem, archs = {
    { name = "golem", fn = ARCH.aGolem }, { name = "sentinel", fn = ARCH.aSentinel }, { name = "idol", fn = ARCH.aIdol } } },
  spectre = { pals = SPECTRE, treat = TREAT.treatSpectre, archs = {
    { name = "wraith", fn = ARCH.aWraith }, { name = "veiledlady", fn = ARCH.aVeiledLady },
    { name = "veiledking", fn = ARCH.aVeiledKing } } }, -- ELDER imp 10
  culte = { pals = CULT, treat = TREAT.treatCult, archs = {
    { name = "cultist", fn = ARCH.aCultist }, { name = "hierophant", fn = ARCH.aHierophant }, { name = "possessed", fn = ARCH.aPossessed } } },
  abyssal = { pals = ABYSSAL, treat = TREAT.treatAbyssal, archs = {
    { name = "anglerfish", fn = ARCH.aAnglerfish }, { name = "deepone", fn = ARCH.aDeepOne }, { name = "moray", fn = ARCH.aMoray } } },
  cristal = { pals = CRYSTAL, treat = TREAT.treatCrystalline, archs = {
    { name = "crystalcluster", fn = ARCH.aCrystalCluster }, { name = "shardwalker", fn = ARCH.aShardWalker }, { name = "prism", fn = ARCH.aPrism } } },
  aile = { pals = WINGED, treat = TREAT.treatWinged, archs = {
    { name = "byakhee", fn = ARCH.aByakhee }, { name = "harpy", fn = ARCH.aHarpy } } },
  colosse = { pals = COLOSSUS, treat = TREAT.treatColossus, archs = {
    { name = "ogre", fn = ARCH.aOgre }, { name = "cyclops", fn = ARCH.aCyclops } } },
  -- ── V4 lumière/Inquisition ──
  templier = { pals = LUMEN, treat = TREAT.treatCorrupt, archs = {
    { name = "crusader", fn = ARCH.aCrusader }, { name = "sentinelshield", fn = ARCH.aSentinelShield }, { name = "paladin", fn = ARCH.aPaladin } } },
  inquisiteur = { pals = INQUIS, treat = TREAT.treatCorrupt, archs = {
    { name = "inquisitor", fn = ARCH.aInquisitor }, { name = "zealot", fn = ARCH.aZealot }, { name = "confessor", fn = ARCH.aConfessor } } },
  seraphin = { pals = SERAPH, treat = TREAT.treatCorrupt, archs = {
    { name = "seraph", fn = ARCH.aSeraph }, { name = "throne", fn = ARCH.aThrone } } },
  griffon = { pals = GRYPHON, treat = TREAT.treatCorrupt, archs = {
    { name = "gryphon", fn = ARCH.aGryphon }, { name = "hippogriff", fn = ARCH.aHippogriff } } },
  -- ── V5 gredins + bêtes classiques ──
  bandit = { pals = BANDIT, treat = TREAT.treatGrime, archs = {
    { name = "cutthroat", fn = ARCH.aCutthroat }, { name = "brigand", fn = ARCH.aBrigand }, { name = "cutpurse", fn = ARCH.aCutpurse } } },
  canide = { pals = CANID, treat = TREAT.treatFeral, archs = {
    { name = "wolf", fn = ARCH.aWolf }, { name = "hound", fn = ARCH.aHound }, { name = "jackal", fn = ARCH.aJackal } } },
  reptile = { pals = REPTILE, treat = TREAT.treatFeral, archs = {
    { name = "coilserpent", fn = ARCH.aCoilSerpent }, { name = "cobra", fn = ARCH.aCobra }, { name = "lizard", fn = ARCH.aLizard } } },
  rongeur = { pals = RODENT, treat = TREAT.treatFeral, archs = {
    { name = "ratgiant", fn = ARCH.aRatGiant }, { name = "ratking", fn = ARCH.aRatKing } } },
  -- ── V6 vivier ──
  arachnide = { pals = SPIDER, treat = TREAT.treatChitin, archs = {
    { name = "spider", fn = ARCH.aSpider }, { name = "widow", fn = ARCH.aWidow },
    { name = "broodmother", fn = ARCH.aBroodmother } } }, -- ELDER imp 10
  crustace = { pals = CRUST, treat = TREAT.treatChitin, archs = {
    { name = "crab", fn = ARCH.aCrab }, { name = "mantisshrimp", fn = ARCH.aMantisShrimp } } },
  meduse = { pals = JELLY, treat = TREAT.treatDrift, archs = {
    { name = "jelly", fn = ARCH.aJelly }, { name = "siphon", fn = ARCH.aSiphon } } },
  echassier = { pals = STILT, treat = TREAT.treatGaunt, archs = {
    { name = "strider", fn = ARCH.aStrider }, { name = "heron", fn = ARCH.aHeron } } },
  wendigo = { pals = WENDIGO, treat = TREAT.treatGaunt, archs = {
    { name = "wendigo", fn = ARCH.aWendigo }, { name = "stag", fn = ARCH.aStag } } },
  hydre = { pals = HYDRA, treat = TREAT.treatMany, archs = {
    { name = "hydra", fn = ARCH.aHydra } } },
  kraken = { pals = KRAKEN, treat = TREAT.treatMany, archs = {
    { name = "kraken", fn = ARCH.aKraken } } },
  pendu = { pals = PUPPET, treat = TREAT.treatHung, archs = {
    { name = "marionette", fn = ARCH.aMarionette }, { name = "hanged", fn = ARCH.aHanged } } },
  chimere = { pals = CHIMERA, treat = TREAT.treatMany, archs = {
    { name = "chimera", fn = ARCH.aChimera } } },
  cocon = { pals = COCOON, treat = TREAT.treatPod, archs = { -- 4 formes distinctes (remplacent aCocoon générique) :
    { name = "broodsac", fn = ARCH.aCocoonBrood }, { name = "bilesac", fn = ARCH.aCocoonBile },
    { name = "chrysalis", fn = ARCH.aCocoonChrysalis }, { name = "embersac", fn = ARCH.aCocoonEmber } } },
  plante = { pals = FLORA, treat = TREAT.treatFlora, archs = {
    { name = "maweed", fn = ARCH.aMaweed }, { name = "vinemaw", fn = ARCH.aVinemaw } } },
  larve = { pals = GRUB, treat = TREAT.treatFeral, archs = {
    { name = "grub", fn = ARCH.aGrub }, { name = "devourer", fn = ARCH.aGrubElder } } }, -- devourer = ELDER imp 10
  crane = { pals = SKULL, treat = TREAT.treatBone, archs = {
    { name = "skullking", fn = ARCH.aSkullking }, { name = "skulltitan", fn = ARCH.aSkullTitan } } }, -- ELDER imp 10
  automate = { pals = AUTOMATON, treat = TREAT.treatRust, archs = {
    { name = "automaton", fn = ARCH.aAutomaton }, { name = "reliquary", fn = ARCH.aReliquary },
    { name = "juggernaut", fn = ARCH.aJuggernaut } } }, -- ELDER imp 10
}
local FAMILY_ORDER = { "cauchemar", "mortvivant", "bete", "demon", "insecte",
  "cephalo", "gelatine", "oeil", "spore", "ombre", "essaim", "annelide",
  "golem", "spectre", "culte", "abyssal", "cristal", "aile", "colosse",
  "templier", "inquisiteur", "seraphin", "griffon", "bandit", "canide", "reptile", "rongeur",
  "arachnide", "crustace", "meduse", "echassier", "wendigo", "hydre", "kraken",
  "pendu", "chimere", "cocon", "plante", "larve", "crane", "automate" }

-- ─────────────────────────── Noms (saveur par famille) ───────────────────────────
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }
local function roman(n) return ROMAN[n] or tostring(n) end
local EV_A = { "Yog", "Cth", "Ngg", "Zha", "Vul", "Goth", "Oth", "Sha", "Mor", "Nyar", "Ath", "Fht", "Ull", "Yth", "Tsa", "Vorm", "Khy", "Gla" }
local EV_B = { "goth", "soth", "ullh", "hotep", "oggua", "leth", "aroth", "ngui", "oloth", "zhar", "quth", "thaa", "vekh", "noss" }
local EV_C = { "a", "oth", "ul", "ax", "een", "or", "is", "oss" }
local POOLS = {
  mortvivant = { "Rictus", "Ossa", "Mortis", "Pallor", "Carrion", "Gravewend", "Marrow", "Ghast", "Wretch", "Husk", "Sepulch", "Cadav", "Wither", "Mourn", "Cryptus", "Bonemaw" },
  bete = { "Fang", "Snarl", "Maul", "Gore", "Bristle", "Howl", "Render", "Scar", "Grizzle", "Tusk", "Ravage", "Mane", "Gnash", "Sablefang", "Diremaw" },
  demon = { "Bael", "Vex", "Grimm", "Azka", "Pyre", "Cinder", "Malg", "Brand", "Skorn", "Druj", "Mordreth", "Ashk", "Vorgath", "Belim", "Carnix" },
  insecte = { "Skitter", "Carapax", "Mandib", "Chryss", "Vesp", "Thorax", "Hivex", "Acarn", "Formic", "Glissel", "Strident", "Vermillux" },
  cephalo = { "Nautilo", "Krakk", "Abyssa", "Tentaclo", "Squallid", "Drowne", "Maelstro", "Sephia", "Coilreef", "Brineworm", "Glaukus" },
  gelatine = { "Glob", "Mucila", "Slither", "Phlegm", "Vesicle", "Quagg", "Pudd", "Slurry", "Congeal", "Visqua", "Gloop", "Aspic" },
  oeil = { "Oculus", "Regard", "Vigil", "Watcher", "Iris", "Scry", "Beholda", "Gaze", "Voyeur", "Cornea", "Lethon" },
  spore = { "Myco", "Sporus", "Hyphae", "Truffle", "Blight", "Mould", "Fung", "Spawn", "Russula", "Amanita", "Caps" },
  ombre = { "Umbra", "Nihil", "Voidkin", "Tenebr", "Eclipse", "Murk", "Shade", "Caligo", "Erebos", "Noctis" },
  essaim = { "Vermis", "Plaga", "Skittermass", "Locust", "Hive", "Teem", "Pullul", "Brood", "Myriad", "Chitter" },
  annelide = { "Graboth", "Annelid", "Vermicul", "Bore", "Leech", "Lampr", "Tunneler", "Mawring", "Devourer", "Carcin" },
  golem = { "Granite", "Monolith", "Cairn", "Basalt", "Sentin", "Obsidia", "Caryat", "Menhir", "Golgo", "Ferro", "Argill" },
  spectre = { "Wail", "Shroud", "Pallid", "Wisp", "Lament", "Mourn", "Grief", "Hollow", "Vesper", "Banshee", "Reliqua" },
  culte = { "Acolyte", "Herald", "Veil", "Devout", "Zelot", "Cassock", "Penitent", "Choir", "Sermon", "Vow", "Reliquus" },
  abyssal = { "Innsm", "Dagon", "Marrowfin", "Trench", "Fathom", "Gloomeel", "Brackish", "Hydora", "Lantern", "Cthon", "Deepkin" },
  cristal = { "Quartz", "Geode", "Prism", "Shard", "Facet", "Lumen", "Beryl", "Vitric", "Spar", "Druse" },
  aile = { "Byak", "Stryx", "Carrion", "Vael", "Skarn", "Gale", "Talon", "Screel", "Aether", "Wend" },
  colosse = { "Gogmag", "Titan", "Grend", "Maul", "Hulk", "Crag", "Ogrim", "Moloch", "Gigan", "Brontes" },
  templier = { "Crusader", "Templar", "Sanctus", "Warden", "Aegis", "Sentinel", "Oathbound", "Bastion", "Bulwark", "Ward", "Cross", "Vigil" },
  inquisiteur = { "Inquisitor", "Confessor", "Zealot", "Mitre", "Chasten", "Tribunal", "Ember", "Censer", "Flagel", "Penitent", "Dogma", "Anathem" },
  seraphin = { "Seraph", "Throne", "Ophan", "Halo", "Cantor", "Empyr", "Hollowing", "Choir", "Glory", "Sixwing", "Hosanna", "Nimbus" },
  griffon = { "Gryphon", "Talon", "Aquilon", "Hippogriff", "Goldbeak", "Ironplume", "Raptor", "Crest", "Herald", "Lionwing", "Pennon" },
  bandit = { "Cutthroat", "Knave", "Rogue", "Throatcut", "Scoundrel", "Footpad", "Brigand", "Shiv", "Grime", "Maraud", "Filch", "Cutpurse" },
  canide = { "Fang", "Howl", "Mastiff", "Jackal", "Greywolf", "Mange", "Ironjaw", "Pack", "Hackle", "Snarl", "Jowl", "Carnage" },
  reptile = { "Viper", "Cobra", "Scale", "Coil", "Venom", "Molt", "Ophid", "Hood", "Hisser", "Scute", "Naja", "Forktongue" },
  rongeur = { "Rat", "Vermin", "Incisor", "Vole", "Pestilence", "Gnawer", "Nuisance", "Scurry", "Sewer", "Greyfang", "Litter", "Ratking" },
  arachnide = { "Weaver", "Widow", "Chelicera", "Silk", "Recluse", "Tarantula", "Eightlegs", "Hourglass", "Spinneret", "Mygale", "Venom", "Webwretch", "Palp", "Arachne" },
  crustace = { "Pincer", "Carapace", "Crab", "Squill", "Cuirass", "Claw", "Cracker", "Hermit", "Crustal", "Hardshell", "Scuttler", "Chitin", "Molt", "Clatter" },
  meduse = { "Medusa", "Bell", "Filament", "Drift", "Urtica", "Translux", "Nematode", "Bluelight", "Stinger", "Siphon", "Veil", "Pulsar", "Cnidar", "Seaspectre" },
  echassier = { "Stilt", "Heron", "Longneck", "Gaunt", "Thinleg", "Snipe", "Wretchlimb", "Pylon", "Probe", "Crane", "Faminefeather", "Beak", "Stork", "Stylet" },
  wendigo = { "Wendigo", "Famine", "Bellow", "Antler", "Stagskull", "Frostbone", "Starveling", "Deadwood", "Cervid", "Yelp", "Hungerling", "Tine", "Dearth", "Coldhowl" },
  hydre = { "Hydra", "Manyhead", "Necks", "Reborn", "Lerna", "Sevenmaw", "Regrow", "Ophis", "Heads", "Polycephal", "Coilkin", "Venomed", "Multihiss", "Hydrant" },
  kraken = { "Kraken", "Abyss", "Tentacle", "Blackbeak", "Deepone", "Leviathan", "Engulf", "Tidemaw", "Cephalon", "Cthonian", "Sucker", "Submerge", "Krakal", "Wrecker" },
  pendu = { "Puppet", "Marionette", "Dangle", "Gibbet", "Strung", "Limp", "Hangman", "Sever", "Noose", "Twitch" },
  chimere = { "Chimera", "Amalgam", "Grafted", "Mismatch", "Cobbled", "Patchwork", "Hybrid", "Teratoma", "Aberrant", "Restitched" },
  cocon = { "Cocoon", "Chrysalis", "Husk", "Pupa", "Hatchling", "Silkbound", "Gestate", "Brood", "Emergent", "Incubus" },
  plante = { "Maweed", "Tendril", "Carnivore", "Pollen", "Thornmaw", "Bramble", "Devourer", "Dionaea", "Sporebloom", "Vinemaw" },
  larve = { "Grub", "Maggot", "Crawler", "Wriggle", "Pseudopod", "Larval", "Glutton", "Segmented", "Mawling", "Pale" },
  crane = { "Skullking", "Orbit", "Vestige", "Titanmaw", "Fissure", "Ossuary", "Bonecolossus", "Cranial", "Relic", "Gravewatch" },
  automate = { "Automaton", "Cog", "Reliquary", "Core", "Rivet", "Carcass", "Gearwork", "Defiled", "Rustborn", "Ostensory" },
}
local function genName(rnd, famKey)
  if famKey == "cauchemar" then
    local a = EV_A[1 + floor(rnd() * #EV_A)]
    local conn = (rnd() < 0.5) and "'" or "-"
    local b = EV_B[1 + floor(rnd() * #EV_B)]
    local n = a .. conn .. b
    if rnd() < 0.4 then n = n .. EV_C[1 + floor(rnd() * #EV_C)] end
    return n
  end
  local pool = POOLS[famKey] or EV_A
  local w = pool[1 + floor(rnd() * #pool)]
  if rnd() < 0.55 then w = w .. " " .. roman(1 + floor(rnd() * 12)) end
  return w
end

-- ─────────────────────────── Bake grille(hex) -> Image nearest ───────────────────────────
local function bake(g)
  local w, h = g.w, g.h
  local data = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local c = g.data[y * w + x]
      if c then
        data:setPixel(x, y, (floor(c / 65536) % 256) / 255, (floor(c / 256) % 256) / 255, (c % 256) / 255, 1)
      end
    end
  end
  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest")
  return img, w, h
end

-- ─────────────────────────── API publique ───────────────────────────
-- AJUSTEMENT-MONDE : le contenu d'un sprite primgen fait ~45px de haut (canvas 64), mais le monde
-- (board/combat 320x180, cases ~30px) attend des créatures ~28px comme l'ancien générateur. `cached` pose
-- donc `def.scale = WORLD_FIT * rareté` -> primgen occupe la MÊME empreinte que l'ancien partout (board,
-- combat protégé, grimoire, gallery) sans retoucher une seule scène. Ajustable d'un cran si besoin en-jeu.
-- 0.5 = échelle NETTE : 0.5 × vue ×4 = ×2 ENTIER (pas de pixels inégaux). À ~la taille de la galerie v7.
-- (0.6 donnait ×2.4 fractionnaire -> pixels chunky + sprites trop gros débordant les cases.)
Primgen.WORLD_FIT = 0.5
Primgen.FAMILY_ORDER = FAMILY_ORDER
-- #archetypes, #palettes d'une famille -> le mapping (creaturegen.cached) en tire des index par hash d'id.
function Primgen.familyShape(famKey)
  local f = FAMILIES[famKey] or FAMILIES.cauchemar
  return #f.archs, #f.pals
end
function Primgen.archName(famKey, archIndex)
  local f = FAMILIES[famKey] or FAMILIES.cauchemar
  local a = f.archs[archIndex]
  return a and a.name or "?"
end
-- PIN : nom de forme CANONIQUE -> index dans `archs` (ou nil si le nom n'est pas dans la famille). Sert au
-- VERROUILLAGE par unité (creaturegen.cached pose `archIndex` depuis Units[id].arch) : ajouter une forme à
-- une famille NE rebinde plus les unités déjà pinnées (leur index est résolu par NOM, pas par hash de nArch).
function Primgen.archIndexOf(famKey, name)
  local f = FAMILIES[famKey]
  if not f then return nil end
  for i = 1, #f.archs do if f.archs[i].name == name then return i end end
  return nil
end

-- opts = { seed, size?=64, family?, archIndex?, paletteIndex? } -> { image, w, h, name, arch, family }
-- Construit la GRILLE + anatomie + palette : CŒUR PARTAGÉ par le rendu BAKÉ (generate) et le rendu VIVANT (live).
-- Séquence de tirages RNG STRICTEMENT identique à l'ancien generate -> déterminisme/golden de génération inchangés.
local function buildGrid(opts)
  local size = opts.size or 64
  local rng = love.math.newRandomGenerator(opts.seed or 1)
  local function rnd() return rng:random() end
  local famKey = (FAMILIES[opts.family] and opts.family) or "cauchemar"
  local fam = FAMILIES[famKey]
  local p = fam.pals[opts.paletteIndex or (1 + floor(rnd() * #fam.pals))]
  local arch = fam.archs[opts.archIndex or (1 + floor(rnd() * #fam.archs))]
  local g = makeGrid(size, size)
  local A = arch.fn(g, rnd, p)             -- dessine + DECLARE l'anatomie
  fam.treat(g, rnd, p, A)                  -- corruption ANCREE (jamais flottante)
  outline(g, p.out)
  return g, A, p, famKey, arch.name, rnd
end

function Primgen.generate(opts)
  local g, _, p, famKey, archName, rnd = buildGrid(opts)
  local img, w, h = bake(g)
  return { image = img, w = w, h = h, name = genName(rnd, famKey), arch = archName, family = famKey }
end

-- Données BRUTES pour le rendu VIVANT (src/render/critter.lua) : grille (cellules packées) + yeux + anatomie A
-- + palette p, SANS bake (aucune Image GPU). Mêmes index/seed que Primgen.def -> rendu IDENTIQUE au baké.
function Primgen.live(opts)
  local g, A, p, famKey, archName, rnd = buildGrid(opts)
  return { grid = g.data, eyes = g.eyes, w = g.w, h = g.h, A = A, p = p,
    name = genName(rnd, famKey), arch = archName, family = famKey }
end

-- ─────────────────────────── Def RIG-COMPATIBLE (anim sprite-entier sur 1 pièce) ───────────────────────────
-- Le sprite est MONOLITHIQUE -> on l'expose comme un rig à UNE part ("body") + des anims qui transforment cette
-- part. Ainsi Rig.new/update/draw (et arena_draw, galerie, build, Grimoire) l'affichent SANS modification.
-- Rig.new accepte une part `image` pré-bakée (cf. src/core/rig.lua). idle/attack/hurt = squash/stretch sprite-entier.
-- ── Mouvement idle PAR FAMILLE (signature de vie propre au TYPE — cf. proto bestiaire `PROF`/`disp`) ──
-- Le sprite est MONOLITHIQUE (1 part, pivot aux PIEDS = (w/2, 58)). On reproduit le `disp(x,y)` per-pixel du
-- proto avec 3 canaux AFFINES sur cette unique part :
--   sway  (b.rot)  = pendule planté aux pieds -> le HAUT bouge plus que la base (≈ `sway`/`writhe`/`legs` du proto)
--   breathe (b.sy) = respiration verticale, pieds au sol (≈ `breathe`)
--   float (rootDy) = lévitation d'ENSEMBLE — RÉSERVÉE aux créatures qui flottent VRAIMENT (≈ `bob`, yeux/ailes/spectres…)
-- Fréquences = freq_proto / 60 (l'horloge du rig est en FRAMES @60fps). sin(0)=0 -> pose NEUTRE à t=0 :
-- les minis figés (MiniRig, bounds) restent identiques, et la couche RENDER pure laisse le golden SIM intact.
-- Désynchro entre voisins via idlePhase (tiré au hasard dans Rig.new). Une famille inconnue -> MOTION_DEFAULT.
local MOTION_DEFAULT = { breathe = 0.018, breatheF = 0.030, sway = 0.006, swayF = 0.030 }
local MOTION = {
  -- amorphes / chair molle : respiration ample, à peine de balancement
  cauchemar   = { breathe = 0.030, breatheF = 0.027, sway = 0.008, swayF = 0.027 },
  gelatine    = { breathe = 0.050, breatheF = 0.037, sway = 0.006, swayF = 0.037 }, -- throb mou
  larve       = { breathe = 0.040, breatheF = 0.047, sway = 0.014, swayF = 0.047 }, -- frétille
  cocon       = { breathe = 0.045, breatheF = 0.024, sway = 0.004, swayF = 0.024 }, -- qqch respire dedans
  -- marcheurs / bêtes : respiration + report de poids discret
  bete        = { breathe = 0.020, breatheF = 0.033, sway = 0.010, swayF = 0.050 },
  demon       = { breathe = 0.020, breatheF = 0.033, sway = 0.020, swayF = 0.030 }, -- dressé, balance
  colosse     = { breathe = 0.025, breatheF = 0.040, sway = 0.011, swayF = 0.040 },
  canide      = { breathe = 0.030, breatheF = 0.043, sway = 0.010, swayF = 0.053 }, -- halète
  bandit      = { breathe = 0.022, breatheF = 0.033, sway = 0.008, swayF = 0.023 }, -- fébrile
  culte       = { breathe = 0.020, breatheF = 0.030, sway = 0.016, swayF = 0.027 }, -- balancement rituel
  inquisiteur = { breathe = 0.018, breatheF = 0.033, sway = 0.012, swayF = 0.027 },
  templier    = { breathe = 0.018, breatheF = 0.033, sway = 0.007, swayF = 0.033 }, -- blindé, raide
  wendigo     = { breathe = 0.020, breatheF = 0.025, sway = 0.013, swayF = 0.025 },
  echassier   = { breathe = 0.015, breatheF = 0.027, sway = 0.013, swayF = 0.027 }, -- sur échasses
  -- os / minéral / mécanique : quasi statiques, micro-vie
  mortvivant  = { breathe = 0.012, breatheF = 0.037, sway = 0.010, swayF = 0.053 }, -- cliquetis d'os
  crane       = { breathe = 0.015, breatheF = 0.020, sway = 0.004, swayF = 0.020 },
  cristal     = { breathe = 0.020, breatheF = 0.023, sway = 0.005, swayF = 0.023 },
  golem       = { breathe = 0.012, breatheF = 0.037, sway = 0.008, swayF = 0.037 },
  automate    = { breathe = 0.010, breatheF = 0.043, sway = 0.007, swayF = 0.043 },
  -- segmentés / nerveux : balancement rapide et menu
  insecte     = { breathe = 0.015, breatheF = 0.050, sway = 0.009, swayF = 0.070 },
  arachnide   = { breathe = 0.025, breatheF = 0.040, sway = 0.011, swayF = 0.060 },
  crustace    = { breathe = 0.025, breatheF = 0.040, sway = 0.009, swayF = 0.057 },
  rongeur     = { breathe = 0.045, breatheF = 0.060, sway = 0.007, swayF = 0.067 }, -- reniflement
  -- reptiles / vers / hydres / plantes : ondulation marquée
  reptile     = { breathe = 0.018, breatheF = 0.030, sway = 0.020, swayF = 0.030 },
  annelide    = { breathe = 0.020, breatheF = 0.033, sway = 0.022, swayF = 0.033 },
  hydre       = { breathe = 0.018, breatheF = 0.032, sway = 0.020, swayF = 0.032 },
  chimere     = { breathe = 0.030, breatheF = 0.030, sway = 0.012, swayF = 0.040 },
  plante      = { breathe = 0.035, breatheF = 0.027, sway = 0.017, swayF = 0.027 }, -- au vent
  spore       = { breathe = 0.030, breatheF = 0.025, sway = 0.013, swayF = 0.025 },
  kraken      = { breathe = 0.025, breatheF = 0.033, sway = 0.022, swayF = 0.040 }, -- bras qui dérivent
  cephalo     = { breathe = 0.030, breatheF = 0.030, sway = 0.018, swayF = 0.040 },
  -- FLOTTANTS : lévitation d'ensemble (float) + signature secondaire
  oeil        = { breathe = 0.025, breatheF = 0.033, float = 1.0, floatF = 0.025 },
  ombre       = { breathe = 0.035, breatheF = 0.027, float = 1.3, floatF = 0.023 },
  spectre     = { breathe = 0.020, breatheF = 0.027, sway = 0.022, swayF = 0.020, float = 1.2, floatF = 0.025 },
  aile        = { breathe = 0.020, breatheF = 0.033, sway = 0.012, swayF = 0.060, float = 1.1, floatF = 0.030 }, -- ailes
  seraphin    = { breathe = 0.020, breatheF = 0.033, sway = 0.010, swayF = 0.050, float = 1.1, floatF = 0.025 },
  griffon     = { breathe = 0.020, breatheF = 0.033, sway = 0.010, swayF = 0.047, float = 0.6, floatF = 0.027 },
  meduse      = { breathe = 0.040, breatheF = 0.030, sway = 0.014, swayF = 0.033, float = 1.2, floatF = 0.027 }, -- pulse
  essaim      = { breathe = 0.020, breatheF = 0.040, sway = 0.014, swayF = 0.053, float = 0.8, floatF = 0.027 },
  abyssal     = { breathe = 0.020, breatheF = 0.030, sway = 0.012, swayF = 0.037, float = 1.0, floatF = 0.027 },
  pendu       = { breathe = 0.012, breatheF = 0.022, sway = 0.020, swayF = 0.022, float = 1.0, floatF = 0.022 }, -- pend & se balance
}

local BODY_ANIM = {}
BODY_ANIM.idle = function(char, t)
  local b = char.parts.body
  local ph = char.idlePhase or 0
  local m = MOTION[char.def.primFamily or ""] or MOTION_DEFAULT
  if b then
    if m.breathe then b.sy = 1 + sin(t * m.breatheF + ph) * m.breathe end       -- respiration (pieds plantés)
    if m.sway then b.rot = sin(t * m.swayF + ph * 1.3) * m.sway end             -- pendule aux pieds (le haut balance)
  end
  if m.float then return { rootDy = sin(t * m.floatF + ph) * m.float } end       -- lévitation : flottants UNIQUEMENT
  return {}
end
BODY_ANIM.attack = function(char, t, prog)
  local b = char.parts.body
  local f = sin(min(1, prog or 0) * math.pi)
  if b then b.sx = 1 + f * 0.12; b.sy = 1 - f * 0.06 end -- fente + étirement avant
  return { rootDx = f * 6 }
end
BODY_ANIM.hurt = function(char, t, prog)
  local b = char.parts.body
  local f = sin(min(1, prog or 0) * math.pi)
  if b then b.sy = 1 + f * 0.10; b.sx = 1 - f * 0.05 end -- recul + squash
  return { rootDx = -f * 4, tint = { 1, 1 - f * 0.45, 1 - f * 0.6 } } -- flash rougeoyant
end

-- opts = { id?, seed, family?, archIndex?, paletteIndex?, rank?, scale?, glow? } -> def consommable par Rig.new.
function Primgen.def(opts)
  local gen = Primgen.generate(opts)
  return {
    name = (opts.id or gen.name):upper(),
    parts = { body = { image = gen.image, w = gen.w, h = gen.h, pivot = { x = floor(gen.w / 2), y = 58 } } },
    rig = { { part = "body", at = { 0, 0 } } },
    animations = BODY_ANIM,
    bodyplan = "primgen", rank = opts.rank or 1, scale = opts.scale or 1, glow = opts.glow or 0,
    primName = gen.name, primArch = gen.arch, primFamily = gen.family,
  }
end

return Primgen
