-- src/ui/gauge.lua
-- ATOMES DE JEU — JAUGES (design-system-spec.md §2.8) : les barres de DONNÉES VIVANTES du combat/HUD.
--   • health(x,y,w,h,cur,max,opts)  — vie : remplissage SANG + SEGMENTS d'altération (DoT) peints depuis
--                                      l'AVANT vers l'arrière (1 fraction = 1 couleur de famille) + overlay
--                                      BOUCLIER en hachures diagonales + numérique `cur/max` (+shield).
--   • cooldown(x,y,w,h,pct,ready)    — recharge : or terni en charge / or vif + lueur quand prêt.
--   • lives(x,y,n,max)               — vies : `max` cœurs, `n` pleins (sang + lueur) / vides (pierre).
--   • descent(x,y,w,h,wins,total)    — descente : `total` segments (def 10), `wins` gagnés (laiton) / restants.
--
-- COUCHE RENDER PURE (love.graphics, espace design 1280×720, sous Draw.begin). Primitives DYNAMIQUES (la
-- valeur change chaque frame) -> direct love.graphics, comme Draw.bar (PAS un widget baké Forge). Couleurs des
-- segments = afflictions de Theme.c (burn/bleed/poison/rot/shock). Numérique via Draw.text* (Space Mono).
-- HEADLESS-SAFE : love.graphics stubé -> tout no-op (golden neutre).
--
-- Réf pixel : pit-forge.js drawHealthGauge (front animé, segments depuis le front) ; nombres = §2.8.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")

local Gauge = {}

local C = Theme.c
local floor, max = math.floor, math.max -- min n'est utilisé qu'en math.min (clamps) -> pas d'alias inutilisé

local function g() return love and love.graphics or nil end
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- Couleur de famille d'affliction (segment DoT). Repli `bleed` si la clé est inconnue (défensif).
local function afflColor(key)
  return C[key] or C.bleed
end

-- ── HEALTH BAR — §2.8. Fond sombre + liseré iron, remplissage SANG (blood-d → blood) proportionnel, puis
-- les SEGMENTS d'altération peints DEPUIS LE FRONT vers l'arrière (chaque segment teinte sa tranche), enfin
-- l'overlay BOUCLIER en hachures diagonales sur la gauche, et le numérique `cur/max` (+shield).
--   opts = {
--     segs   = { {frac=0.2, key="bleed"}, {frac=0.1, key="poison"}, ... }  -- fractions [0..1] DEPUIS le front
--     shield = nombre (PV de bouclier ; dessine la bande hachurée + « +N » dans la couleur bouclier)
--     showText = bool (def true) -> dessine « cur/max » centré
--   }
-- Renvoie la hauteur dessinée (h).
function Gauge.health(x, y, w, h, cur, max_, opts)
  opts = opts or {}
  local gr = g()
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  max_ = max_ or 1
  local frac = clamp01((cur or 0) / (max_ <= 0 and 1 or max_))

  -- piste : fond sombre + liseré iron (« inset shadow » approché par le bord net).
  Draw.rect(x, y, w, h, C.stone900, C.iron, 1)
  local ix, iy = x + 1, y + 1
  local iw, ih = w - 2, h - 2
  if iw <= 0 or ih <= 0 then return h end

  -- remplissage SANG (blood-d profond en bas, blood en crête) sur la fraction de vie.
  local fillW = floor(frac * iw + 0.5)
  if gr and fillW > 0 then
    gr.setColor(C.bloodD[1], C.bloodD[2], C.bloodD[3], 1)
    gr.rectangle("fill", ix, iy, fillW, ih)
    -- crête éclairée (1px haut) = blood vif.
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], 1)
    gr.rectangle("fill", ix, iy, fillW, max(1, floor(ih * 0.35)))

    -- SEGMENTS d'altération : peints depuis le FRONT (bord droit du remplissage) vers la gauche. Chaque
    -- segment occupe `frac` de la LARGEUR INTÉRIEURE, dans l'ordre fourni (le 1er touche le front).
    local front = ix + fillW
    local cursorFrac = 0
    for _, s in ipairs(opts.segs or {}) do
      local sf = clamp01(s.frac or 0)
      if sf > 0 then
        local segPx = sf * iw
        local x1 = front - cursorFrac * iw
        local x0 = x1 - segPx
        -- borne au remplissage (un segment ne déborde pas hors de la vie restante).
        if x0 < ix then x0 = ix end
        if x1 > front then x1 = front end
        if x1 > x0 then
          local col = afflColor(s.key)
          gr.setColor(col[1], col[2], col[3], 0.62) -- voile de famille SUR le sang (la tranche « infectée »)
          gr.rectangle("fill", floor(x0), iy, floor(x1 - x0), ih)
        end
        cursorFrac = cursorFrac + sf
      end
    end

    -- front net (liseré vif) à la pointe du remplissage.
    gr.setColor(C.bloodL[1], C.bloodL[2], C.bloodL[3], 1)
    gr.rectangle("fill", front - 1, iy, 1, ih)
    gr.setColor(1, 1, 1, 1)
  end

  -- OVERLAY BOUCLIER : hachures diagonales (135°) depuis le bord gauche, sur la portion de bouclier, + un
  -- liseré droit dans la couleur bouclier. Le bouclier se lit « par-dessus » la vie (absorbe en premier).
  local shield = opts.shield
  if gr and shield and shield > 0 then
    local shFrac = clamp01(shield / (max_ <= 0 and 1 or max_))
    local shW = floor(shFrac * iw + 0.5)
    if shW > 0 then
      -- hachures : 1 px sur 4 sur la diagonale (x+y) -> motif rayé reconnaissable (sans clip GPU).
      gr.setColor(C.shield[1], C.shield[2], C.shield[3], 0.55)
      for sx = 0, shW - 1 do
        for sy = 0, ih - 1 do
          if ((sx + sy) % 4) == 0 then gr.rectangle("fill", ix + sx, iy + sy, 1, 1) end
        end
      end
      -- liseré droit du bouclier (« right border rgba(shield,.7) »).
      gr.setColor(C.shield[1], C.shield[2], C.shield[3], 0.7)
      gr.rectangle("fill", ix + shW - 1, iy, 1, ih)
      gr.setColor(1, 1, 1, 1)
    end
  end

  -- NUMÉRIQUE `cur/max` centré (Space Mono 12) + « +shield » en couleur bouclier à droite.
  if opts.showText ~= false then
    local font = Theme.value(12)
    local label = tostring(floor(cur or 0)) .. "/" .. tostring(floor(max_))
    local ty = y + (h - (font and font:getHeight() or 12)) / 2
    Draw.textC(label, x + w / 2, ty, C.ink, font)
    if shield and shield > 0 then
      Draw.textR("+" .. tostring(floor(shield)), x + w - 3, ty, C.shield, font)
    end
  end
  return h
