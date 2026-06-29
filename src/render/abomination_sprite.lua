-- src/render/abomination_sprite.lua
-- Rendu combat des boss PvE. Port leger, en primitives LÖVE, des directions
-- visuelles de docs/generation/generateur-abominations.html. RENDER pur.

local Theme = require("src.ui.theme")

local AbominationSprite = {}

local H = Theme.hex
local C = Theme.c

local PALETTES = {
  leviathan = { body = H(0x77466f), dark = H(0x2c1729), light = H(0xc68abd), eye = H(0xffe0f6) },
  regard    = { body = H(0x33151a), dark = H(0x11070a), light = H(0xff4a4a), eye = H(0xffe060) },
  ossuaire  = { body = H(0x9e9a84), dark = H(0x2d2a24), light = H(0xf0e8cc), eye = H(0xd84038) },
  kraken    = { body = H(0x276d79), dark = H(0x0b2730), light = H(0x5af0e0), eye = H(0xffe08a) },
  idole     = { body = H(0x7b6730), dark = H(0x251e12), light = H(0xfff0a0), eye = H(0xffd55d) },
  ruche     = { body = H(0x4f7430), dark = H(0x17230d), light = H(0x9aff3a), eye = H(0xffd66b) },
  brasier   = { body = H(0x6b2414), dark = H(0x170706), light = H(0xff6a1a), eye = H(0xffe08a) },
  floraison = { body = H(0x3d695f), dark = H(0x10251f), light = H(0x5affc8), eye = H(0xd8fff4) },
  devoreur  = { body = H(0x482059), dark = H(0x16081d), light = H(0xc04aff), eye = H(0xffd0ff) },
  vermine   = { body = H(0x6e3544), dark = H(0x1e0b10), light = H(0xff5a7a), eye = H(0xffd47a) },
}

local function palette(key)
  return PALETTES[key] or { body = C.blood, dark = C.stone900, light = C.brassS, eye = C.ink }
end

local function set(col, alpha)
  love.graphics.setColor(col[1], col[2], col[3], alpha or col[4] or 1)
end

local function lineColor(col, alpha, width)
  set(col, alpha)
  love.graphics.setLineWidth(width or 1)
end

local function eye(cx, cy, rx, ry, pal, alpha)
  set(pal.light, (alpha or 1) * 0.45)
  love.graphics.ellipse("fill", cx, cy, rx + 1, ry + 1)
  set(pal.eye, alpha)
  love.graphics.ellipse("fill", cx, cy, rx, ry)
  set(pal.dark, alpha)
  love.graphics.circle("fill", cx, cy, math.max(1, math.min(rx, ry) * 0.45))
end

local function tendril(cx, cy, dx, dy, pal, alpha)
  lineColor(pal.dark, (alpha or 1) * 0.9, 3)
  love.graphics.line(cx, cy, cx + dx * 0.45, cy + dy * 0.25, cx + dx, cy + dy)
  lineColor(pal.light, (alpha or 1) * 0.45, 1)
  love.graphics.line(cx, cy - 1, cx + dx * 0.45, cy + dy * 0.25 - 1, cx + dx, cy + dy - 1)
end

local function tooth(cx, cy, w, h, alpha)
  love.graphics.setColor(0.90, 0.84, 0.66, alpha or 1)
  love.graphics.polygon("fill", cx - w / 2, cy, cx + w / 2, cy, cx, cy + h)
end

local function drawHalo(cx, cy, r, pal, alpha)
  lineColor(pal.light, (alpha or 1) * 0.18, 4)
  love.graphics.circle("line", cx, cy, r)
  lineColor(pal.light, (alpha or 1) * 0.12, 2)
  love.graphics.circle("line", cx, cy, r + 6)
end

local function drawLeviathan(cx, footY, s, pal, alpha, t)
  local cy = footY - 31 * s
  drawHalo(cx, cy, 20 * s, pal, alpha)
  for i = -2, 2 do
    tendril(cx + i * 7 * s, footY - 24 * s, i * 13 * s, (16 + math.abs(i) * 2) * s, pal, alpha)
  end
  set(pal.body, alpha)
  love.graphics.ellipse("fill", cx, cy + 5 * s, 25 * s, 29 * s)
  set(pal.dark, alpha)
  love.graphics.ellipse("line", cx, cy + 5 * s, 25 * s, 29 * s)
  eye(cx - 7 * s, cy - 2 * s, 3.2 * s, 2.4 * s, pal, alpha)
  eye(cx + 8 * s, cy + 1 * s, 3.5 * s, 2.6 * s, pal, alpha)
  eye(cx + math.sin(t * 1.5) * s, cy + 9 * s, 3.0 * s, 2.2 * s, pal, alpha)
end

