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
--
-- API :
--   Transition.new()
--   tr:start(kind, dur, drawCurrent)   -- snapshot la scène sortante (drawCurrent rend dans le canvas actif)
--   tr:update(dt)                       -- avance progress ; désactive à la fin
--   tr:draw(drawNext)                   -- rend la scène entrante (live) + blende ; true si une transition joue
--   tr.active

local Transition = {}
Transition.__index = Transition

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

local function tryShader(src)
  if not (love and love.graphics and love.graphics.newShader) then return nil end
  local ok, sh = pcall(love.graphics.newShader, src)
  return ok and sh or nil
end

function Transition.new()
  local self = setmetatable({ active = false, t = 0, dur = 0.3, kind = "fade_black" }, Transition)
  self._dissolve = tryShader(DISSOLVE_SRC)
  self._pixelate = tryShader(PIXELATE_SRC)
  return self
end

function Transition:ensure(w, h)
  if self.from and self.cw == w and self.ch == h then return end
  if not (love and love.graphics) then return end
  self.from = love.graphics.newCanvas(w, h); self.from:setFilter("nearest", "nearest")
  self.to   = love.graphics.newCanvas(w, h); self.to:setFilter("nearest", "nearest")
  self.cw, self.ch = w, h
end

-- snapshot la scène SORTANTE. drawCurrent() doit dessiner la frame (via Draw.begin(view)/scene:draw/Draw.finish).
function Transition:start(kind, dur, drawCurrent)
  if not (love and love.graphics) then if drawCurrent then end return end
  local w, h = love.graphics.getDimensions()
  self:ensure(w, h)
  self.kind, self.dur, self.t, self.active = kind or "fade_black", dur or 0.3, 0, true
  love.graphics.setCanvas(self.from)
  love.graphics.clear(0, 0, 0, 0)
  if drawCurrent then drawCurrent() end
  love.graphics.setCanvas()
end

function Transition:update(dt)
  if not self.active then return end
  self.t = self.t + (dt or 0)
  if self.t >= self.dur then self.active = false end
end

-- progress courbé (ease-in-out) pour des transitions plus douces
local function easeInOut(p) return p < 0.5 and 2 * p * p or 1 - (-2 * p + 2) ^ 2 / 2 end

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
  "iris_in", "dissolve", "burn", "pixelate",
}

return Transition
