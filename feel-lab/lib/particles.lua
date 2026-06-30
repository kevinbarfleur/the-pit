-- feel-lab/lib/particles.lua
-- Particules pixel travaillees pour The Pit. Chaque sprite est bake depuis une
-- grille palette Wraeclast: pas de cercle lisse, pas de texture placeholder.

local Sprite = require("lib.sprite")
local Palette = require("lib.palette")

local P = {}

local parts = {}
local rings = {}
local bolts = {}
local bubbles = {}
local streaks = {}
local PX = 4
local TEX = nil
local WHITE = { 1, 1, 1, 1 }

-- Ramps:
-- W/Q/q/o = ivoire -> braise -> sang sombre
-- T/Y/y   = or -> laiton sombre
-- S/s/A/a = os/cendre
-- w/V/v   = pourriture/arcane
-- J/k/u   = accents affliction
local G_EMBER = {
  { "..Q..", ".QWQ.", "QWWWQ", ".QWQ.", "..Q.." },
  { "..q..", ".qQq.", "qQqQq", ".qQq.", "..q.." },
  { ".....", "..q..", ".oqo.", "..q..", "....." },
  { ".....", ".....", "..o..", ".....", "....." },
}
local G_SHARD = {
  { "..T..", ".TY..", "TYs..", ".Ys..", "..s.." },
  { ".T...", "TTY..", ".Ys..", "..s..", "....." },
}
local G_ASH = {
  { ".AA.", "AaAa", ".aa.", "...." },
  { "....", ".Aa.", "aa..", ".a.." },
  { "....", "....", ".a..", "...." },
}
local G_SPARK = {
  { "W", "T", "Y", "y" },
  { "T", "Y", "y" },
}
local G_MOTE = {
  { "W" }, { "T" }, { "Q" },
}
local G_FLARE = {
  { "..W..", "..W..", "WWWWW", "..W..", "..W.." },
  { "..T..", ".TWT.", "TWWWY", ".TWT.", "..Y.." },
  { ".....", "..T..", ".TYT.", "..Y..", "....." },
}
local G_RUNE = {
  { "..T..", ".T.T.", "T...T", ".T.T.", "..T.." },
  { ".Y.Y.", "Y...Y", "..T..", "Y...Y", ".Y.Y." },
}
local G_VOID = {
  { "..w..", ".wVw.", "wVWVw", ".wVw.", "..w.." },
  { "..V..", ".vVv.", "VvVvV", ".vVv.", "..V.." },
  { ".....", "..v..", ".v.v.", "..v..", "....." },
}
local G_BLOOD = {
  { ".u.", "uWu", ".U." },
  { ".u.", "uUu", ".U." },
  { "...", ".U.", "..." },
}
local G_BUBBLE = {
  { ".jj.", "jWWj", "jWWj", ".jj." },
  { ".j.", "jWj", ".j." },
  { "j" },
}
local G_GAS = {
  { ".z.", "zjz", ".Z." },
  { "z.z", ".Z.", "..." },
  { "z" },
}
local G_CHIP = {
  { "STT", "sYS", ".s." },
  { ".ST", "sYS", "s.." },
}

local TYPES = {
  ember = { grids = G_EMBER, additive = true, snap = true },
  shard = { grids = G_SHARD, additive = false, snap = true, quarter = true },
  ash = { grids = G_ASH, additive = false, snap = true },
  spark = { grids = G_SPARK, additive = true, snap = true, velocity = true },
  mote = { grids = G_MOTE, additive = true, snap = true },
  flare = { grids = G_FLARE, additive = true, snap = true },
  rune = { grids = G_RUNE, additive = true, snap = true, quarter = true },
  void = { grids = G_VOID, additive = true, snap = true },
  blood = { grids = G_BLOOD, additive = true, snap = true },
  bubble = { grids = G_BUBBLE, additive = true, snap = true },
  gas = { grids = G_GAS, additive = true, snap = true },
  chip = { grids = G_CHIP, additive = false, snap = true, quarter = true },
}

local function bakeAll(grids)
  local frames = {}
  for i, grid in ipairs(grids) do frames[i] = Sprite.bake(grid, Palette) end
  return frames
end

function P.load()
  if TEX or not (love and love.graphics) then return end
  TEX = {}
  for id, spec in pairs(TYPES) do
    TEX[id] = {
      frames = bakeAll(spec.grids),
      additive = spec.additive,
      velocity = spec.velocity,
      quarter = spec.quarter,
      snap = spec.snap,
    }
  end
end

local function rnd(a, b)
  local r = (love and love.math and love.math.random or math.random)()
  if not a then return r end
  return a + (b - a) * r
end