end

-- ── COOLDOWN BAR — §2.8. Recharge : fond sombre + liseré iron, remplissage `pct` (or terni en charge, or
-- vif + lueur quand `ready`). x,y,w,h ; pct ∈ [0,1] ; ready = bool (full + glow). Renvoie h.
function Gauge.cooldown(x, y, w, h, pct, ready)
  local gr = g()
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  Draw.rect(x, y, w, h, C.stone900, C.iron, 1)
  local ix, iy = x + 1, y + 1
  local iw, ih = w - 2, h - 2
  if iw <= 0 or ih <= 0 then return h end
  local p = ready and 1 or clamp01(pct or 0)
  local fw = floor(p * iw + 0.5)
  if gr and fw > 0 then
    -- charge = laiton terni (brass) ; prêt = or vif (gold/brassS) + crête claire.
    local base = ready and C.gold or C.brass
    gr.setColor(base[1], base[2], base[3], 1)
    gr.rectangle("fill", ix, iy, fw, ih)
    local crest = ready and C.brassS or C.brassL
    gr.setColor(crest[1], crest[2], crest[3], 1)
    gr.rectangle("fill", ix, iy, fw, max(1, floor(ih * 0.4)))
    -- lueur « READY » (additive) sur toute la barre.
    if ready and gr.setBlendMode then
      gr.setBlendMode("add")
      gr.setColor(C.shock[1], C.shock[2], C.shock[3], 0.3)
      gr.rectangle("fill", ix, iy, iw, ih)
      gr.setBlendMode("alpha")
    end
    gr.setColor(1, 1, 1, 1)
  end
  return h
end

