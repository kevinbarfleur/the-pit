-- src/fx/nightmare_bg.lua
-- FOND CAUCHEMARDESQUE (combat) — RENDER pur. Deux couches :
--   1) un CHAMP shader plein écran : base UNIE sombre (abysse) + distorsion onirique (domain warp) + DOUBLE/
--      TRIPLE VISION agressive (split RGB animé + 2 fantômes) + vignette + grain + respiration ;
--   2) des YEUX qui s'ouvrent de temps en temps — LES VRAIS YEUX DU PIT (`src/ui/eye.lua` via le pipeline de
--      bake `Forge.newWidget`/`render`/`blit`) : sclère blanche, VEINES injectées de sang, iris OR à pupille en
--      FENTE, paupières métal, clignement. Chaque œil REGARDE le centre (le joueur) = menace, et porte un SPLIT
--      chromatique (R/B décalés en additif) pour s'inscrire dans la double vision.
--
-- Pourquoi réutiliser Eye/Forge plutôt qu'un œil shader « maison » : la DA de l'œil est DÉJÀ établie et soignée
-- (body-horror brass). Un œil refait à la main casserait la cohérence (retour user). On s'appuie sur le meilleur
-- de l'existant. Forge a déjà synchronisé la palette de l'œil (syncEye au require) -> Forge.drawEye = bon rendu.
--
-- Syntaxe GLSL LÖVE (cible 11.5, calquée sur postfx.lua/lifeorb.lua) : effect(color,tex,tc,sc) ; Texel ;
-- extern (=uniform) ; number (=float) ; GLSL 1.20. On peint un quad blanc 1×1 étiré -> tc couvre 0..1.
--
-- HEADLESS-SAFE : sous le mock LÖVE, newShader/Forge.real() sont faux -> draw() retombe sur un aplat sombre,
-- les yeux ne bakent pas (Forge no-op). 100% RENDER -> golden neutre. Horloge = dt mural.

local Theme = require("src.ui.theme")
local Forge = require("src.ui.forge") -- pipeline de bake (newWidget/render/blit) + Forge.drawEye (palette synchronisée)

local NightmareBG = {}
NightmareBG.__index = NightmareBG

-- ── CHAMP shader (couche 1) : aucune entrée texture, tout procédural ─────────────────────────────────
local SHADER_SRC = [[
extern number time;       // horloge murale (s)
extern vec2 res;          // dimensions du rect de destination (px) -> correction d'aspect
extern number intensity;  // maître d'intensité global (0..1)
extern number bright;     // 0 = normal (combat/défaite) ; >0 = VICTOIRE (éclaircit + réchauffe, borné = lisible)
extern number split;      // force de la DOUBLE/TRIPLE VISION (séparation RGB) — « violent » par défaut
extern vec3 baseTint;     // base UNIE sombre (abysse/void)
extern vec3 veinTint;     // teinte des veines/structure émergente (sang sombre / violet)

number hash21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
number vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  number a = hash21(i), b = hash21(i + vec2(1.0, 0.0));
  number c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
number fbm(vec2 p){
  number s = 0.0; number a = 0.5;
  for (int i = 0; i < 5; i++){ s += a * vnoise(p); p = p * 2.02 + vec2(1.7, -1.3); a *= 0.5; }
  return s;
}
number field(vec2 p, number t){
  vec2 q = vec2(fbm(p + vec2(0.0, t * 0.10)), fbm(p + vec2(5.2, -t * 0.12)));
  vec2 r = vec2(fbm(p + 3.5 * q + vec2(1.7, 9.2) - t * 0.06),
                fbm(p + 3.5 * q + vec2(8.3, 2.8) + t * 0.05));
  return fbm(p + 3.0 * r);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc){
  number aspect = res.x / max(res.y, 1.0);
  vec2 p = vec2(tc.x * aspect, tc.y);
  number t = time;

  // ══ DOUBLE / TRIPLE VISION : 3 échantillons à offsets qui dérivent + 2 fantômes -> fantômes RGB baveux.
  number sp = split * (0.6 + 0.4 * sin(t * 0.7));
  vec2 dr = vec2(cos(t * 0.5), sin(t * 0.37));
  number fR = field((p + dr * sp) * 2.4, t);
  number fG = field(p * 2.4, t + 0.3);
  number fB = field((p - dr * sp) * 2.4, t);
  number g2 = field(p * 2.4 + vec2(0.3, -0.2) + dr * sp * 1.8, t * 1.1);
  number g3 = field(p * 2.4 - vec2(0.21, 0.27) - dr * sp * 2.6, t * 0.92);
  vec3 f = mix(vec3(fR, fG, fB), vec3(g2), 0.42);
  f = mix(f, vec3(g3), 0.30);
  number v = (f.r + f.g + f.b) / 3.0;

  vec3 col = baseTint;
  number vein = smoothstep(0.52, 0.92, v);
  col = mix(col, veinTint, vein * 0.62);
  col.r += (f.r - v) * 1.25;
  col.b += (f.b - v) * 1.25;
  col = max(col, vec3(0.0));

  number breath = 0.5 + 0.5 * sin(t * 0.5);
  col *= 0.82 + 0.18 * breath;
  vec2 cc = vec2((tc.x - 0.5) * aspect, tc.y - 0.5);
  number rr = length(cc);
  col *= 1.0 - smoothstep(0.42, 1.15, rr) * 0.62;
  number gr = hash21(sc + vec2(t * 53.0, t * 71.0)) - 0.5;
  col += gr * 0.028;

  // VICTOIRE : on éclaircit + réchauffe (le Puits respire la lumière du gagnant). Borné -> reste lisible.
  vec3 warm = col * 1.7 + vec3(0.20, 0.13, 0.05);
  col = mix(col, warm, clamp(bright, 0.0, 1.0) * 0.72);

  col *= intensity;
  return vec4(col, 1.0) * color;
}
]]

