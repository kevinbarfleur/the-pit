-- feel-lab/lib/postfx.lua
-- SURCOUCHE « CAUCHEMARDESQUE » portée du jeu (src/render/postfx.lua) : un shader appliqué 1:1 sur TOUTE la
-- frame finale (texte/UI intacts, 0 rééchantillonnage). C'est CE qui unifie le look « clean, semi-net,
-- semi-pixélisé » : dither Bayer 4×4 (gravure 1-bit), grain de film, palette-lock Wraeclast (ombres→abysse,
-- hautes→braise, dérive violette), vignette, aberration chromatique radiale. RENDER pur, headless-safe.
--
-- API :
--   PostFX.new()                      -- crée shader + canvas (pcall-gardé ; no-op si GPU/shader absent)
--   postfx:beginFrame(time, sw, sh)   -- redirige le rendu dans le canvas natif ; renvoie fxOn (bool)
--   postfx:endFrame(tension)          -- blit le canvas à travers le shader (tension 0..1 ferme la vignette)
--   postfx:toggle() · postfx.on

local Theme = require("lib.theme")

local SRC = [[
extern number time;
extern number strength;
extern number tension;
extern vec3 shadowTint;   // abysse
extern vec3 hiliteTint;   // braise
extern vec3 rotTint;      // pourriture (violet)

// Bayer 4×4 ordonné (gravure), normalisé [0,1) — valeur par PIXEL ÉCRAN (sc)
number bayer4(vec2 px){
  int x = int(mod(px.x, 4.0));
  int y = int(mod(px.y, 4.0));
  int i = x + y * 4;
  number b =
    (i==0)?0.0:(i==1)?8.0:(i==2)?2.0:(i==3)?10.0:
    (i==4)?12.0:(i==5)?4.0:(i==6)?14.0:(i==7)?6.0:
    (i==8)?3.0:(i==9)?11.0:(i==10)?1.0:(i==11)?9.0:
    (i==12)?15.0:(i==13)?7.0:(i==14)?13.0:5.0;
  return (b + 0.5) / 16.0;
}
number hash21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec4 effect(vec4 col0, Image tex, vec2 uv, vec2 sc){
  vec2 cc = uv - 0.5;
  number r2 = dot(cc, cc);
  // aberration chromatique radiale (forte aux bords, ~0 au centre ; bornée)
  number ca = min(r2 * 0.010, 0.0020) * strength;
  vec3 col;
  col.r = Texel(tex, uv + cc * ca).r;
  col.g = Texel(tex, uv).g;
  col.b = Texel(tex, uv - cc * ca).b;

  number lum = dot(col, vec3(0.299, 0.587, 0.114));
  // palette-lock : tire ombres -> abysse, hautes -> braise (« même artiste »), faible
  col = mix(col, shadowTint, (1.0 - lum) * 0.14 * strength);
  col = mix(col, hiliteTint, lum * 0.10 * strength);
  // dérive violette dans les mid-tons (soupçon de pourriture)
  col = mix(col, rotTint, (1.0 - abs(lum - 0.5) * 2.0) * 0.05 * strength);

  // gravure : dither Bayer ±(6/255)
  col += (bayer4(sc) - 0.5) * (6.0 / 255.0) * strength;
  // grain de film animé
  number g = hash21(sc + vec2(time * 53.0, time * 71.0)) - 0.5;
  col += g * (0.026 + 0.05 * tension) * strength;

  // vignette (douce par défaut, se ferme avec la tension)
  number vig = smoothstep(0.98, 0.42, length(cc));
  col *= mix(1.0, vig, (0.30 + 0.45 * tension) * strength);

  return vec4(col, 1.0) * col0;
}
]]

local PostFX = {}
PostFX.__index = PostFX

local function H(t) return { t[1], t[2], t[3] } end

function PostFX.new()
  local self = setmetatable({ on = true, strength = 1.0 }, PostFX)
  if not (love and love.graphics and love.graphics.newShader) then self.on = false; return self end
  local ok, sh = pcall(love.graphics.newShader, SRC)
  if not ok then self.shader = nil; self.on = false; return self end
  self.shader = sh
  return self
end

function PostFX:ensure(sw, sh)
  if self.canvas and self.cw == sw and self.ch == sh then return end
  self.canvas = love.graphics.newCanvas(sw, sh)
  self.canvas:setFilter("nearest", "nearest")
  self.cw, self.ch = sw, sh
end

-- redirige tout le rendu dans le canvas natif. Renvoie true si la surcouche est active.
function PostFX:beginFrame(time, sw, sh)
  if not (self.on and self.shader) then return false end
  self:ensure(sw, sh)
  self.time = time or 0
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear(0, 0, 0, 1)
  return true
end

-- décroche le canvas et le blit à travers le shader.
function PostFX:endFrame(tension)
  if not (self.on and self.shader and self.canvas) then return end
  love.graphics.setCanvas()
  local c = Theme.c
  self.shader:send("time", self.time or 0)
  self.shader:send("strength", self.strength or 1.0)
  self.shader:send("tension", math.max(0, math.min(1, tension or 0)))
  self.shader:send("shadowTint", H(c.void))
  self.shader:send("hiliteTint", H(c.ember))
  self.shader:send("rotTint", H(c.rot))
  love.graphics.setShader(self.shader)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0)
  love.graphics.setShader()
end

function PostFX:toggle() self.on = not self.on and (self.shader ~= nil); return self.on end

return PostFX
