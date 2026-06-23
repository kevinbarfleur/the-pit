-- src/render/postfx.lua
-- SURCOUCHE CAUCHEMARDESQUE — post-fx RENDER-pur appliqué PAR-DESSUS l'UI déjà nette (bible §6).
--
-- Donne la crasse/horreur d'ambiance SANS jamais reflouter le texte. La discipline (chèrement acquise) :
--   1. On rend toute la frame dans un Canvas à la RÉSOLUTION NATIVE (love.graphics.getDimensions()).
--   2. On blit ce canvas 1:1 (scale 1) à travers le shader -> aucun rééchantillonnage -> texte INTACT.
--   3. AUCUN flou plein écran (le flou adoucit le texte ; interdit ici). Effets = per-pixel, text-safe :
--        · vignette animée (assombrit coins/bords, se resserre à la tension ; centre épargné)
--        · grain de film animé (casse le « trop propre » ; RNG NON-seedé OK car 100% RENDER)
--        · palette-lock doux vers les teintes Wraeclast (tire les ombres/lumières vers braise/abysse —
--          le « même artiste » ; faible -> ne lave pas le texte)
--        · aberration chromatique RADIALE (forte aux bords, ~0 au centre = lisible) bornée à ~1px
--        · dither de Bayer 4×4 (gravure 1-bit subtile, cohérente pixel-art)
--        · pulsation de braise globale très lente (l'écran « respire » comme une chair froide)
--   Tout est AGRESSIF sur fond/bords/pics, RETENU au centre/sur le texte (bible §6).
--
-- FIREWALL : 100% RENDER (cosmétique). Ne lit/écrit aucune SIM. L'horloge vient de love.draw (dt mural).
-- HEADLESS-SAFE : sous le mock LÖVE, newShader/newCanvas/setShader sont ABSENTS -> self.available=false ->
--   tous les points d'entrée sont des NO-OP gardés (le jeu et toute la suite de tests tournent sans GPU).
--   Toute création/usage de ressource graphique est pcall-gardé : un asset/feature absent ne crashe jamais.
--
-- Syntaxe GLSL LÖVE (≠ générique, vérifiée sur love2d.org/wiki/Shader_Variables + newShader, cible 11.5) :
--   fonction obligatoire `effect(vec4 color, Image tex, vec2 tc, vec2 sc)` ; `Texel(tex,uv)` (PAS texture2D) ;
--   `extern` (= uniform) ; `number` (= float). GLSL 1.20 (aucune boucle dynamique -> pas de #pragma glsl3).
--   Le motif (shader + canvas créés UNE fois, pcall-gardés) est exactement celui d'affliction_fx.lua, prouvé.

local Theme = require("src.ui.theme")

local PostFX = {}
PostFX.__index = PostFX

-- ── Teintes de palette-lock (palette Wraeclast, depuis Theme.c -> floats 0..1) ─────────────────────
-- On tire les OMBRES vers l'abysse/void (violet très sombre) et les HAUTES LUMIÈRES vers la braise
-- (ember chaud). Résultat : l'UI nette importée prend la dominante « même artiste » du Puits.
local SHADOW = Theme.c.void   -- 0x050308 (presque noir, légère teinte violette)
local HILITE = Theme.c.ember  -- 0xc4663a (braise chaude) — pôle chaud du palette-lock

-- ── GLSL (per-pixel, text-safe ; aucun flou plein écran) ──────────────────────────────────────────
-- `tc` = UV [0..1] (centre 0.5,0.5) ; `sc` = pixel écran (pour grain/dither -> motif à la grille native).
local NIGHTMARE_GLSL = [[
extern number time;        // horloge murale (s) : grain/pulse/respiration
extern number tension;     // 0..1 : 0 = calme, 1 = l'écran se ferme (vignette + dérive)
extern number strength;    // 0..1 : maître d'intensité de TOUTE la surcouche (subtilité par défaut)
extern vec2 screen;        // dimensions natives du canvas (px) — pour ancrer grain/dither à la grille
extern vec3 shadowTint;    // pôle sombre du palette-lock (abysse/void)
extern vec3 hiliteTint;    // pôle chaud du palette-lock (braise)

// Hash 2D bon marché et stable (Wraeclast n'a pas besoin de bruit cher) -> grain/dither.
number hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Matrice de Bayer 4×4 (ordre de dither) -> seuil [0..1) par pixel écran. Gravure 1-bit subtile.
number bayer4(vec2 px) {
  int x = int(mod(px.x, 4.0));
  int y = int(mod(px.y, 4.0));
  int i = x + y * 4;
  // table 4x4 normalisée /16 (motif de dispersion standard)
  number b =
      (i==0)?0.0:(i==1)?8.0:(i==2)?2.0:(i==3)?10.0:
      (i==4)?12.0:(i==5)?4.0:(i==6)?14.0:(i==7)?6.0:
      (i==8)?3.0:(i==9)?11.0:(i==10)?1.0:(i==11)?9.0:
      (i==12)?15.0:(i==13)?7.0:(i==14)?13.0:5.0;
  return (b + 0.5) / 16.0;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  // Distance radiale au centre [0..~1] : pilote vignette ET aberration (fortes aux bords, ~0 au centre).
  vec2 d = tc - vec2(0.5);
  d.x *= screen.x / screen.y;        // corrige l'aspect -> vignette ovale régulière, pas étirée
  number r = length(d) * 1.41421356; // ~1.0 dans les coins

  // ── Aberration chromatique RADIALE : décale R/B le long du rayon, AMPLITUDE ∝ r² (centre intact). ──
  // r² -> quasi nul au centre (texte net) et marqué aux bords. Bornée ≈1px (à la résolution native).
  number ab = (r * r) * strength * (1.6 / max(screen.x, 1.0)) * (1.0 + tension * 1.5);
  vec2 dir = (r > 0.0001) ? (d / (length(d) + 0.0001)) : vec2(0.0);
  vec3 src;
  src.r = Texel(tex, tc + dir * ab).r;       // canal rouge tiré vers l'extérieur
  src.g = Texel(tex, tc).g;                   // vert pivot = NETTETÉ préservée (le texte reste piqué)
  src.b = Texel(tex, tc - dir * ab).b;        // canal bleu tiré vers l'intérieur
  vec3 col = src;

  // ── Palette-lock DOUX : tire ombres -> abysse, lumières -> braise (le « même artiste »). ──────────
  // Mélange par luminance, faible (×strength) -> teinte sans laver les couleurs ni écraser le contraste.
  number lum = dot(col, vec3(0.299, 0.587, 0.114));
  vec3 graded = mix(shadowTint, hiliteTint, clamp(lum, 0.0, 1.0));
  col = mix(col, graded, 0.14 * strength);

  // ── Posterize TRÈS doux (réduit la finesse des dégradés -> aspect gravé) — n'affecte pas le texte plein. ─
  number levels = 32.0;
  vec3 post = floor(col * levels + 0.5) / levels;
  col = mix(col, post, 0.25 * strength);

  // ── Dither de Bayer : casse le banding du posterize, ajoute le grain de gravure 1-bit (faible). ────
  number bdith = (bayer4(sc) - 0.5) * (1.0 / 255.0) * 6.0 * strength;
  col += bdith;

  // ── Grain de film ANIMÉ (RNG non-seedé : RENDER pur). Densité montée par la tension. ──────────────
  number g = hash21(sc + vec2(time * 53.0, time * 71.0)) - 0.5;
  col += g * (0.045 + 0.05 * tension) * strength;

  // ── Pulsation de braise GLOBALE très lente : l'écran « respire » (chair froide), + chaud aux bords. ─
  number breath = 0.5 + 0.5 * sin(time * 0.6);
  number ember = breath * (0.02 + 0.05 * r) * strength;   // discret au centre, plus marqué aux bords
  col += hiliteTint * ember * (0.5 + 0.5 * tension);

  // ── Vignette : assombrit coins/bords ; se RESSERRE quand la tension monte (l'écran « se ferme »). ──
  // smoothstep -> jamais sur le centre. À tension 0 : douce ; à tension 1 : oppressante.
  number vstart = mix(0.45, 0.30, tension);
  number vend   = mix(1.15, 0.92, tension);
  number vig = 1.0 - smoothstep(vstart, vend, r) * (0.55 * strength + 0.25 * tension * strength);
  col *= vig;

  // ── Scanline horizontale TRÈS subtile (rétro discret) — amplitude minime, pas un CRT (déforme pas le texte). ─
  number scan = 1.0 - 0.025 * strength * (0.5 + 0.5 * sin(sc.y * 3.14159265));
  col *= scan;

  return vec4(col, 1.0) * color;
}
]]

-- ── Détection de capacité (headless = pas de GPU/shader -> NO-OP propre) ───────────────────────────
local function graphicsReady()
  local g = love and love.graphics
  return g and g.newShader and g.newCanvas and g.setCanvas and g.setShader and g.getDimensions and true or false
end

-- Crée le canvas natif à la taille (w,h). pcall-gardé : un échec laisse self.canvas=nil -> bypass.
function PostFX:_ensureCanvas(w, h)
  if not self.available then return end
  if self.canvas and self.cw == w and self.ch == h then return end
  local ok, cv = pcall(love.graphics.newCanvas, w, h)
  if ok and cv then
    pcall(cv.setFilter, cv, "nearest", "nearest") -- 1:1, mais nearest = zéro adoucissement si jamais resamplé
    self.canvas, self.cw, self.ch = cv, w, h
  else
    self.canvas = nil -- échec -> on bypass cette frame (et les suivantes tant que la taille ne change pas)
  end
end

function PostFX.new()
  local self = setmetatable({
    enabled = true,     -- défaut ON, mais SUBTIL (strength modeste) — la lisibilité prime
    available = false,  -- passe à true si le shader compile (sinon NO-OP partout)
    strength = 0.85,    -- maître d'intensité (subtilité par défaut ; <1 garde l'UI lisible)
    t = 0,              -- horloge murale accumulée (s)
    active = false,     -- vrai entre beginFrame() et endFrame() (canvas engagé cette frame)
    cw = 0, ch = 0,
  }, PostFX)

  if graphicsReady() then
    local ok, sh = pcall(love.graphics.newShader, NIGHTMARE_GLSL)
    if ok and sh then
      self.shader = sh
      self.available = true
      -- Uniforms constants envoyés une fois (les teintes de palette ne changent pas).
      pcall(sh.send, sh, "shadowTint", { SHADOW[1], SHADOW[2], SHADOW[3] })
      pcall(sh.send, sh, "hiliteTint", { HILITE[1], HILITE[2], HILITE[3] })
    end
    -- Si newShader échoue (driver/GLSL), self.available reste false -> le jeu rend sans surcouche (pas de crash).
  end
  return self
end

-- TOGGLE [F9] : comparer ON/OFF. No-op si la surcouche n'est pas disponible (headless).
function PostFX:toggle()
  self.enabled = not self.enabled
  return self.enabled
end

-- Canvas ACTIF de la frame (cible de rendu courante) ou nil si la surcouche est inactive. main.lua s'en
-- sert pour RESTAURER la cible après les passes monde (un setCanvas() nu retournerait à l'écran et
-- court-circuiterait la capture). nil hors-fx -> setCanvas(nil) == écran (comportement par défaut intact).
function PostFX:currentCanvas()
  return self.active and self.canvas or nil
end

-- Ouvre la frame : redirige tout le dessin vers le canvas natif. Retourne true si on a bien engagé le
-- canvas (l'appelant fait son dessin normal quoi qu'il arrive ; ce booléen pilote juste endFrame).
-- dt = secondes murales (horloge des effets animés). w,h = dimensions NATIVES (love.graphics.getDimensions()).
function PostFX:beginFrame(dt, w, h)
  self.active = false
  if not (self.available and self.enabled) then return false end
  self.t = self.t + (dt or 0)
  self:_ensureCanvas(w, h)
  if not self.canvas then return false end
  local ok = pcall(function()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1) -- fond opaque : le shader sort vec4(col,1)
  end)
  if not ok then -- échec d'engagement -> on s'assure de rendre la cible par défaut et on bypass
    pcall(love.graphics.setCanvas)
    return false
  end
  self.active = true
  return true
end

-- Ferme la frame : décroche le canvas, puis le blit 1:1 (scale 1, position 0,0) à travers le shader.
-- 1:1 = ZÉRO rééchantillonnage -> le texte natif reste exactement net. tension = 0..1 (optionnel).
function PostFX:endFrame(tension)
  if not self.active then return end
  self.active = false
  local sh = self.shader
  pcall(function()
    love.graphics.setCanvas() -- retour à l'écran
    love.graphics.setShader(sh)
    sh:send("time", self.t)
    sh:send("tension", math.max(0, math.min(1, tension or 0)))
    sh:send("strength", self.strength)
    sh:send("screen", { self.cw, self.ch })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0) -- 1:1, pas de scale -> texte intact
    love.graphics.setShader()
  end)
end

return PostFX
