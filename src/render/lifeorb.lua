-- src/render/lifeorb.lua
-- GLOBE DE VIE « nightmare-forge » (Forge UI.dc.html : « the orb hides a swimmer ») — rendu PIXEL NET + shader
-- cosmardesque. On peint l'orbe dans un CANVAS basse-résolution (≈ boîte/4) puis on le blit ×4 en NEAREST ->
-- gros pixels durs « authored low-res, blown up ×4 » (la signature de la DA). Le blit passe par un SHADER
-- eldritch : gauchissement d'UV lent (« ça se tord »), dérive chromatique au bord, halo violet qui RESPIRE,
-- moucheture sombre qui dérive. Le LIQUIDE = sang (niveau = vies/max), surface ondulée ; le NAGEUR = serpent
-- effilé quasi-noir qui traverse périodiquement (réf docs/pixel-art/forge-px.js « ORBE + nageuse »), œil pâle.
--
-- HEADLESS-SAFE : newCanvas/newShader ABSENTS du mock LÖVE -> fallback Gauge.lifeOrb (primitives lisses,
-- no-op sous le mock). RENDER pur (aucune SIM) -> golden neutre. Vérifs API : love2d.org/wiki (Canvas/Shader,
-- cible 11.5) ; syntaxe GLSL LÖVE calquée sur src/render/postfx.lua (effect/Texel/extern/number).

local Theme = require("src.ui.theme")
local Gauge = require("src.ui.gauge")
local C = Theme.c

local LifeOrb = {}

local floor, ceil, sqrt, sin = math.floor, math.ceil, math.sqrt, math.sin
local min, max = math.min, math.max
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

local canvas, cw0, ch0, shader, shaderTried

-- ── Shader cosmardesque (appliqué au BLIT du canvas). GLSL LÖVE 1.20 : effect(color,tex,tc,sc) ; Texel ;
-- extern (=uniform) ; number (=float). Aucune boucle dynamique. ──
local SHADER_SRC = [[
extern number time;   // s
extern number low;    // 0..1 : intensité « vies basses » (monte le malaise)
extern vec2 res;      // taille du canvas (px) — ancre la moucheture sur la grille
number h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc){
  vec2 cc = tc - vec2(0.5);
  number r = length(cc);
  vec2 dir = (r > 0.0001) ? (cc / (r + 0.0001)) : vec2(0.0);
  // gauchissement « qui se tord » : sinus radial qui s'écoule dans le temps (plus fort au bord / vies basses).
  number warp = sin(r * 16.0 - time * 2.2) * 0.010 * (0.45 + low * 0.9);
  vec2 wuv = tc + dir * warp;
  // dérive chromatique vers le bord (eldritch) — discrète (pas « glitch VHS »).
  number ca = (0.0035 + 0.010 * low) * smoothstep(0.20, 0.5, r);
  vec4 o;
  o.r = Texel(tex, wuv + dir * ca).r;
  o.g = Texel(tex, wuv).g;
  o.b = Texel(tex, wuv - dir * ca).b;
  o.a = Texel(tex, wuv).a;
  // halo violet qui RESPIRE au bord (horreur cosmique), seulement là où il y a de l'orbe (a>0).
  number rim = smoothstep(0.30, 0.5, r);
  number breathe = 0.5 + 0.5 * sin(time * 1.3);
  o.rgb += vec3(0.16, 0.04, 0.26) * rim * o.a * (0.08 + 0.10 * breathe + 0.30 * low);
  // moucheture sombre lente qui dérive dans le liquide (malaise).
  number m = h21(floor(tc * res + vec2(0.0, floor(time * 6.0))));
  o.rgb *= 1.0 - 0.10 * step(0.87, m) * o.a;
  return o * color;
}
]]

