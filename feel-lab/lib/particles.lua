-- feel-lab/lib/particles.lua  (REFONTE PIXEL — matche la DA)
-- Particules en SPRITES PIXEL BAKÉS (au lieu de cercles/traits anti-aliasés = l'ancien « cheap »). Recettes
-- issues de la recherche VFX pixel-art : sprites nearest, **snap à la grille-monde** (×4), **fondu par RAMPE de
-- palette** (frames discrètes, pas alpha lisse), **rotation par paliers 90°**, glow ADDITIF sur cœurs seulement,
-- couleurs **palette Wraeclast** (ramps ember/bone/ash/gold). L'unité finale vient de la surcouche postfx
-- (dither Bayer + grain), appliquée sur toute la frame. RENDER pur, headless-safe.
--
-- API (compat) : P.load() [bake l'atlas, à appeler au boot] · P.burst(x,y,opts) · P.ring(x,y,opts) ·
--   P.update(dt) · P.draw() [SOUS Draw.begin(view)] · P.clear() · P.count()
--   burst opts = { type, count, speed{a,b}|n, spread, dir, life{a,b}, gravity, drag, spin, tint }
--   types : "ember" (braise montante, additif) · "shard" (éclat, opaque, rot 90°) · "ash" (cendre) ·
--           "spark" (étincelle orientée vélocité, additif) · "mote" (étincelle 1px, additif)

local Sprite  = require("lib.sprite")
local Palette  = require("lib.palette")

local P = {}
local parts = {}
local rings = {}
local PX = 4               -- taille d'un pixel-monde en unités DESIGN (le monde du jeu blite ×4)
local TEX = nil            -- atlas baké : TEX[type] = { frames = {sprite...}, additive = bool }
local WHITE = { 1, 1, 1, 1 }

-- ── Grilles ASCII des sprites (chars = clés de la palette Wraeclast ; '.' = transparent) ─────────────────
-- ember : cœur ivoire -> braise -> sang -> brun (rampe W/Q/q/o), additif, 4 frames de dissipation
local G_EMBER = {
  { ".Q.", "QWQ", ".Q." },
  { ".q.", "qQq", ".q." },
  { ".o.", "oqo", ".o." },
  { "...", ".o.", "..." },
}
-- shard : éclat doré/os (T gold, S os clair, Y/s ombres), opaque, tourné par paliers 90°
local G_SHARD = { { "TTs", ".Ys", ".s." } }
-- ash : cendre qui dérive (A clair -> a sombre), opaque, 2 frames
local G_ASH = { { "AA", "Aa" }, { "aa", ".a" } }
-- spark : étincelle-traînée verticale (T tête -> y ombre), additif, orientée vélocité
local G_SPARK = { { "T", "Y", "y" } }
-- mote : micro-étincelle dorée 1px, additif (cœur ivoire/or)
local G_MOTE = { { "W" }, { "T" } }

function P.load()
  if TEX or not (love and love.graphics) then return end
  local function bakeAll(grids)
    local f = {}
    for i, g in ipairs(grids) do f[i] = Sprite.bake(g, Palette) end
    return f
  end
  TEX = {
    ember = { frames = bakeAll(G_EMBER), additive = true },
    shard = { frames = bakeAll(G_SHARD), additive = false },
    ash   = { frames = bakeAll(G_ASH),   additive = false },
    spark = { frames = bakeAll(G_SPARK), additive = true },
    mote  = { frames = bakeAll(G_MOTE),  additive = true },
  }
end

local function rnd(a, b)
  local r = (love and love.math and love.math.random or math.random)()
  if not a then return r end
  return a + (b - a) * r
end
local function easeOut(e) return 1 - (1 - e) * (1 - e) end
local function snap(v) return math.floor(v / PX + 0.5) * PX end

-- ── Émission ────────────────────────────────────────────────────────────────────────────────────────────
function P.burst(x, y, opts)
  opts = opts or {}
  local n = opts.count or 12
  local spA = type(opts.speed) == "table" and opts.speed[1] or (opts.speed or 90)
  local spB = type(opts.speed) == "table" and opts.speed[2] or (opts.speed or 90) * 2.2
  local lA = opts.life and opts.life[1] or 0.35
  local lB = opts.life and opts.life[2] or 0.7
  local dir, spread = opts.dir or 0, opts.spread or (math.pi * 2)
  for _ = 1, n do
    local ang = (spread >= math.pi * 2) and rnd(0, math.pi * 2) or (dir + rnd(-spread / 2, spread / 2))
    local sp, life = rnd(spA, spB), rnd(lA, lB)
    parts[#parts + 1] = {
      x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
      t = life, maxt = life, type = opts.type or "shard",
      rot = rnd(0, math.pi * 2), spin = (opts.spin or 5) * rnd(-1, 1),
      grav = opts.gravity or 0, drag = opts.drag or 2.2, tint = opts.tint,
    }
  end
end

function P.ring(x, y, opts)
  opts = opts or {}
  rings[#rings + 1] = {
    x = x, y = y, t = opts.life or 0.42, maxt = opts.life or 0.42,
    r0 = opts.r0 or 8, r1 = opts.r1 or 90, col = opts.color or Palette.T,
  }
end

-- ── Physique (floats — la recherche confirme : garder ; seul le RENDU change) ────────────────────────────
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
      parts[w] = p; w = w + 1
    end
  end
  for i = #parts, w, -1 do parts[i] = nil end
  w = 1
  for i = 1, #rings do
    local r = rings[i]; r.t = r.t - dt
    if r.t > 0 then rings[w] = r; w = w + 1 end
  end
  for i = #rings, w, -1 do rings[i] = nil end
end

-- ── Rendu (sprites bakés, snap grille, rotation palier ; ring chunky dithéré) ───────────────────────────
local HALFPI = math.pi / 2
function P.draw()
  if not (love and love.graphics) then return end
  if TEX then
    for _, p in ipairs(parts) do
      local tx = TEX[p.type] or TEX.shard
      local nf = #tx.frames
      local fi = math.min(nf, 1 + math.floor((1 - p.t / p.maxt) * nf))
      local spr = tx.frames[fi]
      if spr then
        local sx, sy = snap(p.x), snap(p.y)
        local rot = 0
        if p.type == "spark" then
          rot = math.floor((math.atan2(p.vy, p.vx) + HALFPI) / HALFPI + 0.5) * HALFPI
        elseif p.type == "shard" then
          rot = math.floor(p.rot / HALFPI) * HALFPI
        end
        local a = 1
        if tx.additive and fi == nf then a = math.max(0, math.min(1, p.t / p.maxt * 3)) end
        if tx.additive then love.graphics.setBlendMode("add") end
        local col = p.tint or WHITE
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.draw(spr.image, sx, sy, rot, PX, PX, spr.w / 2, spr.h / 2)
        if tx.additive then love.graphics.setBlendMode("alpha") end
      end
    end
  end
  -- onde de choc : anneau de chunks 1-virtuel-px (snap), grossit par rayon, s'ÉBRÈCHE en dithérant à la fin
  for _, r in ipairs(rings) do
    local k = 1 - r.t / r.maxt
    local rad = r.r0 + (r.r1 - r.r0) * easeOut(k)
    local alpha = (1 - k)
    local N = math.max(10, math.floor(2 * math.pi * rad / (PX * 2)))
    love.graphics.setBlendMode("add")
    love.graphics.setColor(r.col[1], r.col[2], r.col[3], alpha)
    for j = 0, N - 1 do
      if k < 0.4 or (j + math.floor(k * 6)) % 2 == 0 then   -- plein au début, ébréché en fin (dither)
        local ang = j / N * math.pi * 2
        love.graphics.rectangle("fill", snap(r.x + math.cos(ang) * rad), snap(r.y + math.sin(ang) * rad), PX, PX)
      end
    end
    love.graphics.setBlendMode("alpha")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function P.clear() parts = {}; rings = {} end
function P.count() return #parts + #rings end

return P
