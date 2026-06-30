-- feel-lab/lib/transition.lua
-- TRANSITION MANAGER — enrobe un changement de scène (le « swap brutal » de host.goto = le problème #1).
-- Modèle (recherche §1-2) : on SNAPSHOTTE la frame sortante dans un canvas FROZEN au démarrage, l'appelant
-- bascule la scène TOUT DE SUITE, puis chaque frame on rend la scène entrante (live) dans un 2e canvas et on
-- BLENDE les deux selon `progress` et `kind`. RENDER pur, headless-safe (no-op si love.graphics absent),
-- piloté par le dt MURAL (jamais la sim) -> zéro impact déterminisme.
--
-- APIs LÖVE vérifiées (11.5) :
--   love.graphics.newCanvas / setCanvas  https://love2d.org/wiki/love.graphics.newCanvas
--   setBlendMode("alpha","premultiplied") pour blitter un Canvas  https://love2d.org/wiki/love.graphics.setBlendMode
--   love.graphics.stencil / setStencilTest (iris sans shader)  https://love2d.org/wiki/love.graphics.stencil
--   love.graphics.newShader / Shader:send (dissolve/pixelate)  https://love2d.org/wiki/Shader:send
--
-- PLUSIEURS techniques comparables (l'user veut juger) :
--   fade_black · crossfade · slide_left/right/up/down · iris_in · dissolve · burn · pixelate
--   blood_rain · blood_bloom · blood_button
--
-- API :
--   Transition.new()
--   tr:start(kind, dur, drawCurrent)   -- snapshot la scène sortante (drawCurrent rend dans le canvas actif)
--   tr:update(dt)                       -- avance progress ; désactive à la fin
--   tr:draw(drawNext)                   -- rend la scène entrante (live) + blende ; true si une transition joue
--   tr.active

local Transition = {}
Transition.__index = Transition
local Liquid = require("lib.liquid")

-- ── Shaders (pcall-gardés ; repli crossfade si compilation échoue/headless) ──────────────────────────────
local DISSOLVE_SRC = [[
  extern number progress;   // 0..1
  extern number feather;    // largeur de lisière
  extern vec4 edgeColor;    // teinte du front (braise/sang)
  float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
  float vnoise(vec2 p){
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash(i), b = hash(i+vec2(1.,0.)), c = hash(i+vec2(0.,1.)), d = hash(i+vec2(1.,1.));
    vec2 u = f*f*(3.-2.*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
  }
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
    float n = vnoise(uv * 14.0);
    float a = smoothstep(progress, progress + feather, n);   // 1 = encore là, 0 = dissous
    vec4 c = Texel(tex, uv);
    // front incandescent : anneau où a vient de tomber
    float edge = smoothstep(progress - feather, progress, n) * (1.0 - a);
    vec3 rgb = mix(c.rgb, edgeColor.rgb, edge * edgeColor.a);
    return vec4(rgb, c.a) * vec4(1.0,1.0,1.0, a) * color;
  }
]]

local PIXELATE_SRC = [[
  extern number amount;     // taille de bloc (1 = net, grand = gros pixels)
  extern vec2 res;          // résolution du canvas
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
    vec2 grid = max(vec2(1.0), vec2(amount));
    vec2 cell = grid / res;
    vec2 quv = (floor(uv / cell) + 0.5) * cell;
    return Texel(tex, quv) * color;
  }
]]

local BLOOD_DISSOLVE_SRC = [[
  extern number reveal;     // 0..1 : 0 = sang plein, 1 = dissous
  extern number time;
  extern vec2 origin;        // source normalisée pour la version bloom
  extern number mode;        // 0 = rain, 1 = bloom
  float hash(vec2 p){ return fract(sin(dot(p, vec2(37.17, 117.31))) * 43758.5453); }
  float vnoise(vec2 p){
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash(i), b = hash(i+vec2(1.,0.)), c = hash(i+vec2(0.,1.)), d = hash(i+vec2(1.,1.));
    vec2 u = f*f*(3.-2.*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
  }
  float fbm(vec2 p){
    float v = 0.0;
    float a = 0.52;
    for (int i = 0; i < 4; i++) {
      v += vnoise(p) * a;
      p = p * 2.03 + vec2(17.3, 9.1);
      a *= 0.5;
    }
    return v;
  }
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
    vec4 c = Texel(tex, uv) * color;
    if (c.a <= 0.001) return c;
    vec2 grid = vec2(192.0, 108.0);
    vec2 q = (floor(uv * grid) + 0.5) / grid;
    vec2 warp = vec2(
      fbm(q * 3.2 + vec2(time * 0.055, -time * 0.035)),
      fbm(q * 3.2 + vec2(8.2 - time * 0.025, 5.1 + time * 0.045))
    ) - 0.5;
    vec2 p = q + warp * 0.105;
    float cloud = fbm(p * 14.0 + vec2(time * 0.07, -time * 0.09));
    float detail = fbm(p * 42.0 + vec2(-time * 0.22, time * 0.16));
    float grit = hash(floor(q * grid) + floor(time * 9.0));
    float ridge = 1.0 - abs(fbm(p * 24.0 + vec2(time * 0.10, 3.7)) * 2.0 - 1.0);
    float veins = smoothstep(0.72, 0.97, ridge);
    float radial = clamp(distance(q, origin) * 1.30, 0.0, 1.0);
    float vertical = q.y;
    float directional = mix(vertical, radial, step(0.5, mode));
    float field = clamp(cloud * 0.35 + detail * 0.32 + grit * 0.18 + directional * 0.04 + veins * 0.38, 0.0, 1.0);
    float feather = 0.085;
    float keep = smoothstep(reveal - feather, reveal + feather, field);
    float edge = smoothstep(reveal - 0.075, reveal, field) * (1.0 - smoothstep(reveal, reveal + 0.105, field));
    float ember = edge * (0.55 + veins * 0.75);
    c.rgb = mix(c.rgb, vec3(1.0, 0.18, 0.07), ember * 0.78);
    c.rgb += vec3(0.24, 0.06, 0.015) * ember;
    c.a *= max(keep, edge * 0.56);
    return c;
  }
]]

local BLOOD_NIGHTMARE_SRC = [[
  extern number time;
  extern number strength;
  extern vec2 origin;
  float hash(vec2 p){ return fract(sin(dot(p, vec2(91.13, 47.71))) * 43758.5453); }
  float vnoise(vec2 p){
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash(i), b = hash(i+vec2(1.,0.)), c = hash(i+vec2(0.,1.)), d = hash(i+vec2(1.,1.));
    vec2 u = f*f*(3.-2.*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
  }
  float fbm(vec2 p){
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
      v += vnoise(p) * a;
      p = p * 2.07 + vec2(11.7, 5.3);
      a *= 0.5;
    }
    return v;
  }
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
    vec2 q = uv;
    vec2 fromOrigin = q - origin;
    vec2 dir = normalize(fromOrigin + vec2(0.0001, -0.0002));
    float pulse = 0.72 + 0.28 * sin(time * 4.4 + fbm(q * 5.0) * 5.5);
    vec2 warp = vec2(
      fbm(q * 5.2 + vec2(time * 0.18, -time * 0.11)),
      fbm(q * 5.2 + vec2(7.4 - time * 0.13, 3.1 + time * 0.16))
    ) - 0.5;
    float radial = sin(length(fromOrigin) * 31.0 - time * 5.2) * 0.5 + 0.5;
    vec2 duv = warp * 0.011 * strength + dir * (radial - 0.5) * 0.006 * strength * pulse;
    vec2 baseUv = clamp(q + duv, vec2(0.001), vec2(0.999));
    vec2 ghostA = clamp(baseUv + vec2(0.006, -0.003) * strength, vec2(0.001), vec2(0.999));
    vec2 ghostB = clamp(baseUv + vec2(-0.008, 0.004) * strength, vec2(0.001), vec2(0.999));
    vec4 base = Texel(tex, baseUv);
    vec4 violet = Texel(tex, ghostA);
    vec4 red = Texel(tex, ghostB);
    float edge = smoothstep(0.18, 0.92, fbm(q * 12.0 + vec2(time * 0.21, 2.4)));
    vec3 rgb = base.rgb;
    rgb = mix(rgb, violet.rgb * vec3(0.46, 0.22, 0.86), 0.15 * strength);
    rgb = mix(rgb, red.rgb * vec3(0.82, 0.12, 0.22), 0.07 * strength);
    rgb *= 1.0 - 0.18 * strength;
    rgb = mix(rgb, vec3(0.025, 0.012, 0.055), 0.11 * strength + edge * 0.04 * strength);
    rgb += vec3(0.055, 0.015, 0.10) * edge * strength;
    return vec4(rgb, base.a) * color;
  }
]]