-- ── YEUX (couche 2) : VRAIS yeux du Pit, planifiés côté Lua (« de temps en temps ») ─────────────────
-- Chaque œil : ancre (uv, en PÉRIPHÉRIE pour loucher depuis le noir, pas derrière les unités), rayon (art px),
-- échelle de blit (entier, pixel-art net), période LONGUE + décalage (rare), sang (veines), type de pupille.
local EYE = {
  -- ax,   ay,    r,  px, période, décalage, sang, pupille
  { 0.085, 0.20, 15, 4, 10.0, 0.0, 0.75, "slit" },  -- haut-gauche (gros veilleur)
  { 0.915, 0.27, 12, 4, 12.5, 4.1, 0.85, "slit" },  -- haut-droite
  { 0.060, 0.78, 11, 3, 14.0, 8.3, 0.60, "round" }, -- bas-gauche
  { 0.940, 0.74, 14, 4, 11.0, 2.2, 0.70, "slit" },  -- bas-droite
  { 0.500, 0.07, 10, 3, 13.0, 9.6, 0.60, "slit" },  -- haut-centre (lointain)
  { 0.300, 0.95, 9,  3, 9.0,  5.4, 0.85, "round" }, -- bas (petit, sanglant)
}
-- Positions des yeux pour l'ÉCRAN DE FIN (verdict) : sur les BORDS/COINS sombres (hors contenu du bilan) ->
-- « plusieurs yeux qui te fixent depuis les marges ». Réutilise les mêmes widgets/rayons (index aligné sur EYE).
local VPOS = {
  { 0.055, 0.16 }, { 0.945, 0.15 }, { 0.035, 0.54 }, { 0.965, 0.52 }, { 0.150, 0.90 }, { 0.855, 0.92 },
}
local OPEN_FRAC = 0.26 -- part de la période où l'œil est ouvert (~rare)

-- Ouverture (0 hors fenêtre, sinon rampe -> plateau -> rampe). Le clignement NATUREL est porté par Eye.draw.
local function eyeOpenness(t, period, offset)
  local ph = ((t + offset) % period) / period
  if ph > OPEN_FRAC then return 0.0 end
  local x = ph / OPEN_FRAC
  if x < 0.16 then return x / 0.16
  elseif x > 0.84 then return (1.0 - x) / 0.16
  else return 1.0 end