-- Peint l'orbe (verre + liquide + nageur + anneau) dans le canvas COURANT, en coords PIXEL (0..cw, 0..ch).
function LifeOrb._paint(cw, ch, lives, max_, t)
  local g = love.graphics
  max_ = max_ or 5; lives = lives or 0; t = t or 0
  local frac = clamp01(lives / max_)
  local cx, cy = cw / 2, ch / 2
  local R = floor(min(cw, ch) / 2) - 1
  local rIn = R - 2
  if rIn < 3 then return end
  local low = lives <= 1
  local surfaceY = (cy + rIn) - frac * 2 * rIn
  local function waveAt(px) return surfaceY + sin(px * 0.6 + t * 2.0) * (rIn * 0.06) + sin(px * 0.3 - t * 1.3) * (rIn * 0.04) end

  -- VERRE : disque sombre + ombrage interne (lumière haut-gauche).
  g.setColor(C.stone900[1], C.stone900[2], C.stone900[3], 1); g.circle("fill", cx, cy, rIn, 44)
  g.setColor(C.void[1], C.void[2], C.void[3], 0.6); g.circle("fill", cx + rIn * 0.18, cy + rIn * 0.2, rIn * 0.86, 44)

  -- LIQUIDE : scanlines clippées au cercle (dégradé de profondeur), rectangles 1px = pixel net.
  if frac > 0.01 then
    for yy = ceil(surfaceY), ceil(cy + rIn) do
      local dyl = yy - cy
      local hw2 = rIn * rIn - dyl * dyl
      if hw2 > 0 then
        local hw = sqrt(hw2)
        local k = clamp01(0.12 + clamp01((yy - surfaceY) / (2 * rIn)) * 1.05)
        g.setColor(C.blood[1] + (C.bloodD[1] - C.blood[1]) * k, C.blood[2] + (C.bloodD[2] - C.blood[2]) * k,
          C.blood[3] + (C.bloodD[3] - C.blood[3]) * k, 1)
        g.rectangle("fill", floor(cx - hw), yy, ceil(2 * hw), 1)
      end
    end
    -- ménisque (crête de surface) : SEULEMENT quand la surface n'est pas collée au sommet (sinon points
    -- parasites sous l'anneau à vie pleine). Teinte sang clair, discrète.
    if frac < 0.96 then
      g.setColor(0.95, 0.42, 0.30, 0.6)
      for px = floor(cx - rIn), ceil(cx + rIn) do
        local wy = waveAt(px)
        if (px - cx) * (px - cx) < rIn * rIn and rIn * rIn - (wy - cy) * (wy - cy) > 0 then
          g.rectangle("fill", px, floor(wy), 1, 1)
        end
      end
    end
  end

  -- NAGEUR eldritch : serpent EFFILÉ quasi-noir qui traverse périodiquement (réf forge-px.js), œil pâle qui luit.
  if frac > 0.14 then
    local cyc = (t * 0.10 + 0.2) % 1
    if cyc < 0.66 then
      local prog = cyc / 0.66
      local hx = cx - rIn - 2 + prog * (2 * rIn + 4)
      local hy = cy + rIn * 0.16 + sin(t * 1.2) * rIn * 0.16
      for sg = 0, 8 do
        local bx = hx - sg * (rIn * 0.15)
        local by = hy + sin(t * 2.2 - sg * 0.55) * (rIn * 0.11)
        local br = max(0.6, 1.5 - sg * 0.12)
        if (bx - cx) * (bx - cx) + (by - cy) * (by - cy) <= (rIn - 1) * (rIn - 1) and by >= waveAt(bx) then
          g.setColor(0.05, 0.02, 0.07, 0.72)
          g.rectangle("fill", floor(bx - br), floor(by - br), ceil(2 * br) + 1, ceil(2 * br) + 1)
        end
      end
      local ex, ey = floor(hx), floor(hy)
      if (ex - cx) * (ex - cx) + (ey - cy) * (ey - cy) < (rIn - 1) * (rIn - 1) and ey >= waveAt(ex) then
        g.setColor(0.55, 0.25, 0.7, 0.5); g.rectangle("fill", ex - 1, ey - 1, 3, 3)   -- halo violet de l'œil
        g.setColor(0.92, 0.86, 0.7, 0.95); g.rectangle("fill", ex, ey, 1, 1)          -- pupille pâle
      end
    end
  end

  -- BULLES (pixels qui montent vers la surface).
  if frac > 0.12 then
    for i = 1, 3 do
      local ph = (t * (0.22 + i * 0.05) + i * 0.37) % 1
      local by = (cy + rIn) - ph * (frac * 2 * rIn)
      local bx = cx + sin(t * 1.1 + i * 2.1) * (rIn * 0.28) + (i - 2) * (rIn * 0.16)
      if by > waveAt(bx) and rIn * rIn - (by - cy) * (by - cy) > 0 then
        g.setColor(1, 0.82, 0.72, 0.18 * (1 - ph)); g.rectangle("fill", floor(bx), floor(by), 1, 1)
      end
    end
  end

  -- REFLET spéculaire (additif) : la bille de verre.
  if g.setBlendMode then
    g.setBlendMode("add"); g.setColor(1, 1, 1, 0.14)
    g.ellipse("fill", cx - rIn * 0.34, cy - rIn * 0.4, rIn * 0.36, rIn * 0.2, 14)
    g.setBlendMode("alpha")
  end

  -- ANNEAU de laiton + ourlet de fer ; vire au sang à 1 vie.
  local rim = low and { (C.brass[1] + C.blood[1]) / 2, (C.brass[2] + C.blood[2]) / 2, (C.brass[3] + C.blood[3]) / 2 } or C.brass
  g.setLineWidth(1); g.setColor(rim[1], rim[2], rim[3], 1); g.circle("line", cx, cy, R, 44)
  g.setColor(C.iron[1], C.iron[2], C.iron[3], 1); g.circle("line", cx, cy, rIn + 1, 44)
  g.setColor(1, 1, 1, 1)
