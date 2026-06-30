-- feel-lab/lib/liquid.lua
-- Pixel-liquid transition field. This is intentionally not a full Navier-Stokes
-- solver: for a screen wipe, a low-res mass/arrival field gives the useful part
-- of a liquid illusion while staying deterministic and art-directable.

local Liquid = {}
Liquid.__index = Liquid
local Forge = require("src.ui.forge")

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local sin, cos, sqrt, pi = math.sin, math.cos, math.sqrt, math.pi
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function clamp01(v) return max(0, min(1, v or 0)) end

local function smooth(a, b, x)
  if a == b then return x >= b and 1 or 0 end
  local t = clamp01((x - a) / (b - a))
  return t * t * (3 - 2 * t)
end

local function lerp(a, b, t) return a + (b - a) * t end

local function hash2(x, y, s)
  return (sin((x or 0) * 127.13 + (y or 0) * 311.71 + (s or 0) * 74.37) * 43758.5453) % 1
end

local function setColor(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local PAL = {
  black = { 0x07 / 255, 0x01 / 255, 0x03 / 255, 1 },
  deep  = { 0x18 / 255, 0x03 / 255, 0x07 / 255, 1 },
  dark  = { 0x2c / 255, 0x07 / 255, 0x0c / 255, 1 },
  mid   = { 0x5e / 255, 0x12 / 255, 0x18 / 255, 1 },
  red   = { 0x9c / 255, 0x25 / 255, 0x1d / 255, 1 },
  hot   = { 0xe0 / 255, 0x43 / 255, 0x2e / 255, 1 },
  bone  = { 0xe9 / 255, 0xdd / 255, 0xc2 / 255, 1 },
  gold  = { 0xe0 / 255, 0xbb / 255, 0x58 / 255, 1 },
}

function Liquid.new()
  return setmetatable({ fill = {}, age = {}, tmp = {}, eyes = {} }, Liquid)
end

function Liquid:index(x, y)
  return (y - 1) * self.cols + x
end

function Liquid:reset(kind, w, h, opts)
  self.kind, self.w, self.h = kind or "blood_rain", w or 1280, h or 720
  -- 6-8 px cells at common lab sizes: readable as pixel art without becoming
  -- chunky placeholder squares.
  self.cell = max(5, floor(min(self.w / 190, self.h / 106) + 0.5))
  self.cols, self.rows = ceil(self.w / self.cell), ceil(self.h / self.cell)
  local n = self.cols * self.rows
  for i = 1, n do self.fill[i], self.age[i], self.tmp[i] = 0, 0, 0 end
  for i = n + 1, #self.fill do self.fill[i], self.age[i], self.tmp[i] = nil, nil, nil end

  opts = opts or {}
  local ox = self.w * 0.50
  local oy = self.h * 0.76
  if opts.originRectScreen then
    local r = opts.originRectScreen
    ox = (r.x or 0) + (r.w or 0) / 2
    oy = (r.y or 0) + (r.h or 0) / 2
    self.buttonRect = {
      x1 = (r.x or 0) / self.cell,
      y1 = (r.y or 0) / self.cell,
      x2 = ((r.x or 0) + (r.w or 0)) / self.cell,
      y2 = ((r.y or 0) + (r.h or 0)) / self.cell,
      w = (r.w or 0) / self.cell,
      h = (r.h or 0) / self.cell,
    }
  elseif opts.originScreen then
    ox = opts.originScreen.x or ox
    oy = opts.originScreen.y or oy
  elseif opts.originNorm then
    ox = (opts.originNorm.x or 0.5) * self.w
    oy = (opts.originNorm.y or 0.76) * self.h
  end
  self.ox = clamp01(ox / max(1, self.w)) * self.cols
  self.oy = clamp01(oy / max(1, self.h)) * self.rows
  if not self.buttonRect then
    local bw, bh = max(18, self.cols * 0.16), max(6, self.rows * 0.05)
    self.buttonRect = { x1 = self.ox - bw / 2, y1 = self.oy - bh / 2, x2 = self.ox + bw / 2, y2 = self.oy + bh / 2, w = bw, h = bh }
  end
  self.eyePx = max(2, floor((self.w / 1280) * (Forge.PX or 2) + 0.5))
  self.time = 0
  self.cover = 0
  self:_seedEyes()
end

function Liquid:_seedEyes()
  self.eyes = {}
  local count = self.kind == "blood_button" and 22 or (self.kind == "blood_bloom" and 16 or 12)
  local maxR = sqrt(self.cols * self.cols + self.rows * self.rows)
  for i = 1, count do
    local x, y
    local x0, y0
    if self.kind == "blood_button" then
      local br = self.buttonRect
      local col = (i - 1) % 5
      local row = floor((i - 1) / 5) % 2
      x0 = lerp(br.x1 + br.w * 0.16, br.x2 - br.w * 0.16, col / 4) + (hash2(i, 3, 0.1) - 0.5) * br.w * 0.10
      y0 = lerp(br.y1 + br.h * 0.34, br.y2 - br.h * 0.26, row) + (hash2(i, 5, 0.2) - 0.5) * br.h * 0.22
      local a = i * 2.39996 + hash2(i, 4, 0.2) * 0.74
      local r = maxR * (0.12 + hash2(i, 9, 0.7) ^ 0.66 * 0.86)
      x = self.ox + cos(a) * r * (0.82 + hash2(i, 21, 0.3) * 0.22)
      y = self.oy + sin(a) * r * 0.70 + max(0, sin(a)) * r * 0.26
    elseif self.kind == "blood_bloom" then
      local a = i * 2.39996 + hash2(i, 4, 0.2) * 0.8
      local r = maxR * (0.10 + hash2(i, 9, 0.7) ^ 0.72 * 0.82)
      x = self.ox + cos(a) * r * 0.92
      y = self.oy + sin(a) * r * 0.74 + max(0, sin(a)) * r * 0.15
      x0, y0 = x, y
    else
      x = 12 + hash2(i, 2, 0.1) * (self.cols - 24)
      y = 12 + hash2(i, 7, 0.9) * (self.rows - 24)
      x0, y0 = x, y
    end
    local margin = 12
    self.eyes[i] = {
      x = max(margin, min(self.cols - margin, x)),
      y = max(margin, min(self.rows - margin, y)),
      x0 = max(margin, min(self.cols - margin, x0 or x)),
      y0 = max(margin, min(self.rows - margin, y0 or y)),
      r = 2.0 + hash2(i, 11, 0.3) * 1.8,
      phase = hash2(i, 13, 0.4) * pi * 2,
      gx = hash2(i, 17, 0.8) * 2 - 1,
      gy = hash2(i, 19, 0.6) * 2 - 1,
      seed = 300 + i * 41 + floor(hash2(i, 23, 0.5) * 997),
      source = self.kind == "blood_button" and i <= 5,
    }
  end
end

function Liquid:_raiseCell(x, y, target, dt)
  if x < 1 or x > self.cols or y < 1 or y > self.rows then return end
  local i = self:index(x, y)
  local f = self.fill[i] or 0
  if target > f then
    local rate = 1 - (0.0008 ^ (dt or 0.016))
    self.fill[i] = min(1, f + (target - f) * rate)
  end
end

function Liquid:_depositRain(cover, dt)
  local rows, cols = self.rows, self.cols
  local base = rows * (cover * 1.10 - 0.05)
  local dripPower = smooth(0.04, 0.70, cover)
  for x = 1, cols do
    local n = hash2(x, 5, 0.1)
    local slow = 0.5 + 0.5 * sin(self.time * (1.4 + n * 1.2) + x * 0.31)
    local longDrip = rows * (0.03 + n * 0.25) * dripPower * (0.45 + slow * 0.55)
    local front = base + longDrip
    local bleed = floor(hash2(x, 8, 0.7) * 2)
    for yy = 1, min(rows, floor(front + 3)) do
      local edge = front - yy
      local target = smooth(-1.5, 2.5, edge)
      target = target * (0.92 + hash2(x, yy, 0.3) * 0.08)
      for bx = -bleed, bleed do
        self:_raiseCell(x + bx, yy, target * (1 - math.abs(bx) * 0.18), dt)
      end
    end
  end
end

function Liquid:_depositBloom(cover, dt)
  local rows, cols = self.rows, self.cols
  local ox, oy = self.ox, self.oy
  local maxD = 0
  local corners = { { 1, 1 }, { cols, 1 }, { 1, rows }, { cols, rows } }
  for _, c in ipairs(corners) do
    maxD = max(maxD, sqrt((c[1] - ox) ^ 2 + (c[2] - oy) ^ 2))
  end
  local radius = maxD * (cover ^ 1.35) * 1.18 + 2
  local pulse = sin(self.time * 3.1) * 0.9
  for y = 1, rows do
    for x = 1, cols do
      local dx, dy = x - ox, y - oy
      local d = sqrt(dx * dx + dy * dy)
      local a = atan2(dy, dx)
      local blockNoise = (hash2(floor(x / 3), floor(y / 3), 4.1) - 0.5) * 9.0
      local vein = max(0, sin(a * 9.0 + hash2(floor(d), 2, 3.0) * 4.0 + self.time * 0.7)) ^ 7
      local gravityBias = max(0, dy) * 0.18 * smooth(0.14, 0.85, cover)
      local threshold = radius + blockNoise + vein * 11.0 + gravityBias + pulse
      local target = smooth(-3.2, 4.0, threshold - d)
      if d < 5 then target = 1 end
      if target > 0.01 then self:_raiseCell(x, y, target, dt) end
    end
  end
end

function Liquid:_depositButton(cover, dt)
  local rows, cols = self.rows, self.cols
  local br = self.buttonRect
  local ox, oy = self.ox, self.oy
  local maxD = 0
  local corners = { { 1, 1 }, { cols, 1 }, { 1, rows }, { cols, rows } }
  for _, c in ipairs(corners) do
    maxD = max(maxD, sqrt((c[1] - ox) ^ 2 + (c[2] - oy) ^ 2))
  end

  local seedFill = smooth(0.00, 0.22, cover)
  local spread = smooth(0.22, 0.98, cover)
  local radius = maxD * (spread ^ 1.72) * 1.03
  local soften = 2.6 + 4.8 * spread
  for y = 1, rows do
    for x = 1, cols do
      local insideX = x >= br.x1 and x <= br.x2
      local insideY = y >= br.y1 and y <= br.y2
      local rectInside = insideX and insideY
      local dx = max(br.x1 - x, 0, x - br.x2)
      local dy = max(br.y1 - y, 0, y - br.y2)
      local rectDist = sqrt(dx * dx + dy * dy)
      local cx = max(br.x1, min(br.x2, x))
      local cy = max(br.y1, min(br.y2, y))
      local a = atan2(y - oy, x - ox)
      local block = (hash2(floor(x / 2), floor(y / 2), 6.5) - 0.5) * (4.5 + 8.5 * spread)
      local lobe = max(0, sin(a * 7.0 + hash2(floor(rectDist * 2), 4, 1.2) * 4.0 + self.time * 0.52)) ^ 5
      local gravityBias = max(0, y - oy) * 0.10 * spread
      local sideBias = abs(x - ox) * 0.012 * spread
      local threshold = radius + block + lobe * 8.0 + gravityBias + sideBias
      local target = smooth(-soften, soften, threshold - rectDist)
      local puddleX = max(1, br.w * (0.70 + spread * 4.30))
      local puddleY = max(1, br.h * (1.00 + spread * 6.20))
      local puddleD = sqrt(((x - ox) / puddleX) ^ 2 + ((y - oy) / puddleY) ^ 2)
      local puddleNoise = (hash2(floor(x / 3), floor(y / 3), 12.4) - 0.5) * (0.16 + spread * 0.16)
      local sourcePuddle = smooth(-0.18, 0.20, 1.0 - puddleD + puddleNoise) * smooth(0.18, 0.62, cover)
      target = max(target, sourcePuddle)
      local inButtonTarget = rectInside and seedFill * (0.82 + hash2(x, y, 1.9) * 0.16) or 0
      if rectInside and cover < 0.28 then
        -- le label se fait avaler par plaques internes, pas par un masque uniforme.
        local labelBand = smooth(br.y1 + br.h * 0.24, br.y1 + br.h * 0.62, y)
          * (1 - smooth(br.y1 + br.h * 0.68, br.y2, y))
        local labelBite = smooth(0.05, 0.26, cover) * labelBand * (0.55 + hash2(x, y, 8.2) * 0.45)
        inButtonTarget = max(inButtonTarget, labelBite)
      end
      target = max(target, inButtonTarget)
      if rectInside and cover < 0.18 then
        -- Le tout premier signal garde la dalle rectangulaire du CTA.
        target = max(target, smooth(0.00, 0.12, cover) * 0.52)
      end
      if target > 0.01 then self:_raiseCell(x, y, min(1, target), dt) end
      if rectInside and cover > 0.18 and hash2(floor(cx), floor(cy), 4.7) > 0.965 then
        self:_raiseCell(x, y, min(1, target + 0.18), dt)
      end
    end
  end
end

function Liquid:_flow(dt)
  local cols, rows = self.cols, self.rows
  local flowMul = 1
  if self.kind == "blood_button" then
    flowMul = 0.01 + 0.99 * smooth(0.34, 0.92, self.cover or 0)
  end
  local speed = min(1, (dt or 0.016) * 58) * flowMul
  for i = 1, cols * rows do self.tmp[i] = self.fill[i] or 0 end

  for y = rows - 1, 1, -1 do
    for x = 1, cols do
      local i = self:index(x, y)
      local f = self.fill[i] or 0
      if f > 0.12 then
        local di = self:index(x, y + 1)
        local below = self.fill[di] or 0
        local down = min(f * 0.18 * speed, max(0, 1 - below) * 0.45)
        if down > 0.001 then
          self.tmp[i] = max(0, self.tmp[i] - down)
          self.tmp[di] = min(1, self.tmp[di] + down)
        end
        if below > 0.72 or self.kind == "blood_bloom" or (self.kind == "blood_button" and (self.cover or 0) > 0.48) then
          for _, side in ipairs({ -1, 1 }) do
            local sx = x + side
            if sx >= 1 and sx <= cols then
              local si = self:index(sx, y)
              local sf = self.fill[si] or 0
              local lateral = min(f * 0.045 * speed, max(0, f - sf) * 0.20)
              if lateral > 0.001 then
                self.tmp[i] = max(0, self.tmp[i] - lateral)
                self.tmp[si] = min(1, self.tmp[si] + lateral)
              end
            end
          end
        end
      end
    end
  end

  for i = 1, cols * rows do
    local f = min(1, max(0, self.tmp[i] or 0))
    self.fill[i] = f
    if f > 0.12 then self.age[i] = min(1, (self.age[i] or 0) + dt * 4.8) end
  end
end

function Liquid:update(dt, progress)
  dt = dt or 0
  self.time = self.time + dt
  local raw = progress or 0
  local cover = self.kind == "blood_button" and smooth(0.00, 0.92, raw) or smooth(0.00, 0.78, raw)
  self.cover = cover
  if cover <= 0 then return end
  if self.kind == "blood_button" then self:_depositButton(cover, dt)
  elseif self.kind == "blood_bloom" then self:_depositBloom(cover, dt)
  else self:_depositRain(cover, dt) end
  self:_flow(dt)
end

function Liquid:sample(gx, gy)
  local x = max(1, min(self.cols, floor(gx + 0.5)))
  local y = max(1, min(self.rows, floor(gy + 0.5)))
  return self.fill[self:index(x, y)] or 0, self.age[self:index(x, y)] or 0
end

function Liquid:_isEdge(x, y, f)
  if f < 0.95 then return true end
  local i
  i = x > 1 and self:index(x - 1, y); if i and (self.fill[i] or 0) < 0.45 then return true end
  i = x < self.cols and self:index(x + 1, y); if i and (self.fill[i] or 0) < 0.45 then return true end
  i = y > 1 and self:index(x, y - 1); if i and (self.fill[i] or 0) < 0.45 then return true end
  i = y < self.rows and self:index(x, y + 1); if i and (self.fill[i] or 0) < 0.45 then return true end
  return false
end

function Liquid:_drawCells()
  local px = self.cell
  for y = 1, self.rows do
    local y0 = (y - 1) * px
    for x = 1, self.cols do
      local i = self:index(x, y)
      local f = self.fill[i] or 0
      if f > 0.035 then
        local n = hash2(x, y, 9.6)
        local edge = self:_isEdge(x, y, f)
        local a = smooth(0.02, 0.34, f)
        local red = lerp(PAL.deep[1], PAL.mid[1], f)
        local green = lerp(PAL.deep[2], PAL.mid[2], f)
        local blue = lerp(PAL.deep[3], PAL.mid[3], f)
        if edge then
          red = lerp(red, PAL.hot[1], 0.26 + n * 0.18)
          green = lerp(green, PAL.hot[2], 0.16 + n * 0.10)
          blue = lerp(blue, PAL.hot[3], 0.10)
        elseif n < 0.045 then
          red, green, blue = red * 0.62, green * 0.55, blue * 0.58
        end

        love.graphics.setColor(red, green, blue, a)
        local x0 = (x - 1) * px
        love.graphics.rectangle("fill", x0, y0, px + 0.5, px + 0.5)

        if edge and n > 0.58 then
          setColor(PAL.hot, 0.20 + n * 0.16)
          love.graphics.rectangle("fill", x0, y0, px, max(1, floor(px * 0.28)))
        elseif f > 0.86 and n > 0.975 then
          setColor(PAL.black, 0.22)
          love.graphics.rectangle("fill", x0 + floor(px * 0.38), y0, max(1, floor(px * 0.26)), px)
        end
      end
    end
  end
end

function Liquid:_drawEyes()
  for _, e in ipairs(self.eyes) do
    local spread = self.kind == "blood_button" and smooth(0.10, 0.62, self.cover or 0) or 1
    local ex = lerp(e.x0 or e.x, e.x, spread)
    local ey = lerp(e.y0 or e.y, e.y, spread)
    local f, age = self:sample(ex, ey)
    local visible = self.kind ~= "blood_button" or e.source or spread > 0.26
    if visible and f > 0.34 then
      local wake = smooth(0.00, 0.18, age + f * 0.12)
      local blinkCycle = (self.time * (0.62 + hash2(e.seed, 3, 0.2) * 0.36) + e.phase) % 3.25
      local blink = smooth(2.90, 3.02, blinkCycle) * (1 - smooth(3.02, 3.18, blinkCycle))
      local open = clamp01(wake * (1 - blink * 0.88))
      if open > 0.025 then
        local scale = self.eyePx or 2
        local artR = max(4, min(9, floor(e.r * self.cell / scale * 0.62 + 0.5)))
        local aw = artR * 5 + 12
        local ah = artR * 4 + 10
        if not e.widget or e.aw ~= aw or e.ah ~= ah then
          e.widget = Forge.newWidget(aw, ah)
          e.aw, e.ah = aw, ah
        end
        local cx, cy = floor(aw / 2), floor(ah / 2)
        local lookPhase = floor((self.time * (1.15 + hash2(e.seed, 7, 0.4) * 0.55) + e.phase) % 4)
        local dx = (lookPhase == 0 and -1) or (lookPhase == 1 and 1) or (hash2(e.seed, 8, 0.1) * 2 - 1)
        local dy = (lookPhase == 2 and -0.55) or (lookPhase == 3 and 0.40) or (hash2(e.seed, 9, 0.3) * 0.6 - 0.3)
        local gaze = { cx + dx * artR * 3.0, cy + dy * artR * 1.8 }
        local image = Forge.render(e.widget, function(buf, W, H, tt)
          Forge.drawEye(buf, cx, cy, artR, open, 0.55 + 0.35 * wake, tt, e.seed,
            { squash = 0.70 + hash2(e.seed, 10, 0.7) * 0.12, pupil = "slit", blood = 0.78, gaze = gaze })
        end, self.time + e.phase * 0.08)
        local px = ex * self.cell
        local py = ey * self.cell
        Forge.blitEye(image, px - aw * scale / 2, py - ah * scale / 2, scale, {
          t = self.time + e.phase * 0.08,
          open = open,
          react = wake * 0.25,
          nightmare = 0.54,
        })
      end
    end
  end
end

function Liquid:draw()
  if not (love and love.graphics) then return end
  self:_drawCells()
  self:_drawEyes()
end

return Liquid