end

-- ── Construction ────────────────────────────────────────────────────────────────────────────────────
local function graphicsReady()
  local g = love and love.graphics
  return g and g.newShader and g.newImage and love.image and love.image.newImageData and true or false
end

function NightmareBG.new(seed)
  local self = setmetatable({
    t = 0,
    seed = seed or 0,
    shader = nil,
    white = nil,     -- image 1×1 (support du quad plein écran -> tc 0..1)
    eyeW = {},       -- widget Forge par œil (bake réutilisé ; ré-rendu chaque frame quand ouvert)
  }, NightmareBG)

  if graphicsReady() then
    local ok, sh = pcall(love.graphics.newShader, SHADER_SRC)
    if ok and sh then
      self.shader = sh
      local void = Theme.c.void or { 0.02, 0.012, 0.03 }
      local vein = Theme.c.bloodDeep or { 0.28, 0.07, 0.05 }
      pcall(sh.send, sh, "baseTint", { void[1], void[2], void[3] })
      pcall(sh.send, sh, "veinTint", { vein[1] * 0.7, vein[2] * 0.7, vein[3] * 0.8 })
      pcall(sh.send, sh, "intensity", 1.0)
      pcall(sh.send, sh, "split", 0.085)
    end
    pcall(function()
      local id = love.image.newImageData(1, 1)
      id:setPixel(0, 0, 1, 1, 1, 1)
      self.white = love.graphics.newImage(id)
    end)
    -- widgets Forge des yeux : un tampon par œil, dimensionné à 2r + marge (paupières/gaze). Baké à la demande.
    for i = 1, #EYE do
      local r = EYE[i][3]
      local side = 2 * r + 8
      self.eyeW[i] = Forge.newWidget(side, side)
    end
  end
  return self
end

function NightmareBG:update(dt)
  dt = dt or 0
  if dt < 0 then dt = 0 end
  self.t = self.t + dt
end

-- Composite UN œil baké à l'écran avec un SPLIT chromatique (base nette + fantômes R/B en additif décalés)
-- -> l'œil s'inscrit dans la double vision du fond. px = échelle entière (pixel-art net). cxs,cys = CENTRE écran.
local function blitEyeSplit(img, cxs, cys, px, split)
  local g = love.graphics
  if not (img and g and g.draw) then return end
  local iw, ih = img:getDimensions()
  local x = math.floor(cxs - iw * px / 2)
  local y = math.floor(cys - ih * px / 2)
  -- fantômes chromatiques d'abord (additif, décalés) : R poussé d'un côté, B de l'autre -> frange de double vision.
  if g.setBlendMode then
    g.setBlendMode("add")
    g.setColor(0.95, 0.05, 0.10, 0.55); g.draw(img, x + split, y, 0, px, px)
    g.setColor(0.10, 0.25, 0.95, 0.55); g.draw(img, x - split, y, 0, px, px)
    g.setBlendMode("alpha")
  end
  -- œil net par-dessus (lecture franche du regard).
  g.setColor(1, 1, 1, 1); g.draw(img, x, y, 0, px, px)
  g.setColor(1, 1, 1, 1)
end

-- COUCHE 1 — CHAMP shader seul (base sombre + double/triple vision + vignette/grain). `bright` rampe à la
-- VICTOIRE. Séparé des yeux pour qu'un écran (bilan) puisse intercaler un voile de lisibilité ENTRE le champ
-- (assombrissable) et les yeux (qui doivent rester prominents). opts = { verdict, verdictT } (cf. draw).
function NightmareBG:drawField(dx, dy, dw, dh, opts)
  if not (love and love.graphics) then return end
  local g = love.graphics
  local verdict = opts and opts.verdict
  local vT = (opts and opts.verdictT) or 0
  if self.shader and self.white then
    local bright = (verdict == "win") and math.min(1.0, vT / 0.5) or 0.0
    pcall(function()
      self.shader:send("time", self.t)
      self.shader:send("res", { dw, dh })
      self.shader:send("bright", bright)
    end)
    g.setShader(self.shader); g.setColor(1, 1, 1, 1)
    g.draw(self.white, dx, dy, 0, dw, dh)
    g.setShader(); g.setColor(1, 1, 1, 1)
  else
    local void = Theme.c.void or { 0.02, 0.012, 0.03 }
    g.setColor(void[1], void[2], void[3], 1); g.rectangle("fill", dx, dy, dw, dh); g.setColor(1, 1, 1, 1)
  end