local function drawRegard(cx, footY, s, pal, alpha, t)
  local cy = footY - 30 * s
  drawHalo(cx, cy, 22 * s, pal, alpha)
  set(pal.body, alpha)
  love.graphics.circle("fill", cx, cy, 25 * s)
  set(pal.dark, alpha)
  love.graphics.circle("line", cx, cy, 25 * s)
  eye(cx, cy, 12 * s, 8 * s, pal, alpha)
  for i = 0, 7 do
    local a = i * math.pi / 4 + t * 0.18
    eye(cx + math.cos(a) * 17 * s, cy + math.sin(a) * 13 * s, 2.2 * s, 1.8 * s, pal, alpha * 0.85)
  end
end

local function drawOssuaire(cx, footY, s, pal, alpha)
  local cy = footY - 32 * s
  drawHalo(cx, cy, 18 * s, pal, alpha)
  set(pal.body, alpha)
  love.graphics.ellipse("fill", cx, cy - 5 * s, 18 * s, 16 * s)
  love.graphics.rectangle("fill", cx - 11 * s, cy + 6 * s, 22 * s, 27 * s)
  set(pal.dark, alpha)
  love.graphics.rectangle("line", cx - 11 * s, cy + 6 * s, 22 * s, 27 * s)
  eye(cx - 6 * s, cy - 6 * s, 3 * s, 3 * s, pal, alpha)
  eye(cx + 6 * s, cy - 6 * s, 3 * s, 3 * s, pal, alpha)
  lineColor(pal.dark, alpha, 2)
  for i = -2, 2 do love.graphics.line(cx + i * 4 * s, cy + 8 * s, cx + i * 4 * s, cy + 31 * s) end
  for i = 1, 3 do love.graphics.line(cx - 15 * s, cy + i * 7 * s, cx + 15 * s, cy + i * 7 * s) end
end

local function drawKraken(cx, footY, s, pal, alpha, t)
  local cy = footY - 30 * s
  drawHalo(cx, cy, 20 * s, pal, alpha)
  for i = -3, 3 do
    local sway = math.sin(t * 1.3 + i) * 3 * s
    tendril(cx + i * 5 * s, footY - 21 * s, i * 8 * s + sway, 17 * s, pal, alpha)
  end
  set(pal.body, alpha)
  love.graphics.ellipse("fill", cx, cy, 21 * s, 26 * s)
  eye(cx - 6 * s, cy - 3 * s, 3 * s, 2 * s, pal, alpha)
  eye(cx + 6 * s, cy - 3 * s, 3 * s, 2 * s, pal, alpha)
end

local function drawIdole(cx, footY, s, pal, alpha)
  local cy = footY - 31 * s
  drawHalo(cx, cy, 25 * s, pal, alpha)
  set(pal.dark, alpha)
  love.graphics.rectangle("fill", cx - 18 * s, cy - 21 * s, 36 * s, 50 * s)
  set(pal.body, alpha)
  love.graphics.rectangle("line", cx - 18 * s, cy - 21 * s, 36 * s, 50 * s)
  love.graphics.rectangle("fill", cx - 10 * s, cy - 13 * s, 20 * s, 35 * s)
  eye(cx, cy - 1 * s, 7 * s, 5 * s, pal, alpha)
  lineColor(pal.light, alpha * 0.75, 2)
  love.graphics.line(cx - 14 * s, cy + 18 * s, cx + 14 * s, cy + 18 * s)
end

local function drawRuche(cx, footY, s, pal, alpha, t)
  local cy = footY - 28 * s
  drawHalo(cx, cy, 20 * s, pal, alpha)
  for i = -2, 2 do
    local dx = (i < 0 and -1 or 1) * (18 + math.abs(i) * 3) * s
    lineColor(pal.dark, alpha, 3)
    love.graphics.line(cx + i * 4 * s, cy + 13 * s, cx + dx, cy + (20 + math.sin(t + i) * 2) * s)
  end
  set(pal.body, alpha)
  love.graphics.ellipse("fill", cx, cy + 6 * s, 24 * s, 28 * s)
  love.graphics.ellipse("fill", cx, cy - 14 * s, 14 * s, 12 * s)
  eye(cx - 5 * s, cy - 15 * s, 2.4 * s, 2 * s, pal, alpha)
  eye(cx + 5 * s, cy - 15 * s, 2.4 * s, 2 * s, pal, alpha)
end

local function drawBrasier(cx, footY, s, pal, alpha, t)
  local cy = footY - 32 * s
  drawHalo(cx, cy, 18 * s, pal, alpha)
  set(pal.dark, alpha)
  love.graphics.polygon("fill", cx - 18 * s, cy + 25 * s, cx - 10 * s, cy - 19 * s,
    cx, cy - 28 * s, cx + 12 * s, cy - 17 * s, cx + 19 * s, cy + 25 * s)
  set(pal.body, alpha)
  love.graphics.polygon("line", cx - 18 * s, cy + 25 * s, cx - 10 * s, cy - 19 * s,
    cx, cy - 28 * s, cx + 12 * s, cy - 17 * s, cx + 19 * s, cy + 25 * s)
  set(pal.light, alpha * (0.75 + 0.18 * math.sin(t * 4)))
  love.graphics.polygon("fill", cx - 5 * s, cy + 17 * s, cx, cy - 16 * s, cx + 6 * s, cy + 17 * s)
  eye(cx - 6 * s, cy - 6 * s, 2.6 * s, 2 * s, pal, alpha)
  eye(cx + 7 * s, cy - 4 * s, 2.6 * s, 2 * s, pal, alpha)