local function tryShader(src)
  if not (love and love.graphics and love.graphics.newShader) then return nil end
  local ok, sh = pcall(love.graphics.newShader, src)
  return ok and sh or nil
end

function Transition.new()
  local self = setmetatable({ active = false, t = 0, dur = 0.3, kind = "fade_black" }, Transition)
  self._dissolve = tryShader(DISSOLVE_SRC)
  self._pixelate = tryShader(PIXELATE_SRC)
  self._blood = tryShader(BLOOD_DISSOLVE_SRC)
  self._bloodNightmare = tryShader(BLOOD_NIGHTMARE_SRC)
  return self
end

function Transition:ensure(w, h)
  if self.from and self.cw == w and self.ch == h then return end
  if not (love and love.graphics) then return end
  self.from = love.graphics.newCanvas(w, h); self.from:setFilter("nearest", "nearest")
  self.to   = love.graphics.newCanvas(w, h); self.to:setFilter("nearest", "nearest")
  self.blood = love.graphics.newCanvas(w, h); self.blood:setFilter("nearest", "nearest")
  self.bloodComposite = love.graphics.newCanvas(w, h); self.bloodComposite:setFilter("nearest", "nearest")
  self.cw, self.ch = w, h
end

-- snapshot la scène SORTANTE. drawCurrent() doit dessiner la frame (via Draw.begin(view)/scene:draw/Draw.finish).
function Transition:start(kind, dur, drawCurrent, opts)
  if not (love and love.graphics) then if drawCurrent then end return end
  local w, h = love.graphics.getDimensions()
  self:ensure(w, h)
  self.kind, self.dur, self.t, self.active = kind or "fade_black", dur or 0.3, 0, true
  self.opts = opts or {}
  if self.kind == "blood_rain" or self.kind == "blood_bloom" or self.kind == "blood_button" then
    self.liquid = self.liquid or Liquid.new()
    self.liquid:reset(self.kind, w, h, self.opts)
  else
    self.liquid = nil
  end
  love.graphics.setCanvas(self.from)
  love.graphics.clear(0, 0, 0, 0)
  if drawCurrent then drawCurrent() end
  love.graphics.setCanvas()
