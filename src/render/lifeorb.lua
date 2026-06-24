-- src/render/lifeorb.lua
-- GLOBE DE VIE « nightmare-forge » (= D2 « Resource orb » du handoff designer : « a silhouette crosses the
-- fluid »). RENDU LISSE (pas pixel) pour coller au côté NET de l'UI du jeu (retour user 2026-06 : « trop
-- pixellisé, rapproche-toi du côté net qu'on a »), PUIS des effets cauchemardesques par-dessus via SHADER.
--
-- Pipeline : on peint l'orbe en PRIMITIVES VECTORIELLES (cercles/ellipses/traits lissés) dans un CANVAS
-- SUPERSAMPLÉ (≈ boîte ×2, filtre LINÉAIRE) -> bords nets/anti-aliasés, jamais de gros pixels ; puis on le
-- blit à travers un SHADER cosmardesque (gauchissement d'UV lent, dérive chromatique discrète, halo violet
-- qui RESPIRE, moucheture sombre). LIQUIDE sang (niveau = vies/max) + surface ondulée + NAGEUR serpent effilé
-- (réf docs/pixel-art/forge-px.js « ORBE + nageuse »), œil pâle/violet ; bulles ; reflet ; anneau de laiton
-- (vire au sang à 1 vie).
--
-- HEADLESS-SAFE : newCanvas/newShader ABSENTS du mock -> fallback Gauge.lifeOrb (no-op sous le mock). RENDER
-- pur -> golden neutre. Syntaxe GLSL LÖVE calquée sur src/render/postfx.lua (effect/Texel/extern/number, 11.5).

local Theme = require("src.ui.theme")
local Gauge = require("src.ui.gauge")
local C = Theme.c

local LifeOrb = {}

local floor, ceil, sqrt, sin = math.floor, math.ceil, math.sqrt, math.sin
local min, max = math.min, math.max
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

local canvas, cw0, ch0, shader, shaderTried
local SS = 2 -- supersample : canvas = boîte ×SS (filtre linéaire) -> rendu lisse/anti-aliasé (« net »)

-- ── Shader cosmardesque (au BLIT). GLSL LÖVE 1.20 : effect(color,tex,tc,sc) ; Texel ; extern (=uniform) ;
-- number (=float). Effets « un peu » par-dessus le rendu net (retour user) : subtil par défaut. ──
local SHADER_SRC = [[
extern number time;   // s
extern number low;    // 0..1 : intensité « vies basses » (monte le malaise)
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc){
  vec2 cc = tc - vec2(0.5);
  number r = length(cc);
  vec2 dir = (r > 0.0001) ? (cc / (r + 0.0001)) : vec2(0.0);
  // gauchissement « qui se tord » : sinus radial qui s'écoule dans le temps (plus fort au bord / vies basses).
  number warp = sin(r * 16.0 - time * 2.2) * 0.008 * (0.4 + low * 0.9);
  vec2 wuv = tc + dir * warp;
  // dérive chromatique vers le bord (eldritch) — discrète.
  number ca = (0.0035 + 0.010 * low) * smoothstep(0.22, 0.5, r);
  vec4 o;
  o.r = Texel(tex, wuv + dir * ca).r;
  o.g = Texel(tex, wuv).g;
  o.b = Texel(tex, wuv - dir * ca).b;
  o.a = Texel(tex, wuv).a;
  // halo violet qui RESPIRE au bord (horreur cosmique), seulement là où il y a de l'orbe (a>0).
  number rim = smoothstep(0.30, 0.5, r);
  number breathe = 0.5 + 0.5 * sin(time * 1.3);
  o.rgb += vec3(0.16, 0.04, 0.26) * rim * o.a * (0.07 + 0.09 * breathe + 0.30 * low);
  // moucheture sombre lente sur une grille FIXE (indépendante de la résolution) qui dérive -> malaise.
  vec2 cell = floor(tc * 26.0 + vec2(0.0, floor(time * 5.0)));
  number m = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
  o.rgb *= 1.0 - 0.08 * step(0.9, m) * o.a;
  return o * color;
}
]]

