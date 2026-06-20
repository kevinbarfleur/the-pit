-- src/fx/background.lua
-- Décor d'ambiance "The Pit" : on descend un puits, tout est souterrain.
-- Couche STATIQUE peinte une fois dans un Canvas (gradient + voûte + grain).
-- Couche DYNAMIQUE redessinée par frame (poussière + halo rouge pulsant).
-- Même philosophie que les biomes PixiJS : paintStatic une fois, paintDynamic par tick.

local Background = {}
Background.__index = Background

-- Pseudo-aléatoire déterministe (textures stables entre les lancements).
local function rand(seed) return ((seed * 9301 + 49297) % 233280) / 233280 end
local function lerp(a, b, t) return a + (b - a) * t end

function Background.new(palette, w, h)
  local self = setmetatable({ w = w, h = h, t = 0, dust = {} }, Background)

  local canvas = love.graphics.newCanvas(w, h)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)

  -- Gradient vertical (voûte sombre -> fond légèrement rougeâtre).
  for y = 0, h - 1 do
    local u = y / h
    love.graphics.setColor(lerp(0.024, 0.055, u), lerp(0.016, 0.030, u), lerp(0.039, 0.050, u), 1)
    love.graphics.rectangle("fill", 0, y, w, 1)
  end

  -- Halo de braise diffus dans la moitié haute.
  for i = 1, 40 do
    love.graphics.setColor(0.43, 0.16, 0.14, 0.04)
    love.graphics.rectangle("fill", math.floor(rand(i) * w), math.floor(rand(i + 100) * h * 0.5), 2, 2)
  end

  -- Stalactites au plafond.
  for i = 1, 18 do
    local x = math.floor(rand(i + 500) * (w - 2))
    local len = 4 + math.floor(rand(i + 600) * 8)
    for dy = 0, len - 1 do
      local tip = len - 1 - dy
      love.graphics.setColor(0.07, 0.05, 0.07, 1)
      love.graphics.rectangle("fill", x, dy, (tip >= 2) and 2 or 1, 1)
    end
  end

  -- Grain rocheux dispersé.
  for i = 1, 130 do
    love.graphics.setColor(0.10, 0.08, 0.10, 0.5)
    love.graphics.rectangle("fill", math.floor(rand(i + 900) * w), math.floor(rand(i + 1300) * h), 1, 1)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setCanvas()
  canvas:setFilter("nearest", "nearest")
  self.canvas = canvas

  for i = 1, 44 do
    self.dust[i] = {
      x = rand(i * 3) * w, y = rand(i * 7) * h,
      sp = 0.05 + rand(i * 11) * 0.12, ph = rand(i * 13) * math.pi * 2,
    }
  end
  return self
end

function Background:update(frameDt, t)
  self.t = t
  for _, d in ipairs(self.dust) do
    d.y = d.y + d.sp * frameDt
    if d.y > self.h then d.y = 0 end
  end
end

function Background:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0)

  -- Halo rouge pulsant au centre-bas : la gueule du puits.
  love.graphics.setColor(0.43, 0.16, 0.14, 0.06 + 0.03 * math.sin(self.t * 0.04))
  love.graphics.circle("fill", self.w * 0.5, self.h * 0.62, 60)

  -- Poussière en suspension.
  for _, d in ipairs(self.dust) do
    local a = 0.4 + 0.2 * math.sin(self.t * 0.02 + d.ph)
    local x = d.x + math.sin(self.t * 0.02 + d.ph) * 2
    love.graphics.setColor(0.42, 0.35, 0.38, a * 0.4)
    love.graphics.rectangle("fill", math.floor(x), math.floor(d.y), 1, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Background