end

function Transition:update(dt)
  if not self.active then return end
  self.t = self.t + (dt or 0)
  if self.liquid and (self.kind == "blood_rain" or self.kind == "blood_bloom" or self.kind == "blood_button") then
    self.liquid:update(dt or 0, math.min(1, self.t / self.dur))
  end
  if self.t >= self.dur then self.active = false end
end

-- progress courbé (ease-in-out) pour des transitions plus douces
local function easeInOut(p) return p < 0.5 and 2 * p * p or 1 - (-2 * p + 2) ^ 2 / 2 end
local function clamp01(v) return math.max(0, math.min(1, v or 0)) end
local function smooth(a, b, x)
  local t = clamp01((x - a) / (b - a))
  return t * t * (3 - 2 * t)
end
local function easeOut(p) return 1 - (1 - p) * (1 - p) end

local BLOOD_DARK = { 0x1d / 255, 0x04 / 255, 0x07 / 255, 1 }
local BLOOD_MID = { 0x5c / 255, 0x10 / 255, 0x16 / 255, 1 }
local BLOOD_HOT = { 0xc8 / 255, 0x2e / 255, 0x26 / 255, 1 }
local BLOOD_BLACK = { 0x08 / 255, 0x01 / 255, 0x03 / 255, 1 }
local EYE_WHITE = { 0xe9 / 255, 0xdd / 255, 0xc2 / 255, 1 }
local EYE_GOLD = { 0xd8 / 255, 0xb6 / 255, 0x5e / 255, 1 }