-- ── Un cœur plein (silhouette pixel, §2.8 lives). cx = coin haut-gauche, scale = px par cellule de grille.
-- Bitmap 7×6 (deux lobes + pointe), reconnaissable sans lire. col = couleur de remplissage.
local HEART = { "0110110", "1111111", "1111111", "0111110", "0011100", "0001000" }
local function heart(cx, cy, scale, col, glow)
  local gr = g(); if not gr then return end
  cx, cy = floor(cx), floor(cy)
  gr.setColor(col[1], col[2], col[3], col[4] or 1)
  for r = 1, #HEART do
    local row = HEART[r]
    for c = 1, #row do
      if string.sub(row, c, c) == "1" then
        gr.rectangle("fill", cx + (c - 1) * scale, cy + (r - 1) * scale, scale, scale)
      end
    end
  end
  -- lueur de sang sous le cœur plein (additive) — « 0 0 6px rgba(blood) ».
  if glow and gr.setBlendMode then
    gr.setBlendMode("add")
    gr.setColor(col[1], col[2], col[3], 0.25)
    gr.rectangle("fill", cx, cy, #HEART[1] * scale, #HEART * scale)
    gr.setBlendMode("alpha")
  end
  gr.setColor(1, 1, 1, 1)
end

-- ── LIVES — §2.8. `max` cœurs alignés, `n` pleins (sang + lueur) / vides (pierre stone-700). x,y = coin
-- haut-gauche ; renvoie la largeur totale. scale/gap réglables (def 2px/cellule, 4px d'écart).
function Gauge.lives(x, y, n, max_, scale, gap)
  max_ = max_ or 5
  n = math.max(0, math.min(n or 0, max_))
  scale = scale or 2
  gap = gap or 4
  local cw = #HEART[1] * scale
  for i = 0, max_ - 1 do
    local cx = x + i * (cw + gap)
    heart(cx, y, scale, i < n and C.blood or C.stone700, i < n)
  end
  return max_ * (cw + gap) - gap
end

-- Mélange linéaire de deux couleurs {r,g,b} -> {r,g,b}. k clampé [0,1].
local function mix(a, b, k)
  k = k < 0 and 0 or (k > 1 and 1 or k)
  return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

-- ── LIFE ORB — globe de vie « à la Diablo » (retour user 2026-06, retour de l'ancien orbe à nageur) : verre
-- sombre, LIQUIDE SANG dont le niveau = vies/max, surface ONDULÉE animée, un POISSON pâle qui nage (demi-tour
-- aux bords + tangage), bulles qui montent, reflet spéculaire et anneau de laiton (vire au sang à 1 vie).
-- Per-frame en primitives lisses (chrome d'UI nette, comme les barres de combat) ; x,y,w,h = boîte ; t = SECONDES.
-- HEADLESS-SAFE (g() -> no-op ; setBlendMode/arc gardés -> absents du mock). Render-only -> golden neutre.
function Gauge.lifeOrb(x, y, w, h, lives, max_, t)
  local gr = g(); if not gr then return end
  max_ = max_ or 5
  lives = lives or 0
  t = t or 0
  local frac = clamp01(lives / max_)
  local cx, cy = x + w / 2, y + h / 2
  local R = floor(math.min(w, h) / 2) - 1 -- rayon extérieur (laisse la place à l'anneau)
  local rIn = R - 3                       -- rayon du liquide (sous l'anneau)
  if rIn < 4 then return end
  local low = lives <= 1
  local pulse = low and (0.5 + 0.5 * math.sin(t * 4)) or 0

  -- 1) VERRE : disque sombre + ombrage interne (la lumière vient du haut-gauche).
  gr.setColor(C.stone900[1], C.stone900[2], C.stone900[3], 1)
  gr.circle("fill", cx, cy, rIn, 56)
  gr.setColor(C.void[1], C.void[2], C.void[3], 0.55)
  gr.circle("fill", cx + rIn * 0.16, cy + rIn * 0.18, rIn * 0.9, 56)

  -- 2) SURFACE du liquide (deux sinus déphasés) à `frac` de hauteur.
  local surfaceY = (cy + rIn) - frac * (2 * rIn)
  local function waveAt(px) return surfaceY + math.sin(px * 0.09 + t * 2.0) * 1.6 + math.sin(px * 0.05 - t * 1.3) * 1.0 end

  -- 3) LIQUIDE : scanlines clippées au cercle (remplissage circulaire parfait + dégradé de profondeur).
  if frac > 0.005 then
    local yTop = math.max(math.ceil(cy - rIn), math.ceil(surfaceY))
    for yy = yTop, math.ceil(cy + rIn) do
      local dyl = yy - cy
      local hw2 = rIn * rIn - dyl * dyl
      if hw2 > 0 then
        local hw = math.sqrt(hw2)
        local depth = clamp01((yy - surfaceY) / (2 * rIn))
        local col = mix(C.blood, C.bloodD, 0.12 + depth * 1.05)
        if low then col = mix(col, C.bloodD, 0.3 * pulse) end
        gr.setColor(col[1], col[2], col[3], 1)
        gr.line(cx - hw, yy, cx + hw, yy)
      end
    end
    -- crête de surface (ménisque clair ondulé) sur la largeur du liquide.
    local hwS2 = rIn * rIn - (surfaceY - cy) * (surfaceY - cy)
    if hwS2 > 0 then
      local hwS = math.sqrt(hwS2)
      local top = mix(C.blood, { 1, 0.55, 0.34 }, 0.35)
      gr.setLineWidth(2); gr.setColor(top[1], top[2], top[3], 0.8)
      local px0, py0
      for px = floor(cx - hwS), math.ceil(cx + hwS), 3 do
        local wy = waveAt(px)
        if px0 then gr.line(px0, py0, px, wy) end
        px0, py0 = px, wy
      end
      gr.setLineWidth(1)
    end
  end

  -- 4) POISSON pâle qui nage (silhouette ; caché si trop peu d'eau). Corps ellipse + queue triangle + œil ;
  -- demi-tour aux bords (face = signe de la vitesse) ; reste TOUJOURS sous la surface et dans le cercle.
  if frac > 0.14 then
    local ang = t * 0.8
    local bodyW, bodyH = rIn * 0.32, rIn * 0.19
    local fy = (surfaceY + (cy + rIn)) / 2 + math.sin(t * 1.6) * (rIn * 0.16)
    local hwFy2 = rIn * rIn - (fy - cy) * (fy - cy)
    if hwFy2 > 0 then
      local maxX = math.sqrt(hwFy2) - bodyW - 2
      if maxX > 2 then
        local fx = cx + math.sin(ang) * maxX
        local face = (math.cos(ang) >= 0) and 1 or -1
        fy = math.max(fy, waveAt(fx) + bodyH + 1)
        gr.push(); gr.translate(fx, fy); gr.scale(face, 1)
        gr.setColor(0.80, 0.72, 0.56, 0.40)
        gr.polygon("fill", -bodyW * 0.7, 0, -bodyW * 1.6, -bodyH, -bodyW * 1.6, bodyH) -- queue
        gr.setColor(0.82, 0.74, 0.58, 0.55)
        gr.ellipse("fill", 0, 0, bodyW, bodyH, 18)                                     -- corps
        gr.setColor(0, 0, 0, 0.7)
        gr.circle("fill", bodyW * 0.5, -bodyH * 0.12, math.max(1, bodyH * 0.2))        -- œil
        gr.pop()
      end
    end
  end

  -- 5) BULLES qui montent du fond vers la surface (toujours dans l'eau).
  if frac > 0.12 then
    for i = 1, 3 do
      local ph = (t * (0.22 + i * 0.05) + i * 0.37) % 1
      local by = (cy + rIn) - ph * (frac * 2 * rIn)
      local bx = cx + math.sin(t * 1.1 + i * 2.1) * (rIn * 0.28) + (i - 2) * (rIn * 0.16)
      if by > waveAt(bx) and (rIn * rIn - (by - cy) * (by - cy)) > 0 then
        gr.setColor(1, 0.82, 0.72, 0.16 * (1 - ph))
        gr.circle("fill", bx, by, 1.2)
      end
    end
  end

  -- 6) REFLET spéculaire (additif, gardé) : la bille de verre.
  if gr.setBlendMode then
    gr.setBlendMode("add"); gr.setColor(1, 1, 1, 0.12)
    gr.ellipse("fill", cx - rIn * 0.34, cy - rIn * 0.4, rIn * 0.4, rIn * 0.22, 18)
    gr.setBlendMode("alpha")
  end

  -- 7) ANNEAU de laiton + ourlet de fer ; vire au sang à 1 vie (avec un léger pouls).
  local rim = low and mix(C.brass, C.blood, 0.4 + 0.3 * pulse) or C.brass
  gr.setLineWidth(3); gr.setColor(rim[1], rim[2], rim[3], 1); gr.circle("line", cx, cy, R, 56)
  if gr.arc then
    gr.setLineWidth(2); gr.setColor(C.brassS[1], C.brassS[2], C.brassS[3], 0.5)
    gr.arc("line", "open", cx, cy, R - 1, math.pi * 1.15, math.pi * 1.7)
  end
  gr.setLineWidth(1); gr.setColor(C.iron[1], C.iron[2], C.iron[3], 1); gr.circle("line", cx, cy, rIn + 1, 56)
  gr.setColor(1, 1, 1, 1)
end

-- ── DESCENT BAR (10 victoires) — §2.8. `total` segments égaux (def 10) ; les `wins` premiers GAGNÉS (laiton
-- brass→brass-l) / les restants sombres + liseré pierre. x,y,w,h ; renvoie h. gap = écart inter-segments.
function Gauge.descent(x, y, w, h, wins, total, gap)
  total = total or 10
  wins = math.max(0, math.min(wins or 0, total))
  h = h or 8
  gap = gap or 2
  local gr = g()
  x, y, w = floor(x), floor(y), floor(w)
  local segW = (w - gap * (total - 1)) / total
  for i = 1, total do
    local sx = x + (i - 1) * (segW + gap)
    if i <= wins then
      -- gagné : laiton (brass profond + crête brass-l).
      Draw.rect(sx, y, segW, h, C.brass, nil)
      if gr then
        gr.setColor(C.brassL[1], C.brassL[2], C.brassL[3], 1)
        gr.rectangle("fill", floor(sx), y, math.ceil(segW), max(1, floor(h * 0.4)))
        gr.setColor(1, 1, 1, 1)
      end
    else
      Draw.rect(sx, y, segW, h, C.stone900, C.stone700, 1)
    end
  end
  return h
end

return Gauge