end

-- DESSINE le globe dans (x,y,w,h) DESIGN. Pipeline : peinture basse-réso (canvas ≈ boîte/4) -> blit ×4 NEAREST
-- à travers le shader cosmardesque. Fallback (headless / GPU sans shader) : Gauge.lifeOrb (orbe lisse).
function LifeOrb.draw(x, y, w, h, lives, max_, t)
  local g = love.graphics
  if not (g and g.newCanvas and g.newShader and g.setCanvas and g.getCanvas) then
    return Gauge.lifeOrb(x, y, w, h, lives, max_, t)
  end
  local PIX = 4
  local cwv, chv = max(8, ceil(w / PIX)), max(8, ceil(h / PIX))
  if (not canvas) or cw0 ~= cwv or ch0 ~= chv then
    canvas = g.newCanvas(cwv, chv); if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
    cw0, ch0 = cwv, chv
  end
  if not shader and not shaderTried then
    shaderTried = true
    local ok, sh = pcall(g.newShader, SHADER_SRC); if ok then shader = sh end
  end
  -- 1) peinture basse-réso dans le canvas (transform NEUTRE -> coords pixel du canvas).
  local prev = g.getCanvas()
  g.push(); g.origin()
  g.setCanvas(canvas); g.clear(0, 0, 0, 0)
  LifeOrb._paint(cwv, chv, lives, max_, t)
  g.setCanvas(prev)
  g.pop()
  -- 2) blit ×PIX (nearest) à travers le shader cosmardesque, sous le transform DESIGN restauré.
  local lowI = ((lives or 0) <= 1) and 1 or (((lives or 0) <= 2) and 0.4 or 0)
  if shader then shader:send("time", t or 0); shader:send("low", lowI); shader:send("res", { cwv, chv }); g.setShader(shader) end
  g.setColor(1, 1, 1, 1)
  g.draw(canvas, x, y, 0, w / cwv, h / chv)
  if shader then g.setShader() end
  g.setColor(1, 1, 1, 1)
end

return LifeOrb