local function seed01(i, salt)
  return (math.sin(i * 97.137 + salt * 13.731) * 43758.5453) % 1
end

local function col(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local function drawPixelEye(cx, cy, r, open, gazeX, gazeY)
  if open <= 0.03 then return end
  love.graphics.push()
  love.graphics.translate(math.floor(cx + 0.5), math.floor(cy + 0.5))
  love.graphics.scale(1, 0.62 + open * 0.26)
  col(BLOOD_BLACK, 0.78)
  love.graphics.ellipse("fill", 0, 1, r + 5, r * 0.78 + 4)
  col(EYE_WHITE, 0.96)
  love.graphics.ellipse("fill", 0, 0, r, r * 0.58)
  col(BLOOD_HOT, 0.44)
  love.graphics.setLineWidth(2)
  for i = 1, 4 do
    local a = i * 1.47 + r
    love.graphics.line(math.cos(a) * r * 0.92, math.sin(a) * r * 0.42,
      math.cos(a + 0.4) * r * 0.30, math.sin(a + 0.4) * r * 0.16)
  end
  local gx = (gazeX or 0) * r * 0.24
  local gy = (gazeY or 0) * r * 0.12
  col(EYE_GOLD, 0.98)
  love.graphics.circle("fill", gx, gy, math.max(2, r * 0.35))
  col(BLOOD_BLACK, 1)
  love.graphics.rectangle("fill", gx - math.max(1, r * 0.10), gy - r * 0.34, math.max(2, r * 0.20), r * 0.68)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

local function drawDrips(w, h, cover, t)
  local edgeBase = -24 + h * (cover * 1.05)
  col(BLOOD_DARK, 1)
  love.graphics.rectangle("fill", 0, -8, w, math.max(0, edgeBase + 18))
  local step = 24
  for x = -step, w + step, step do
    local i = math.floor((x + step) / step)
    local n = seed01(i, 2.4)
    local wave = 0.5 + 0.5 * math.sin(i * 1.91 + t * 2.2)
    local len = h * cover * (0.04 + 0.24 * n * wave)
    local width = 8 + math.floor(seed01(i, 7.1) * 18)
    local y = edgeBase + len
    col(i % 3 == 0 and BLOOD_MID or BLOOD_DARK, 0.96)
    love.graphics.rectangle("fill", x + (step - width) / 2, -4, width, math.max(0, y))
    if y > 8 then
      local bulb = 6 + seed01(i, 9.8) * 12
      love.graphics.rectangle("fill", x + step / 2 - bulb / 2, y - bulb * 0.25, bulb, bulb)
      if n > 0.60 then
        col(BLOOD_HOT, 0.22)
        love.graphics.rectangle("fill", x + step / 2 - 2, y - len * 0.38, 4, len * 0.32)
      end
    end
  end
  for i = 1, 12 do
    local x = seed01(i, 1.1) * w
    local y = math.min(h - 40, edgeBase * (0.52 + seed01(i, 3.3) * 0.42))
    if y > 58 and y < edgeBase + 90 then
      local r = 8 + seed01(i, 4.4) * 9
      drawPixelEye(x, y, r, smooth(0.10, 0.42, cover), seed01(i, 6.6) * 2 - 1, seed01(i, 7.7) * 2 - 1)
    end
  end
end

local function originOf(opts, w, h)
  opts = opts or {}
  if opts.originRectScreen then
    local r = opts.originRectScreen
    return (r.x or 0) + (r.w or 0) / 2, (r.y or 0) + (r.h or 0) / 2
  end
  if opts.originScreen then return opts.originScreen.x or w / 2, opts.originScreen.y or h * 0.78 end
  if opts.originNorm then return (opts.originNorm.x or 0.5) * w, (opts.originNorm.y or 0.78) * h end
  return w / 2, h * 0.78
end

local function drawBloom(w, h, cover, t, opts)
  local ox, oy = originOf(opts, w, h)
  local maxR = math.sqrt(w * w + h * h)
  local r = maxR * easeOut(cover) * 0.78 + 18
  col(BLOOD_DARK, 0.98)
  love.graphics.circle("fill", ox, oy, r)
  col(BLOOD_MID, 0.92)
  love.graphics.circle("fill", ox, oy, r * 0.72)

  for i = 1, 34 do
    local a = i / 34 * math.pi * 2 + math.sin(t * 0.9 + i) * 0.12
    local n = 0.45 + seed01(i, 5.2) * 0.70
    local len = r * n
    local ww = 8 + seed01(i, 8.8) * 32
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.rotate(a)
    col(i % 4 == 0 and BLOOD_HOT or BLOOD_DARK, i % 4 == 0 and 0.32 or 0.82)
    love.graphics.rectangle("fill", 0, -ww / 2, len, ww)
    love.graphics.pop()
  end

  local block = 18
  for i = 1, 62 do
    local a = seed01(i, 11.1) * math.pi * 2
    local rr = r * (0.20 + seed01(i, 12.2) * 0.88)
    local x = ox + math.cos(a) * rr
    local y = oy + math.sin(a) * rr
    local s = block * (0.45 + seed01(i, 13.3) * 1.4)
    col(i % 5 == 0 and BLOOD_HOT or BLOOD_DARK, i % 5 == 0 and 0.22 or 0.92)
    love.graphics.rectangle("fill", x - s / 2, y - s / 2, s, s)
  end

  for i = 1, 14 do
    local a = seed01(i, 18.1) * math.pi * 2
    local rr = r * (0.16 + seed01(i, 19.2) * 0.58)
    local x = ox + math.cos(a) * rr
    local y = oy + math.sin(a) * rr
    local er = 7 + seed01(i, 20.3) * 12
    if x > 20 and x < w - 20 and y > 20 and y < h - 20 then
      drawPixelEye(x, y, er, smooth(0.08, 0.34, cover), (ox - x) / maxR * 2.2, (oy - y) / maxR * 2.2)
    end
  end
end

local function drawBloodTexture(self, kind, w, h, p)
  if not self.blood then return end
  love.graphics.setCanvas(self.blood)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setBlendMode("alpha")
  if self.liquid then self.liquid:draw() end
  love.graphics.setCanvas()
end

local function drawBloodTransition(self, kind, w, h, p)
  local reveal = smooth(0.74, 1.00, p)
  local ox, oy = originOf(self.opts, w, h)
  drawBloodTexture(self, kind, w, h, p)

  love.graphics.setCanvas(self.bloodComposite)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setBlendMode("alpha")
  if p < 0.74 then
    love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.from, 0, 0)
  else
    love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.to, 0, 0)
  end
  if self._blood then
    self._blood:send("reveal", reveal)
    self._blood:send("time", self.t)
    self._blood:send("origin", { ox / math.max(1, w), oy / math.max(1, h) })
    self._blood:send("mode", (kind == "blood_bloom" or kind == "blood_button") and 1 or 0)
    love.graphics.setShader(self._blood)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.blood, 0, 0)
  love.graphics.setShader()
  love.graphics.setCanvas()

  local cover = smooth(0.00, 0.78, p)
  local nightmare = math.min(0.62, math.max(smooth(0.02, 0.35, p) * 0.46, cover * 0.56))
  nightmare = nightmare * (1 - smooth(0.96, 1.00, p))
  if self._bloodNightmare then
    self._bloodNightmare:send("time", self.t)
    self._bloodNightmare:send("strength", nightmare)
    self._bloodNightmare:send("origin", { ox / math.max(1, w), oy / math.max(1, h) })
    love.graphics.setShader(self._bloodNightmare)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.bloodComposite, 0, 0)
  love.graphics.setShader()
