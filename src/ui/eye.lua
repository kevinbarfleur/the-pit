-- src/ui/eye.lua
-- L'ŒIL — la signature body-horror de l'UI The Pit, EXTRAITE de forge.lua pour être réutilisée partout :
-- nuée des boutons (cta), veilleur des panneaux, gemme de carte de relique, sceau (eye-ring). Port fidèle de
-- `drawEye()` de docs/pixel-art/forge-px.js : sclère + veines injectées de sang (BLOOD) + iris/pupille
-- (slit/round) + paupières qui bornent + clignement cyclique.
--
-- ── CONTRAT (zéro love.*) ──────────────────────────────────────────────────────────────────────────
-- Eye.draw écrit dans un TAMPON Forge (le `buf` FFI de forge.lua : set/blend/add en OCTETS 0..255). C'est
-- de l'arithmétique PURE -> testable headless, jamais d'appel graphique direct (le bake/blit reste l'affaire
-- de forge.lua). Les COULEURS (sclère/sang/pupille/métal des paupières) sont injectées par forge.lua via
-- Eye.setPalette(pal) au require, pour garder UNE seule source de palette (pas de hex dupliqués ici).
-- DÉTERMINISTE : le RNG des veines (mulberry32 seedé) est aussi injecté par forge.lua (Eye.setRng(fn)).
--
-- Eye.draw(buf, cx, cy, r, open, glow, t, seed, opts) :
--   cx,cy  centre (art-px) ; r rayon ; open 0..1 (paupières) ; glow 0..1 (iris qui s'illumine).
--   t      horloge (secondes, animation des regards/clignements) ; seed graine (désync entre yeux).
--   opts   { squash=0.62, gaze={gx,gy}|nil, pupil="slit"|"round", blood=0..1 }.

local Eye = {}

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sin, cos, sqrt, pi = math.sin, math.cos, math.sqrt, math.pi
local function hypot(a, b) return sqrt(a * a + b * b) end
local function clamp(v) return v < 0 and 0 or (v > 1 and 1 or v) end
local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Palette injectée (forge.lua appelle Eye.setPalette une fois). Valeurs de repli (octets) au cas où l'œil
-- serait utilisé sans forge (showcase isolé) : mêmes teintes que forge-px.js.
local METAL  = { outline = { 8, 5, 3 }, deep = { 52, 37, 15 }, mid = { 106, 80, 34 }, base = { 156, 122, 54 }, hi = { 216, 182, 94 }, spec = { 246, 230, 164 } }
local SCLERA = { pale = { 216, 207, 182 }, shade = { 156, 145, 122 }, vein = { 156, 34, 34 } }
local PUPIL  = { 7, 4, 9 }
local BLOOD  = { d3 = { 156, 32, 32 } }
local ACC    = { dark = { 122, 94, 36 }, mid = { 196, 154, 62 }, bright = { 242, 217, 138 } }

-- RNG injecté (mulberry32 seedé de forge.lua) : Eye.setRng(function(seed) return function()->0..1 end end).
-- Repli déterministe (LCG) si non injecté -> l'œil reste seedé même isolé.
local makeRng = function(a)
  local s = a % 2147483647; if s <= 0 then s = s + 2147483646 end
  return function() s = (s * 16807) % 2147483647; return s / 2147483647 end
end

-- forge.lua passe SES tables (mêmes objets) -> une seule source de vérité de palette. ACC suit l'accent
-- courant (setPalette est rappelé par Forge.setAccent pour que l'iris vire à l'accent actif).
function Eye.setPalette(pal)
  if not pal then return end
  if pal.metal then METAL = pal.metal end
  if pal.sclera then SCLERA = pal.sclera end
  if pal.pupil then PUPIL = pal.pupil end
  if pal.blood then BLOOD = pal.blood end
  if pal.acc then ACC = pal.acc end
end
function Eye.setRng(fn) if type(fn) == "function" then makeRng = fn end end

function Eye.draw(buf, cx, cy, r, open, glow, t, seed, opts)
  if not buf then return end
  opts = opts or {}
  local squash = opts.squash or 0.62
  local gaze = opts.gaze
  local pupil = opts.pupil or "slit"
  local blood = opts.blood or 0
  local bt = (t * 0.6 + seed * 2.3) % 6.0
  local blink = bt > 5.6 and (1 - abs(bt - 5.8) / 0.2) or 0
  local op = clamp(open * (1 - clamp(blink)))
  -- PLUS OUVERT = PLUS ROND : à l'ouverture (op->1) le squash remonte vers ~0.92 (œil rond, LISIBLE).
  local sqOpen = squash + (0.92 - squash) * op
  local ry = r * sqOpen * op
  if ry < 0.6 then
    -- ŒIL FERMÉ (repos) : COUTURE de paupière nette (fente sombre + ourlet clair) -> « œil clos », pas un trou.
    for x = -r, r do
      local fx, fy = floor(cx + x + 0.5), floor(cy + 0.5)
      buf:set(fx, fy, mix(METAL.deep, { 0, 0, 0 }, 0.55))
      if abs(x) < r - 0.5 then buf:set(fx, fy + 1, mix(METAL.mid, METAL.deep, 0.5)) end
    end
    buf:set(floor(cx - r + 0.5), floor(cy - 0.5 + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.4))
    buf:set(floor(cx + r + 0.5), floor(cy - 0.5 + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.4))
    return
  end
  local ex, ey
  -- sclère : cœur quasi blanc (lecture « œil » nette), bord en ombre douce (volume).
  local SCLERA_WHITE = { 244, 240, 230 }
  for y = -math.ceil(ry), math.ceil(ry) do
    for xx = -math.ceil(r), math.ceil(r) do
      ex = xx / r; ey = y / ry
      if ex * ex + ey * ey <= 1 then
        local fall = clamp(abs(ex) * 0.38 + abs(ey) * 0.42)
        local base = mix(SCLERA_WHITE, SCLERA.shade, fall)
        if fall < 0.3 then base = mix(base, { 255, 255, 255 }, (0.3 - fall) * 0.8) end
        if blood > 0 then base = mix(base, BLOOD.d3, blood * 0.14) end
        buf:set(floor(cx + xx + 0.5), floor(cy + y + 0.5), base)
      end
    end
  end
  -- veines (délibérées, seedées, propres)
  local nv = 2 + floor(blood * 3 + 0.5)
  local rnd = makeRng(floor(seed * 101))
  for _ = 1, nv do
    local a = rnd() * 6.28
    local vx, vy = cx + cos(a) * r * 0.96, cy + sin(a) * ry * 0.96
    for _ = 1, math.ceil(r * 0.6) do
      ex = (vx - cx) / r; ey = (vy - cy) / ry
      if ex * ex + ey * ey <= 1 then buf:blend(floor(vx + 0.5), floor(vy + 0.5), SCLERA.vein, 0.42 + blood * 0.3) end
      vx = vx + (cx - vx) * 0.18 + (rnd() - 0.5) * 0.4
      vy = vy + (cy - vy) * 0.18
    end
  end
  -- iris + pupille
  local gx, gy = 0, 0
  if gaze then
    local dx, dy = gaze[1] - cx, gaze[2] - cy
    local dl = hypot(dx, dy); if dl == 0 then dl = 1 end
    local mo = r * 0.32
    gx = dx / dl * mo; gy = dy / dl * mo * sqOpen
  else
    gx = sin(t * 0.5 + seed) * r * 0.22; gy = cos(t * 0.4 + seed * 1.3) * ry * 0.4
  end
  local ir = max(2, floor(r * 0.48 + 0.5))
  for y = -ir, ir do
    for xx = -ir, ir do
      local d = hypot(xx, y)
      if d <= ir then
        local ax, ay = gx + xx, gy + y
        if (ax / r) * (ax / r) + (ay / ry) * (ay / ry) <= 1 then
          local dd = d / ir
          local col = mix(mix(ACC.mid, ACC.bright, glow), ACC.dark, dd)
          local isP
          if pupil == "slit" then
            isP = abs(xx) < ir * 0.30 * (1 - 0.32 * abs(y) / ir)
          else
            isP = dd < 0.46
          end
          if isP then col = PUPIL elseif dd > 0.84 then col = mix(col, { 0, 0, 0 }, 0.5) end
          buf:set(floor(cx + ax + 0.5), floor(cy + ay + 0.5), col)
        end
      end
    end
  end
  buf:set(floor(cx + gx - ir * 0.3 + 0.5), floor(cy + gy - ir * 0.3 + 0.5), { 255, 255, 255 })
  -- PAUPIÈRES : arcs haut/bas qui BORNENT l'œil. Gros œil (r>=5) -> ourlet 2px (lèvre éclairée en haut).
  local thick = (r >= 5)
  for xx = -r, r do
    ex = xx / r
    if abs(ex) <= 1 then
      local lh = sqrt(max(0, 1 - ex * ex)) * ry
      buf:set(floor(cx + xx + 0.5), floor(cy - lh + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.45))
      buf:set(floor(cx + xx + 0.5), floor(cy + lh + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.6))
      if thick then
        buf:set(floor(cx + xx + 0.5), floor(cy - lh + 1.5), mix(METAL.deep, METAL.mid, 0.3))
        buf:set(floor(cx + xx + 0.5), floor(cy + lh - 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.35))
      end
    end
  end
end

-- Eye.ring(buf, W, H, open, glow, t, seed) : ŒIL serti dans un ANNEAU de métal (le SCEAU). Porté de
-- drawEyeRing du JS. L'anneau est dessiné ici (métal lit/ombré radial) puis l'œil au centre.
function Eye.ring(buf, W, H, open, glow, t, seed)
  if not buf then return end
  local cx, cy = W / 2 - 0.5, H / 2 - 0.5
  local Rc = min(W, H) / 2 - 0.5
  for y = floor(cy - Rc), math.ceil(cy + Rc) do
    for x = floor(cx - Rc), math.ceil(cx + Rc) do
      local dx, dy = x - cx, y - cy
      local d = hypot(dx, dy)
      if d >= Rc - 2 and d <= Rc + 0.4 then
        local lit = (-dx / d * 0.4 - dy / d * 0.5)
        buf:set(x, y, (d > Rc - 0.5 or d < Rc - 1.5) and METAL.outline
          or (lit > 0 and mix(METAL.mid, METAL.hi, lit) or METAL.deep))
      end
    end
  end
  Eye.draw(buf, cx, cy, Rc - 3, open, glow, t, seed, { blood = 0.6, squash = 0.8 })
end

-- Eye.watcher(buf, W, H, t, seed, opts) : le VEILLEUR d'un panneau/carte — un œil qui s'OUVRE puis se
-- referme en cycle lent, posé à une position relative (opts.fx,fy en 0..1, défaut bas-droite), hors du
-- contenu lourd. Rend l'UI « vivante » sans bruit. opts = { fx, fy, r, period, blood }.
function Eye.watcher(buf, W, H, t, seed, opts)
  if not buf then return end
  opts = opts or {}
  local period = opts.period or 0.07
  local ec = ((t * period + (seed % 7) * 0.13) % 1)
  local eo = ec < 0.18 and sin(ec / 0.18 * pi) or 0
  if eo <= 0.01 then return end
  local fx = opts.fx or 0.86
  local fy = opts.fy or 0.9
  Eye.draw(buf, floor(W * fx + 0.5), floor(H * fy + 0.5), opts.r or 5, clamp(eo), 0.5, t, seed + 3,
    { blood = opts.blood or 0.6, squash = 0.7 })
end

return Eye