end

local function drawFloraison(cx, footY, s, pal, alpha)
  local cy = footY - 28 * s
  drawHalo(cx, cy, 20 * s, pal, alpha)
  lineColor(pal.dark, alpha, 4)
  love.graphics.line(cx, cy + 25 * s, cx - 13 * s, cy - 4 * s)
  love.graphics.line(cx, cy + 25 * s, cx + 12 * s, cy - 6 * s)
  love.graphics.line(cx, cy + 25 * s, cx, cy - 14 * s)
  set(pal.body, alpha)
  love.graphics.ellipse("fill", cx, cy + 11 * s, 17 * s, 23 * s)
  set(pal.light, alpha)
  love.graphics.ellipse("fill", cx - 13 * s, cy - 7 * s, 13 * s, 7 * s)
  love.graphics.ellipse("fill", cx + 13 * s, cy - 9 * s, 13 * s, 7 * s)
  love.graphics.ellipse("fill", cx, cy - 18 * s, 16 * s, 8 * s)
  eye(cx, cy + 4 * s, 3 * s, 2.4 * s, pal, alpha)
end

local function drawDevoreur(cx, footY, s, pal, alpha, t)
  local cy = footY - 30 * s
  drawHalo(cx, cy, 21 * s, pal, alpha)
  for i = -2, 2 do tendril(cx, cy + 5 * s, i * 13 * s, (24 + math.sin(t + i) * 3) * s, pal, alpha) end
  set(pal.body, alpha)
  love.graphics.circle("fill", cx, cy, 24 * s)
  set(pal.dark, alpha)
  love.graphics.circle("fill", cx, cy + 2 * s, 12 * s)
  for i = -3, 3 do tooth(cx + i * 3.5 * s, cy - 9 * s, 3 * s, 8 * s, alpha) end
  eye(cx - 9 * s, cy - 14 * s, 2.5 * s, 2 * s, pal, alpha)
  eye(cx + 9 * s, cy - 14 * s, 2.5 * s, 2 * s, pal, alpha)
end

local function drawVermine(cx, footY, s, pal, alpha)
  local cy = footY - 26 * s
  drawHalo(cx, cy, 18 * s, pal, alpha)
  for i = 0, 5 do
    local x = cx - 18 * s + i * 7 * s
    set(i % 2 == 0 and pal.body or pal.dark, alpha)
    love.graphics.ellipse("fill", x, cy + i * 3 * s, 11 * s, 13 * s)
  end
  eye(cx + 18 * s, cy + 15 * s, 3 * s, 2.4 * s, pal, alpha)
  lineColor(pal.light, alpha * 0.55, 1)
  love.graphics.line(cx - 21 * s, cy - 2 * s, cx + 22 * s, cy + 18 * s)
end

local DRAWERS = {
  leviathan = drawLeviathan, regard = drawRegard, ossuaire = drawOssuaire,
  kraken = drawKraken, idole = drawIdole, ruche = drawRuche,
  brasier = drawBrasier, floraison = drawFloraison, devoreur = drawDevoreur,
  vermine = drawVermine,
}

function AbominationSprite.isAbomination(u)
  local spec = u and u.spec
  return spec and spec.visualKind == "abomination"
end

function AbominationSprite.isGeneral(u)
  local spec = u and u.spec
  return spec and spec.visualKind == "abomination_general"
end

function AbominationSprite.isBossOrGeneral(u)
  return AbominationSprite.isAbomination(u) or AbominationSprite.isGeneral(u)
end

function AbominationSprite.shadowSize(u)
  if AbominationSprite.isAbomination(u) then return 23, 5 end
  if AbominationSprite.isGeneral(u) then return 10, 2.5 end
  return 8, 2
end

function AbominationSprite.draw(u, t, opts)
  opts = opts or {}
  local alpha = opts.alpha or 1
  local key = (u.spec and u.spec.abomination) or "leviathan"
  local pal = palette(key)
  local boss = AbominationSprite.isAbomination(u)
  local s = boss and 0.95 or 0.46
  local draw = DRAWERS[key] or drawLeviathan
  love.graphics.setLineStyle("rough")
  draw(u.x, u.y, s, pal, alpha, t or 0)
  if opts.flash and opts.flash > 0 then
    love.graphics.setColor(1, 1, 1, opts.flash)
    love.graphics.ellipse("fill", u.x, u.y - (boss and 27 or 15), boss and 24 or 12, boss and 30 or 14)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return AbominationSprite