local function choose(v)
  if type(v) == "table" then return v[1 + math.floor(rnd() * #v)] end
  return v
end

local function easeOut(e) return 1 - (1 - e) * (1 - e) end
local function easeIn(e) return e * e end
local function snap(v) return math.floor(v / PX + 0.5) * PX end
local function clamp01(v) return math.max(0, math.min(1, v or 0)) end
local TAU = math.pi * 2

local function targetVolume(x, y, opts)
  opts = opts or {}
  local t = opts.target or {}
  local rx = t.rx or (t.w and t.w / 2) or opts.rx or 34
  local ry = t.ry or (t.h and t.h / 2) or opts.ry or 44
  local cx = t.cx or (t.x and t.w and (t.x + t.w / 2)) or x
  local cy = t.cy or (t.y and t.h and (t.y + t.h / 2)) or y
  return {
    cx = cx, cy = cy, rx = rx, ry = ry,
    left = cx - rx, right = cx + rx,
    top = cy - ry, bottom = cy + ry,
  }
end

local function pointInVolume(v, sx, sy)
  sx, sy = sx or 0.8, sy or 0.6
  return v.cx + rnd(-v.rx * sx, v.rx * sx), v.cy + rnd(-v.ry * sy, v.ry * sy)
end

local function pointOnRim(v, ang, ox, oy)
  return v.cx + math.cos(ang) * v.rx * (ox or 1), v.cy + math.sin(ang) * v.ry * (oy or 1)
end

function P.burst(x, y, opts)
  opts = opts or {}
  local n = opts.count or 12
  local spA = type(opts.speed) == "table" and opts.speed[1] or (opts.speed or 90)
  local spB = type(opts.speed) == "table" and opts.speed[2] or ((opts.speed or 90) * 2.2)
  local lA = opts.life and opts.life[1] or 0.35
  local lB = opts.life and opts.life[2] or 0.7
  local dir, spread = opts.dir or 0, opts.spread or (math.pi * 2)
  local radius = opts.radius or 0
  local scale = opts.scale or 1
  for _ = 1, n do
    local ang = (spread >= math.pi * 2) and rnd(0, math.pi * 2) or (dir + rnd(-spread / 2, spread / 2))
    local sp, life = rnd(spA, spB), rnd(lA, lB)
    local sx = x + math.cos(ang) * rnd(0, radius)
    local sy = y + math.sin(ang) * rnd(0, radius)
    parts[#parts + 1] = {
      x = sx, y = sy, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
      t = life, maxt = life, type = choose(opts.type) or "shard",
      rot = opts.rot or rnd(0, math.pi * 2), spin = (opts.spin or 5) * rnd(-1, 1),
      grav = opts.gravity or 0, drag = opts.drag or 2.2, tint = opts.tint,
      scale = type(scale) == "table" and rnd(scale[1], scale[2]) or scale,
      shrink = opts.shrink ~= false, layer = opts.layer or "front",
    }
  end
end

function P.ring(x, y, opts)
  opts = opts or {}
  rings[#rings + 1] = {
    x = x, y = y, t = opts.life or 0.42, maxt = opts.life or 0.42,
    r0 = opts.r0 or 8, r1 = opts.r1 or 90, col = opts.color or Palette.T,
    style = opts.style or "shock", width = opts.width or 1,
    notches = opts.notches or 0, spokes = opts.spokes or 0,
    layer = opts.layer or "front",
  }
end

function P.orbitBolts(x, y, opts)
  opts = opts or {}
  local n = opts.count or 3
  local col = opts.color or Palette.J
  local vol = opts.target and targetVolume(x, y, opts)
  local cx, cy = vol and vol.cx or x, vol and vol.cy or y
  for i = 1, n do
    local life = rnd(opts.lifeA or 0.20, opts.lifeB or 0.42)
    local r = rnd(opts.rA or 24, opts.rB or 48)
    local rx = opts.rxA and rnd(opts.rxA, opts.rxB or opts.rxA) or (opts.rx or (vol and rnd(vol.rx * 0.88, vol.rx * 1.16)) or r)
    local ry = opts.ryA and rnd(opts.ryA, opts.ryB or opts.ryA) or (opts.ry or (vol and rnd(vol.ry * 0.70, vol.ry * 1.00)) or r)
    local a = (opts.angle or 0) + i / n * math.pi * 2 + rnd(-0.24, 0.24)
    bolts[#bolts + 1] = {
      x = cx, y = cy, t = life, maxt = life,
      r = r, rx = rx, ry = ry,
      a = a,
      len = rnd(opts.lenA or 0.42, opts.lenB or 0.78),
      spin = rnd(opts.spinA or -4.8, opts.spinB or 4.8),
      zig = rnd(0, math.pi * 2),
      col = col,
      width = opts.width or 2,
      branch = opts.branch ~= false,
      layer = opts.layer or (opts.wrap and (math.sin(a) < -0.10 and "back" or "front")) or "front",
    }
  end
end

function P.bubbles(x, y, opts)
  opts = opts or {}
  local n = opts.count or 8
  local col = opts.color or Palette.j
  local vol = opts.target and targetVolume(x, y, opts)
  for _ = 1, n do
    local life = rnd(opts.lifeA or 0.70, opts.lifeB or 1.30)
    local bx, by
    if vol then
      if opts.around then
        local side = rnd()
        if side < 0.36 then
          bx = vol.left + rnd(-4, 12)
          by = vol.cy + rnd(-vol.ry * 0.55, vol.ry * 0.62)
        elseif side < 0.72 then
          bx = vol.right + rnd(-12, 4)
          by = vol.cy + rnd(-vol.ry * 0.55, vol.ry * 0.62)
        elseif side < 0.90 then
          bx = vol.cx + rnd(-vol.rx * 0.76, vol.rx * 0.76)
          by = vol.top + rnd(-4, 10)
        else
          bx = vol.cx + rnd(-vol.rx * 0.70, vol.rx * 0.70)
          by = vol.bottom + rnd(-8, 4)
        end
      else
        bx = vol.cx + rnd(-vol.rx * 0.92, vol.rx * 0.92)
        by = vol.cy + rnd(-vol.ry * 0.42, vol.ry * 0.58)
      end
    else
      local ang = rnd(0, math.pi * 2)
      local rad = rnd(0, opts.radius or 18)
      bx = x + math.cos(ang) * rad
      by = y + math.sin(ang) * rad
    end
    bubbles[#bubbles + 1] = {
      x = bx, y = by,
      vx = rnd(-18, 18),
      vy = rnd(opts.vyA or -92, opts.vyB or -30),
      r = rnd(opts.rA or 5, opts.rB or 12),
      t = life, maxt = life,
      col = col,
      wob = rnd(0, math.pi * 2),
      squash = rnd(-0.22, 0.22),
      layer = opts.layer or (vol and (rnd() < (opts.frontBias or 0.58) and "front" or "back")) or "front",
    }
  end
end

function P.bloodSpray(x, y, opts)
  opts = opts or {}
  local n = opts.count or 12
  local dir = opts.dir or 0
  local spread = opts.spread or math.pi * 0.55
  for _ = 1, n do
    local ang = dir + rnd(-spread / 2, spread / 2)
    local sp = rnd(opts.speedA or 120, opts.speedB or 330)
    local life = rnd(opts.lifeA or 0.24, opts.lifeB or 0.70)
    local len = rnd(opts.lenA or 10, opts.lenB or 32)
    streaks[#streaks + 1] = {
      x = x + rnd(-3, 3), y = y + rnd(-3, 3),
      vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
      t = life, maxt = life, len = len, col = opts.color or Palette.u,
      width = opts.width or rnd(2, 4), grav = opts.gravity or 285,
      drag = opts.drag or 1.55, satellite = rnd() < 0.45,
      layer = opts.layer or "back",
    }
  end
end

function P.signature(cause, x, y, opts)
  opts = opts or {}
  local heavy = opts.heavy and true or false
  local dot = opts.dot and true or false
  local vol = targetVolume(x, y, opts)
  if cause == "bleed" then
    local woundX = vol.cx + vol.rx * rnd(0.32, 0.72)
    local woundY = vol.cy + rnd(-vol.ry * 0.38, vol.ry * 0.24)
    local dir = rnd(-0.34, 0.28)
    P.ring(woundX, woundY, { color = Palette.u, r0 = 4, r1 = heavy and 72 or 46, life = 0.26, style = "shock", spokes = 3, layer = "back" })
    P.bloodSpray(woundX, woundY, { count = heavy and 18 or 9, dir = dir, spread = math.pi * rnd(0.32, 0.54),
      speedA = heavy and 160 or 95, speedB = heavy and 390 or 250, layer = "back" })
    P.burst(woundX, woundY, { type = "blood", count = heavy and 12 or 7, dir = dir, spread = math.pi * rnd(0.42, 0.74),
      speed = { heavy and 120 or 70, heavy and 360 or 230 }, life = { 0.24, heavy and 0.72 or 0.52 },
      gravity = 280, drag = 1.65, radius = 5, scale = heavy and { 0.55, 0.95 } or { 0.6, 0.9 }, layer = "back" })
    P.burst(woundX - vol.rx * 0.20, woundY + vol.ry * 0.30, { type = "blood", count = heavy and 8 or 4, dir = math.pi / 2, spread = math.pi * 0.42,
      speed = { 35, 140 }, life = { 0.42, 0.90 }, gravity = 260, drag = 1.35, scale = { 0.75, 1.1 }, layer = "front" })
  elseif cause == "poison" then
    P.ring(vol.cx, vol.cy, { color = Palette.j, r0 = 8, r1 = dot and 46 or 78, life = dot and 0.34 or 0.46, style = "seal", notches = 5, layer = "back" })
    P.bubbles(vol.cx, vol.cy, { target = vol, around = true, frontBias = 0.72, color = Palette.j, count = dot and 11 or 20,
      rA = dot and 3 or 5, rB = dot and 7 or 11, lifeA = 0.76, lifeB = dot and 1.20 or 1.55,
      vyA = dot and -62 or -112, vyB = -24 })
    P.burst(vol.cx, vol.cy + vol.ry * 0.10, { type = "gas", count = dot and 7 or 14, speed = { 12, 70 },
      life = { 0.58, 1.16 }, gravity = -32, drag = 2.8, radius = dot and vol.rx * 0.55 or vol.rx * 0.90,
      tint = Palette.j, scale = { 0.8, 1.35 }, layer = "front" })
  elseif cause == "shock" then
    P.ring(vol.cx, vol.cy, { color = Palette.J, r0 = 16, r1 = heavy and 84 or 56, life = 0.24, style = "shock", spokes = heavy and 8 or 5, width = 2, layer = "back" })
    P.orbitBolts(vol.cx, vol.cy, { target = vol, color = Palette.J, count = heavy and 9 or 6,
      rxA = vol.rx * 0.82, rxB = vol.rx * 1.22, ryA = vol.ry * 0.66, ryB = vol.ry * 1.04,
      lifeA = heavy and 0.58 or 0.36, lifeB = heavy and 1.02 or 0.68, lenA = 0.36, lenB = 0.86, width = heavy and 3 or 2,
      spinA = -6.2, spinB = 6.2, wrap = true })
    for i = 1, heavy and 4 or 3 do
      local px, py = pointOnRim(vol, i / (heavy and 4 or 3) * TAU + rnd(-0.22, 0.22), 0.92, 0.78)
      P.burst(px, py, { type = "spark", count = heavy and 8 or 5, speed = { 90, heavy and 310 or 220 },
        life = { 0.16, 0.44 }, drag = 3.20, tint = Palette.J, scale = { 0.9, 1.35 }, layer = "front" })
    end
  elseif cause == "burn" then
    P.ring(vol.cx, vol.cy + vol.ry * 0.12, { color = Palette.k, r0 = 6, r1 = dot and 52 or 84, life = 0.34, style = "shock", spokes = 4, layer = "back" })
    P.burst(vol.cx, vol.cy + vol.ry * 0.32, { type = "ember", count = dot and 13 or 28, dir = -math.pi / 2, spread = math.pi * 0.82,
      speed = { 42, dot and 160 or 260 }, life = { 0.44, dot and 0.86 or 1.18 },
      gravity = -92, drag = 2.08, radius = vol.rx * 0.62, tint = Palette.k, scale = { 0.95, 1.55 }, layer = "front" })
    P.burst(vol.cx, vol.cy + vol.ry * 0.08, { type = "flare", count = dot and 4 or 8, dir = -math.pi / 2, spread = math.pi * 0.55,
      speed = { 80, dot and 180 or 300 }, life = { 0.14, 0.34 }, drag = 3.2, tint = Palette.Q, scale = { 0.9, 1.4 } })
  elseif cause == "rot" then
    P.ring(vol.cx, vol.cy, { color = Palette.w, r0 = 10, r1 = dot and 48 or 78, life = 0.52, style = "seal", notches = 7, layer = "back" })
    P.burst(vol.cx, vol.cy, { type = "void", count = dot and 10 or 22, speed = { 22, dot and 110 or 170 },
      life = { 0.50, dot and 1.00 or 1.34 }, gravity = 48, drag = 2.0, radius = dot and 10 or 22,
      tint = Palette.w, scale = { 0.9, 1.45 }, layer = "front" })
    for _ = 1, dot and 2 or 4 do
      local px, py = pointInVolume(vol, 0.75, 0.58)
      P.burst(px, py, { type = "ash", count = dot and 3 or 5, speed = { 12, 100 },
        life = { 0.70, 1.45 }, gravity = 92, drag = 1.65, radius = 8, scale = { 0.8, 1.25 }, layer = rnd() < 0.5 and "back" or "front" })
    end
  else
    local hitX = vol.cx - vol.rx * 0.62
    local hitY = vol.cy + rnd(-vol.ry * 0.24, vol.ry * 0.18)
    P.ring(hitX, hitY, { color = Palette.W, r0 = 5, r1 = heavy and 76 or 50, life = 0.28, style = "shock", spokes = heavy and 5 or 3, layer = "front" })
    P.burst(hitX, hitY, { type = "shard", count = heavy and 18 or 9, speed = { 80, heavy and 285 or 180 },
      life = { 0.20, heavy and 0.58 or 0.42 }, gravity = 90, drag = 2.25, scale = { 0.85, 1.2 } })
    P.burst(hitX + vol.rx * 0.22, hitY, { type = "spark", count = heavy and 10 or 5, speed = { 100, heavy and 300 or 200 },
      life = { 0.10, 0.26 }, drag = 3.3, tint = Palette.W, scale = { 0.8, 1.15 } })
  end
end

local PRESETS = {
  levelup = function(x, y)
    P.ring(x, y, { color = Palette.W, r0 = 42, r1 = 170, life = 0.58, style = "seal", notches = 12, spokes = 6 })
    P.ring(x, y, { color = Palette.T, r0 = 28, r1 = 132, life = 0.48, style = "seal", notches = 10 })
    P.ring(x, y, { color = Palette.Q, r0 = 18, r1 = 92, life = 0.34, style = "shock", spokes = 6 })
    P.burst(x, y, { type = "flare", count = 10, speed = { 110, 250 }, life = { 0.16, 0.34 }, drag = 3.2, scale = { 1.0, 1.5 } })
    P.burst(x, y, { type = "rune", count = 14, speed = { 65, 190 }, life = { 0.42, 0.80 }, drag = 2.25, spin = 10 })
    P.burst(x, y, { type = "chip", count = 22, speed = { 105, 285 }, life = { 0.54, 1.00 }, gravity = 220, drag = 1.60, spin = 14 })
    P.burst(x, y, { type = "ember", count = 22, dir = -math.pi / 2, spread = math.pi * 0.88, speed = { 42, 145 }, life = { 0.68, 1.20 }, gravity = -54, drag = 2.15 })
    P.burst(x, y, { type = "ash", count = 16, speed = { 24, 105 }, life = { 0.88, 1.48 }, gravity = 105, drag = 1.68 })
    P.burst(x, y, { type = "mote", count = 14, speed = { 70, 210 }, life = { 0.30, 0.60 }, drag = 2.65 })
  end,
  levelup_big = function(x, y)
    P.ring(x, y, { color = Palette.W, r0 = 58, r1 = 224, life = 0.70, style = "seal", notches = 16, spokes = 8, width = 2 })
    P.ring(x, y, { color = Palette.T, r0 = 38, r1 = 172, life = 0.58, style = "seal", notches = 14, spokes = 4 })
    P.ring(x, y, { color = Palette.Q, r0 = 24, r1 = 124, life = 0.42, style = "shock", spokes = 8, width = 2 })
    P.burst(x, y, { type = "flare", count = 16, speed = { 150, 330 }, life = { 0.18, 0.40 }, drag = 3.0, scale = { 1.15, 1.8 } })
    P.burst(x, y, { type = "rune", count = 22, speed = { 90, 255 }, life = { 0.50, 0.94 }, drag = 2.05, spin = 14, scale = { 0.95, 1.35 } })
    P.burst(x, y, { type = "chip", count = 36, speed = { 135, 360 }, life = { 0.62, 1.16 }, gravity = 245, drag = 1.45, spin = 18, scale = { 0.9, 1.25 } })
    P.burst(x, y, { type = "ember", count = 34, dir = -math.pi / 2, spread = math.pi * 1.00, speed = { 58, 190 }, life = { 0.74, 1.34 }, gravity = -62, drag = 2.00 })
    P.burst(x, y, { type = "ash", count = 24, speed = { 32, 130 }, life = { 0.96, 1.70 }, gravity = 115, drag = 1.55 })
    P.burst(x, y, { type = "mote", count = 24, speed = { 88, 270 }, life = { 0.34, 0.70 }, drag = 2.35 })
  end,
  levelup_echo = function(x, y)
    P.ring(x, y, { color = Palette.T, r0 = 62, r1 = 196, life = 0.54, style = "seal", notches = 13, spokes = 5 })
    P.ring(x, y, { color = Palette.Q, r0 = 34, r1 = 136, life = 0.38, style = "shock", spokes = 7 })
    P.burst(x, y, { type = "chip", count = 20, speed = { 105, 270 }, life = { 0.46, 0.88 }, gravity = 210, drag = 1.65, spin = 16 })
    P.burst(x, y, { type = "rune", count = 14, speed = { 72, 210 }, life = { 0.36, 0.72 }, drag = 2.15, spin = 12 })
    P.burst(x, y, { type = "mote", count = 16, speed = { 70, 230 }, life = { 0.26, 0.54 }, drag = 2.70 })
  end,
  levelup_peak = function(x, y)
    P.ring(x, y, { color = Palette.W, r0 = 74, r1 = 246, life = 0.74, style = "seal", notches = 18, spokes = 10, width = 2 })
    P.ring(x, y, { color = Palette.T, r0 = 52, r1 = 184, life = 0.50, style = "shock", spokes = 10 })
    P.burst(x, y, { type = "flare", count = 12, speed = { 175, 360 }, life = { 0.16, 0.34 }, drag = 3.2, scale = { 1.2, 2.0 } })
    P.burst(x, y, { type = "chip", count = 40, speed = { 150, 390 }, life = { 0.56, 1.08 }, gravity = 260, drag = 1.42, spin = 20 })
    P.burst(x, y, { type = "ember", count = 38, dir = -math.pi / 2, spread = math.pi * 1.12, speed = { 68, 215 }, life = { 0.68, 1.26 }, gravity = -72, drag = 1.95 })
    P.burst(x, y, { type = "void", count = 12, speed = { 42, 140 }, life = { 0.40, 0.78 }, drag = 2.15, spin = 8 })
  end,
  seal = function(x, y)
    P.ring(x, y, { color = Palette.w, r0 = 10, r1 = 86, life = 0.55, style = "seal", notches = 9 })
    P.burst(x, y, { type = "void", count = 20, speed = { 36, 130 }, life = { 0.42, 0.84 }, drag = 2.0, spin = 7 })
    P.burst(x, y, { type = "rune", count = 8, speed = { 60, 160 }, life = { 0.34, 0.62 }, drag = 2.2, spin = 10 })
    P.burst(x, y, { type = "ash", count = 12, speed = { 20, 90 }, life = { 0.6, 1.1 }, gravity = 70, drag = 1.6 })
  end,
  impact = function(x, y)
    P.ring(x, y, { color = Palette.u, r0 = 4, r1 = 112, life = 0.40, style = "shock", spokes = 7, width = 2 })
    P.ring(x, y, { color = Palette.Q, r0 = 18, r1 = 78, life = 0.28, style = "seal", notches = 6 })
    P.burst(x, y, { type = "blood", count = 20, speed = { 110, 270 }, life = { 0.24, 0.56 }, gravity = 170, drag = 1.95, scale = { 1.0, 1.55 } })
    P.burst(x, y, { type = "spark", count = 14, speed = { 125, 280 }, life = { 0.12, 0.28 }, drag = 3.3 })
    P.burst(x, y, { type = "flare", count = 4, speed = { 130, 260 }, life = { 0.12, 0.24 }, drag = 3.6, scale = { 0.9, 1.3 } })
    P.burst(x, y, { type = "chip", count = 12, speed = { 90, 220 }, life = { 0.36, 0.68 }, gravity = 220, drag = 1.60, spin = 14 })
  end,
  death = function(x, y)
    P.ring(x, y, { color = Palette.A, r0 = 12, r1 = 118, life = 0.68, style = "seal", notches = 7 })
    P.burst(x, y, { type = "ash", count = 42, speed = { 35, 170 }, life = { 0.70, 1.60 }, gravity = 140, drag = 1.3, radius = 10 })
    P.burst(x, y, { type = "void", count = 18, speed = { 40, 160 }, life = { 0.44, 0.95 }, drag = 1.8, spin = 8 })
    P.burst(x, y, { type = "ember", count = 10, dir = -math.pi / 2, spread = math.pi * 0.65, speed = { 25, 95 }, life = { 0.55, 1.0 }, gravity = -40, drag = 2.2 })
  end,
  unlock = function(x, y)
    P.ring(x, y, { color = Palette.T, r0 = 7, r1 = 74, life = 0.42, style = "seal", notches = 4 })
    P.burst(x, y, { type = "rune", count = 6, speed = { 50, 140 }, life = { 0.36, 0.60 }, drag = 2.1, spin = 8 })
    P.burst(x, y, { type = "chip", count = 12, speed = { 90, 220 }, life = { 0.38, 0.70 }, gravity = 180, drag = 1.6, spin = 14 })
    P.burst(x, y, { type = "mote", count = 16, speed = { 50, 180 }, life = { 0.24, 0.52 }, drag = 2.4 })
  end,
}

function P.explosion(kind, x, y, opts)
  opts = opts or {}
  local f = PRESETS[kind] or PRESETS.levelup
  f(x, y, opts)
end

function P.update(dt)
  if not dt or dt <= 0 then return end
  local w = 1
  for i = 1, #parts do
    local p = parts[i]
    p.t = p.t - dt
    if p.t > 0 then
      local f = math.exp(-p.drag * dt)
      p.vx = p.vx * f
      p.vy = p.vy * f + p.grav * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.rot = p.rot + p.spin * dt
      parts[w] = p
      w = w + 1
    end
  end
  for i = #parts, w, -1 do parts[i] = nil end
  w = 1
  for i = 1, #rings do
    local r = rings[i]
    r.t = r.t - dt
    if r.t > 0 then rings[w] = r; w = w + 1 end
  end
  for i = #rings, w, -1 do rings[i] = nil end
  w = 1
  for i = 1, #bolts do
    local b = bolts[i]
    b.t = b.t - dt
    if b.t > 0 then bolts[w] = b; w = w + 1 end
  end
  for i = #bolts, w, -1 do bolts[i] = nil end
  w = 1
  for i = 1, #bubbles do
    local b = bubbles[i]
    b.t = b.t - dt
    if b.t > 0 then
      local f = math.exp(-1.55 * dt)
      b.vx = b.vx * f
      b.vy = b.vy * f - 14 * dt
      b.x = b.x + b.vx * dt + math.sin((b.maxt - b.t) * 8 + b.wob) * dt * 8
      b.y = b.y + b.vy * dt
      bubbles[w] = b
      w = w + 1
    end
  end
  for i = #bubbles, w, -1 do bubbles[i] = nil end
  w = 1
  for i = 1, #streaks do
    local s = streaks[i]
    s.t = s.t - dt
    if s.t > 0 then
      local f = math.exp(-s.drag * dt)
      s.vx = s.vx * f
      s.vy = s.vy * f + s.grav * dt
      s.x = s.x + s.vx * dt
      s.y = s.y + s.vy * dt
      streaks[w] = s
      w = w + 1
    end
  end
  for i = #streaks, w, -1 do streaks[i] = nil end
end

local HALFPI = math.pi / 2

local function drawRing(r)
  local k = 1 - r.t / r.maxt
  local rad = r.r0 + (r.r1 - r.r0) * easeOut(k)
  local alpha = (1 - k)
  local n = math.max(12, math.floor(2 * math.pi * rad / (PX * 2)))
  local col = r.col or Palette.T
  love.graphics.setBlendMode("add")
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  for j = 0, n - 1 do
    local draw = true
    if r.style == "seal" then
      draw = ((j + math.floor(k * 8)) % 3) ~= 1 or k < 0.22
    else
      draw = k < 0.45 or (j + math.floor(k * 6)) % 2 == 0
    end
    if draw then
      local ang = j / n * math.pi * 2
      local size = r.style == "seal" and PX or PX * (r.width or 1)
      love.graphics.rectangle("fill", snap(r.x + math.cos(ang) * rad), snap(r.y + math.sin(ang) * rad), size, size)
    end
  end
  if r.notches and r.notches > 0 then
    for j = 0, r.notches - 1 do
      local ang = j / r.notches * math.pi * 2 + k * 0.7
      local nx, ny = snap(r.x + math.cos(ang) * rad), snap(r.y + math.sin(ang) * rad)
      love.graphics.rectangle("fill", nx - PX, ny, PX * 3, PX)
      love.graphics.rectangle("fill", nx, ny - PX, PX, PX * 3)
    end
  end
  if r.spokes and r.spokes > 0 then
    love.graphics.setColor(col[1], col[2], col[3], alpha * 0.42)
    love.graphics.setLineWidth(2)
    for j = 0, r.spokes - 1 do
      local ang = j / r.spokes * math.pi * 2 - k * 0.4
      love.graphics.line(snap(r.x + math.cos(ang) * rad * 0.32), snap(r.y + math.sin(ang) * rad * 0.32),
        snap(r.x + math.cos(ang) * rad * 0.82), snap(r.y + math.sin(ang) * rad * 0.82))
    end
    love.graphics.setLineWidth(1)
  end
  love.graphics.setBlendMode("alpha")
end

local function drawBolt(b)
  local k = 1 - b.t / b.maxt
  local alpha = (1 - k) * (k < 0.18 and k / 0.18 or 1)
  local col = b.col or Palette.J
  local a0 = b.a + b.spin * k
  local segs = 5
  local pts = {}
  love.graphics.setBlendMode("add")
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  love.graphics.setLineWidth(b.width or 2)
  local lastX, lastY
  for i = 0, segs do
    local t = i / segs
    local ang = a0 + (t - 0.5) * b.len
    local jitter = math.sin((i * 2.17 + b.zig + k * 9.0)) * PX * 1.15
    local rx = (b.rx or b.r) + jitter
    local ry = (b.ry or b.r) + jitter * 0.64
    local x = snap(b.x + math.cos(ang) * rx)
    local y = snap(b.y + math.sin(ang) * ry)
    pts[#pts + 1] = { x = x, y = y, a = ang, rx = rx, ry = ry }
    if lastX then love.graphics.line(lastX, lastY, x, y) end
    love.graphics.rectangle("fill", x - PX / 2, y - PX / 2, PX, PX)
    lastX, lastY = x, y
  end
  if b.branch then
    love.graphics.setLineWidth(math.max(1, (b.width or 2) - 1))
    for i = 2, #pts - 1 do
      local p = pts[i]
      if math.sin(b.zig + i * 3.31 + k * 12) > 0.08 then
        local side = math.sin(b.zig + i * 1.83) > 0 and 1 or -1
        local ba = p.a + side * (0.52 + 0.40 * (0.5 + 0.5 * math.sin(b.zig + i * 4.70)))
        local bl = (PX * 2.2 + PX * 3.4 * (0.5 + 0.5 * math.sin(b.zig + i * 5.90))) * (1 - k * 0.35)
        local bx = snap(p.x + math.cos(ba) * bl)
        local by = snap(p.y + math.sin(ba) * bl * 0.82)
        love.graphics.line(p.x, p.y, bx, by)
        love.graphics.rectangle("fill", bx - PX / 2, by - PX / 2, PX, PX)
      end
    end
  end
  love.graphics.setLineWidth(1)
  love.graphics.setBlendMode("alpha")
end

local function drawBubble(b)
  local k = 1 - b.t / b.maxt
  local alpha = math.min(1, b.t / b.maxt * 2.2) * (k < 0.10 and k / 0.10 or 1)
  local col = b.col or Palette.j
  local wob = math.sin(k * math.pi * 4 + b.wob) * (b.squash or 0.1)
  local rx = b.r * (1 + k * 0.25 + wob)
  local ry = b.r * (1 + k * 0.18 - wob * 0.45)
  local n = math.max(8, math.floor(2 * math.pi * math.max(rx, ry) / PX))
  love.graphics.setBlendMode("add")
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  for i = 0, n - 1 do
    if i % 3 ~= 1 or k < 0.55 then
      local a = i / n * math.pi * 2
      love.graphics.rectangle("fill", snap(b.x + math.cos(a) * rx), snap(b.y + math.sin(a) * ry), PX, PX)
    end
  end
  love.graphics.setColor(1, 1, 1, alpha * 0.48)
  love.graphics.rectangle("fill", snap(b.x - rx * 0.22), snap(b.y - ry * 0.35), PX, PX)
  love.graphics.setBlendMode("alpha")
end

local function drawStreak(s)
  local k = 1 - s.t / s.maxt
  local alpha = math.max(0, math.min(1, s.t / s.maxt * 2.4))
  local col = s.col or Palette.u
  local vx, vy = s.vx, s.vy
  local mag = math.max(1, math.sqrt(vx * vx + vy * vy))
  local nx, ny = vx / mag, vy / mag
  local len = s.len * (1 - k * 0.42)
  local x1, y1 = snap(s.x), snap(s.y)
  local x0, y0 = snap(s.x - nx * len), snap(s.y - ny * len)
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(col[1], col[2], col[3], 0.72 * alpha)
  love.graphics.setLineWidth(s.width or 3)
  love.graphics.line(x0, y0, x1, y1)
  love.graphics.rectangle("fill", x1 - PX / 2, y1 - PX / 2, PX, PX)
  if s.satellite then
    love.graphics.setColor(Palette.U[1], Palette.U[2], Palette.U[3], 0.62 * alpha)
    love.graphics.rectangle("fill", snap(x1 - ny * PX * 1.5), snap(y1 + nx * PX * 1.5), PX, PX)
  end
  love.graphics.setLineWidth(1)
end

local function wants(layer, item)
  return not layer or (item.layer or "front") == layer
end

function P.draw(layer)
  if not (love and love.graphics) then return end
  if TEX then
    for _, p in ipairs(parts) do
      if wants(layer, p) then
        local tx = TEX[p.type] or TEX.shard
        local frames = tx.frames
        local nf = #frames
        local lifeK = clamp01(1 - p.t / p.maxt)
        local fi = math.min(nf, 1 + math.floor(lifeK * nf))
        local spr = frames[fi]
        if spr then
          local sx, sy = tx.snap and snap(p.x) or p.x, tx.snap and snap(p.y) or p.y
          local rot = p.rot or 0
          if tx.velocity then
            rot = math.floor((math.atan2(p.vy, p.vx) + HALFPI) / HALFPI + 0.5) * HALFPI
          elseif tx.quarter then
            rot = math.floor((p.rot or 0) / HALFPI + 0.5) * HALFPI
          end
          local a = 1
          if tx.additive then a = math.max(0, math.min(1, p.t / p.maxt * 2.8)) end
          local sc = p.scale or 1
          if p.shrink then sc = sc * (1 - easeIn(lifeK) * 0.28) end
          if tx.additive then love.graphics.setBlendMode("add") end
          local col = p.tint or WHITE
          love.graphics.setColor(col[1], col[2], col[3], a)
          love.graphics.draw(spr.image, sx, sy, rot, PX * sc, PX * sc, spr.w / 2, spr.h / 2)
          if tx.additive then love.graphics.setBlendMode("alpha") end
        end
      end
    end
  end
  for _, r in ipairs(rings) do if wants(layer, r) then drawRing(r) end end
  for _, b in ipairs(bolts) do if wants(layer, b) then drawBolt(b) end end
  for _, s in ipairs(streaks) do if wants(layer, s) then drawStreak(s) end end
  for _, b in ipairs(bubbles) do if wants(layer, b) then drawBubble(b) end end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha")
end

function P.clear() parts = {}; rings = {}; bolts = {}; bubbles = {}; streaks = {} end
function P.count() return #parts + #rings + #bolts + #bubbles + #streaks end
function P.presets() return { "levelup", "levelup_big", "levelup_echo", "levelup_peak", "seal", "impact", "death", "unlock" } end

return P