end

-- COUCHE 2 — les VRAIS yeux du Pit (Eye.draw via Forge), regard vers le CENTRE (le joueur). Comportement
-- selon le verdict : "loss" = grands ouverts, TREMBLANTS, SANGLANTS ; "win" = se FERMENT (éblouis) ; nil =
-- combat (ouverts « de temps en temps »). Dessiné À PART pour rester prominent au-dessus d'un voile de bilan.
function NightmareBG:drawEyes(dx, dy, dw, dh, opts)
  if not (love and love.graphics) then return end
  local g = love.graphics
  local verdict = opts and opts.verdict
  local vT = (opts and opts.verdictT) or 0
  local t = self.t
  local ccx, ccy = dx + dw * 0.5, dy + dh * 0.5
  for i = 1, #EYE do
    local e = EYE[i]
    local open, tremble, blood
    if verdict == "loss" then
      open, tremble, blood = 1.0, true, math.min(1.0, e[7] + 0.20)
    elseif verdict == "win" then
      open, tremble, blood = math.max(0.40, 1.0 - vT / 0.8), false, e[7] -- se SEMI-ferment (éblouis), JAMAIS clos
    else
      open, tremble, blood = eyeOpenness(t, e[5], e[6]), false, e[7]
    end
    if open > 0.02 then
      local w = self.eyeW[i]
      if w then
        local r, px = e[3], e[4]
        -- ancre : positions du VERDICT (bords sombres du bilan) si un verdict est en cours, sinon position de combat.
        local ax = verdict and VPOS[i][1] or e[1]
        local ay = verdict and VPOS[i][2] or e[2]
        local cxs = dx + ax * dw + math.sin(t * 0.13 + i * 1.3) * 6
        local cys = dy + ay * dh + math.cos(t * 0.11 + i * 2.0) * 5
        if tremble then -- DÉFAITE : tremblement nerveux haute fréquence, faible amplitude.
          cxs = cxs + math.sin(t * 22.0 + i * 3.1) * 2.4
          cys = cys + math.cos(t * 19.0 + i * 2.3) * 2.4
        end
        local aw, ah = w.aw, w.ah
        local gdx, gdy = ccx - cxs, ccy - cys
        local gl = math.sqrt(gdx * gdx + gdy * gdy); if gl < 1 then gl = 1 end
        local gaze = { aw / 2 + (gdx / gl) * r, ah / 2 + (gdy / gl) * r }
        local seed = i * 131 + 7
        local img = Forge.render(w, function(buf)
          Forge.drawEye(buf, math.floor(aw / 2), math.floor(ah / 2), r, open, 0.55, t, seed,
            { blood = blood, pupil = e[8], gaze = gaze })
        end, t)
        if g.setBlendMode then -- halo ambré qui COUVE (∝ ouverture), falloff lisse (14 disques).
          local gr = r * px * 1.9
          g.setBlendMode("add")
          for k = 14, 1, -1 do g.setColor(0.80, 0.56, 0.24, 0.012 * open); g.circle("fill", cxs, cys, gr * k / 14) end
          g.setBlendMode("alpha"); g.setColor(1, 1, 1, 1)
        end
        blitEyeSplit(img, cxs, cys, px, math.max(1, math.floor(px * 1.4 + 0.5)))
      end
    end
  end
end

-- Fond COMPLET (combat) : champ + yeux d'affilée (aucun voile entre les deux). opts = { verdict, verdictT }.
function NightmareBG:draw(dx, dy, dw, dh, opts)
  self:drawField(dx, dy, dw, dh, opts)
  self:drawEyes(dx, dy, dw, dh, opts)
end

return NightmareBG