end

-- rend la scène ENTRANTE (live) + blende. Renvoie true si une transition est en cours (l'appelant n'a alors
-- PAS à dessiner la scène lui-même). drawNext() rend la frame entrante.
function Transition:draw(drawNext)
  if not self.active or not (love and love.graphics) then return false end
  local w, h = self.cw, self.ch
  local p = math.min(1, self.t / self.dur)
  local e = easeInOut(p)

  -- capture la scène entrante (live) dans `to`
  love.graphics.setCanvas(self.to)
  love.graphics.clear(0, 0, 0, 0)
  if drawNext then drawNext() end
  love.graphics.setCanvas()

  love.graphics.push()
  love.graphics.origin()
  love.graphics.setBlendMode("alpha", "premultiplied")   -- canvas = alpha prémultiplié

  local kind = self.kind
  if kind == "crossfade" then
    love.graphics.setColor(1, 1, 1, 1 - e); love.graphics.draw(self.from, 0, 0)
    love.graphics.setColor(1, 1, 1, e);     love.graphics.draw(self.to, 0, 0)

  elseif kind == "fade_black" then
    -- 1re moitié : sortante + voile noir qui monte ; 2e : entrante + voile qui descend (le swap est masqué)
    if p < 0.5 then
      love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.from, 0, 0)
    else
      love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.to, 0, 0)
    end
    love.graphics.setBlendMode("alpha")
    local veil = 1 - math.abs(p * 2 - 1)     -- 0 -> 1 (mi-course) -> 0
    love.graphics.setColor(0.02, 0.012, 0.03, veil)
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif kind:sub(1, 5) == "slide" then
    local dir = kind:sub(7)
    local dx, dy = 0, 0
    if dir == "left"  then dx = -w * e elseif dir == "right" then dx = w * e
    elseif dir == "up" then dy = -h * e elseif dir == "down"  then dy = h * e end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.from, dx, dy)
    love.graphics.draw(self.to, dx + (dir == "left" and w or dir == "right" and -w or 0),
                                dy + (dir == "up" and h or dir == "down" and -h or 0))

  elseif kind == "iris_in" then
    -- la sortante reste, un disque qui se ferme révèle l'entrante AU CENTRE (rétro)
    love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.to, 0, 0)
    love.graphics.setBlendMode("alpha")
    if love.graphics.stencil then
      local maxR = math.sqrt(w * w + h * h) / 2
      local r = maxR * (1 - e)
      love.graphics.stencil(function() love.graphics.circle("fill", w / 2, h / 2, r) end, "replace", 1)
      love.graphics.setStencilTest("greater", 0)
      love.graphics.setBlendMode("alpha", "premultiplied")
      love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.from, 0, 0)
      love.graphics.setStencilTest()
    end

  elseif (kind == "dissolve" or kind == "burn") and self._dissolve then
    love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(self.to, 0, 0)   -- entrante dessous
    self._dissolve:send("progress", e)
    self._dissolve:send("feather", kind == "burn" and 0.14 or 0.08)
    self._dissolve:send("edgeColor", kind == "burn" and { 0.88, 0.42, 0.16, 1.0 } or { 0.71, 0.18, 0.14, 0.8 })
    love.graphics.setShader(self._dissolve)
    love.graphics.draw(self.from, 0, 0)                                      -- sortante se dissout par-dessus
    love.graphics.setShader()

  elseif kind == "pixelate" and self._pixelate then
    -- se désintègre en gros pixels au milieu puis se recompose
    local amt = 1 + 28 * math.sin(e * math.pi)
    self._pixelate:send("res", { w, h })
    self._pixelate:send("amount", amt)
    love.graphics.setShader(self._pixelate)
    if p < 0.5 then love.graphics.draw(self.from, 0, 0) else love.graphics.draw(self.to, 0, 0) end
    love.graphics.setShader()

  elseif kind == "blood_rain" or kind == "blood_bloom" or kind == "blood_button" then
    love.graphics.setBlendMode("alpha")
    drawBloodTransition(self, kind, w, h, p)

  else  -- repli : crossfade
    love.graphics.setColor(1, 1, 1, 1 - e); love.graphics.draw(self.from, 0, 0)
    love.graphics.setColor(1, 1, 1, e);     love.graphics.draw(self.to, 0, 0)
  end

  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop()
  return true
end

-- catalogue (pour l'UI de la galerie)
Transition.KINDS = {
  "fade_black", "crossfade", "slide_left", "slide_right", "slide_up", "slide_down",
  "iris_in", "dissolve", "burn", "pixelate", "blood_rain", "blood_bloom", "blood_button",
}

return Transition