-- Peint l'orbe (verre + liquide + nageur + anneau) dans le canvas COURANT, en coords PIXEL (0..cw, 0..ch).
-- TOUT en primitives VECTORIELLES lissées (tailles/épaisseurs proportionnelles au rayon -> net à toute échelle).
function LifeOrb._paint(cw, ch, lives, max_, t)
  local g = love.graphics
  max_ = max_ or 5; lives = lives or 0; t = t or 0
  local frac = clamp01(lives / max_)
  local cx, cy = cw / 2, ch / 2
  local R = min(cw, ch) / 2 - max(2, cw * 0.018)
  local rIn = R - max(2, R * 0.05)
  if rIn < 6 then return end
  local low = lives <= 1
  local SEG = 80 -- segments des cercles -> contour bien rond (lisse)
  local surfaceY = (cy + rIn) - frac * 2 * rIn
  local function waveAt(px) return surfaceY + sin(px * (3.0 / rIn) + t * 2.0) * (rIn * 0.05) + sin(px * (1.6 / rIn) - t * 1.3) * (rIn * 0.03) end

  -- VERRE : disque sombre + ombrage interne (lumière haut-gauche).
  g.setColor(C.stone900[1], C.stone900[2], C.stone900[3], 1); g.circle("fill", cx, cy, rIn, SEG)
  g.setColor(C.void[1], C.void[2], C.void[3], 0.6); g.circle("fill", cx + rIn * 0.16, cy + rIn * 0.18, rIn * 0.88, SEG)

  -- LIQUIDE : scanlines fines clippées au cercle (dégradé de profondeur) -> remplissage circulaire lisse.
  if frac > 0.01 then
    for yy = floor(surfaceY), ceil(cy + rIn) do
      local hw2 = rIn * rIn - (yy - cy) * (yy - cy)
      if hw2 > 0 then
        local hw = sqrt(hw2)
        local k = clamp01(0.12 + clamp01((yy - surfaceY) / (2 * rIn)) * 1.05)
        g.setColor(C.blood[1] + (C.bloodD[1] - C.blood[1]) * k, C.blood[2] + (C.bloodD[2] - C.blood[2]) * k,
          C.blood[3] + (C.bloodD[3] - C.blood[3]) * k, 1)
        g.rectangle("fill", cx - hw, yy, 2 * hw, 1.6)
      end
    end
    -- ménisque LISSE (crête de surface) : polyligne ; seulement quand la surface n'est pas collée au sommet.
    if frac < 0.97 then
      g.setColor(0.95, 0.42, 0.30, 0.7); g.setLineWidth(max(1, rIn * 0.045))
      local pts = {}
      for px = floor(cx - rIn), ceil(cx + rIn), 2 do
        local wy = waveAt(px)
        if (px - cx) * (px - cx) < rIn * rIn and rIn * rIn - (wy - cy) * (wy - cy) > 0 then
          pts[#pts + 1] = px; pts[#pts + 1] = wy
        end
      end
      if #pts >= 4 then g.line(pts) end
      g.setLineWidth(1)
    end
  end

  -- NAGEUR eldritch : serpent EFFILÉ (segments = cercles lissés, tapering) quasi-noir qui traverse
  -- périodiquement (réf forge-px.js « nageuse »), œil pâle/violet qui luit. Reste sous la surface et dans le cercle.
  if frac > 0.14 then
    local cyc = (t * 0.10 + 0.2) % 1
    if cyc < 0.66 then
      local prog = cyc / 0.66
      local hx = cx - rIn - rIn * 0.1 + prog * (2 * rIn + rIn * 0.2)
      local hy = cy + rIn * 0.16 + sin(t * 1.2) * rIn * 0.16
      for sg = 0, 10 do
        local bx = hx - sg * (rIn * 0.12)
        local by = hy + sin(t * 2.2 - sg * 0.5) * (rIn * 0.11)
        local br = max(rIn * 0.03, rIn * 0.13 - sg * rIn * 0.011)
        if (bx - cx) * (bx - cx) + (by - cy) * (by - cy) <= (rIn - br) * (rIn - br) and by >= waveAt(bx) then
          g.setColor(0.05, 0.02, 0.07, 0.78); g.circle("fill", bx, by, br, 18)
        end
      end
      if (hx - cx) * (hx - cx) + (hy - cy) * (hy - cy) < (rIn * 0.92) * (rIn * 0.92) and hy >= waveAt(hx) then
        g.setColor(0.55, 0.25, 0.7, 0.5); g.circle("fill", hx, hy, rIn * 0.055, 14)  -- halo violet de l'œil
        g.setColor(0.92, 0.86, 0.7, 0.95); g.circle("fill", hx, hy, rIn * 0.026, 12) -- pupille pâle
      end
    end
  end

  -- BULLES (petits cercles lisses qui montent vers la surface).
  if frac > 0.12 then
    for i = 1, 3 do
      local ph = (t * (0.22 + i * 0.05) + i * 0.37) % 1
      local by = (cy + rIn) - ph * (frac * 2 * rIn)
      local bx = cx + sin(t * 1.1 + i * 2.1) * (rIn * 0.28) + (i - 2) * (rIn * 0.16)
      if by > waveAt(bx) and rIn * rIn - (by - cy) * (by - cy) > 0 then
        g.setColor(1, 0.82, 0.72, 0.18 * (1 - ph)); g.circle("fill", bx, by, max(1, rIn * 0.022), 10)
      end
    end
  end

  -- REFLET spéculaire (additif) : la bille de verre.
  if g.setBlendMode then
    g.setBlendMode("add"); g.setColor(1, 1, 1, 0.13)
    g.ellipse("fill", cx - rIn * 0.34, cy - rIn * 0.4, rIn * 0.36, rIn * 0.2, 22)
    g.setBlendMode("alpha")
  end

  -- ANNEAU de laiton + ourlet de fer (lisses) ; vire au sang à 1 vie.
  local rim = low and { (C.brass[1] + C.blood[1]) / 2, (C.brass[2] + C.blood[2]) / 2, (C.brass[3] + C.blood[3]) / 2 } or C.brass
  g.setLineWidth(max(1.5, R * 0.055)); g.setColor(rim[1], rim[2], rim[3], 1); g.circle("line", cx, cy, R, SEG)
  g.setLineWidth(max(1, rIn * 0.03)); g.setColor(C.iron[1], C.iron[2], C.iron[3], 1); g.circle("line", cx, cy, rIn, SEG)
  g.setLineWidth(1); g.setColor(1, 1, 1, 1)
end

-- DESSINE le globe dans (x,y,w,h) DESIGN. Pipeline : peinture LISSE supersamplée (canvas ≈ boîte×SS, filtre
-- linéaire) -> blit à travers le shader cosmardesque. Fallback (headless / GPU sans shader) : Gauge.lifeOrb.
function LifeOrb.draw(x, y, w, h, lives, max_, t)
  local g = love.graphics
  if not (g and g.newCanvas and g.newShader and g.setCanvas and g.getCanvas) then
    return Gauge.lifeOrb(x, y, w, h, lives, max_, t)
  end
  local cwv, chv = max(16, ceil(w * SS)), max(16, ceil(h * SS))
  if (not canvas) or cw0 ~= cwv or ch0 ~= chv then
    canvas = g.newCanvas(cwv, chv); if canvas.setFilter then canvas:setFilter("linear", "linear") end
    cw0, ch0 = cwv, chv
  end
  if not shader and not shaderTried then
    shaderTried = true
    local ok, sh = pcall(g.newShader, SHADER_SRC); if ok then shader = sh end
  end
  -- 1) peinture LISSE haute-réso dans le canvas (transform NEUTRE -> coords pixel du canvas).
  local prev = g.getCanvas()
  g.push(); g.origin()
  g.setCanvas(canvas); g.clear(0, 0, 0, 0)
  LifeOrb._paint(cwv, chv, lives, max_, t)
  g.setCanvas(prev)
  g.pop()
  -- 2) blit (filtre linéaire -> lisse) à travers le shader cosmardesque, sous le transform DESIGN restauré.
  local lowI = ((lives or 0) <= 1) and 1 or (((lives or 0) <= 2) and 0.4 or 0)
  if shader then shader:send("time", t or 0); shader:send("low", lowI); g.setShader(shader) end
  g.setColor(1, 1, 1, 1)
  g.draw(canvas, x, y, 0, w / cwv, h / chv)
  if shader then g.setShader() end
  g.setColor(1, 1, 1, 1)
end

return LifeOrb
