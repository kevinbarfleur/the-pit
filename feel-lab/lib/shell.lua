-- feel-lab/lib/shell.lua
-- Chrome persistant du Feel Lab, aligne sur le langage recent Build/Grimoire :
-- bandeau fin, valeurs compactes, bouton retour iconique, aucun ancien wordmark.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Button = require("src.ui.button")
local Feel = require("lib.feel")

local Shell = {}

local W, H = 1280, 720
local BAR_H = 54
local FOOT_H = 26

local function alpha(col, a)
  return { col[1], col[2], col[3], a }
end

local function titleText(ctx)
  return tostring((ctx and ctx.title) or "Feel Lab"):upper()
end

function Shell.drawBack(view)
  Draw.begin(view)
  local C = Theme.c
  local n = 52
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local top, bot = C.stone900, C.void
    local r = top[1] + (bot[1] - top[1]) * t
    local g = top[2] + (bot[2] - top[2]) * t
    local b = top[3] + (bot[3] - top[3]) * t
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 0, H * t, W, H / n + 1)
  end
  Draw.rect(0, H - 116, W, 116, alpha(C.bgEmber, 0.38))
  Draw.finish()
end

local function metric(rx, label, value, col)
  local vf = Theme.label(13)
  local lf = Theme.label(8)
  Draw.textR(value, rx, 11, col, vf)
  Draw.textR(label, rx, 31, Theme.c.ink5, lf)
  return rx - math.max(Draw.textWidth(value, vf), Draw.textWidth(label, lf)) - 28
end

function Shell.drawFront(view, ctx)
  ctx = ctx or {}
  local C = Theme.c
  local back
  Draw.begin(view)

  Panel.vgrad(0, 0, W, BAR_H, { 0x1d / 255, 0x17 / 255, 0x10 / 255, 1 }, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 1 })
  Draw.setColor(C.brassS, 0.16)
  love.graphics.rectangle("fill", 0, 0, W, 1)
  Draw.reset()
  Draw.rect(0, BAR_H - 1, W, 1, C.iron)

  local x = 22
  if ctx.canBack then
    back = { x = 18, y = 12, w = 30, h = 30 }
    local over = ctx.mx and Shell.backHit(back, ctx.mx, ctx.my)
    Feel.hover("shell_back", over and true or false)
    Button.icon(back.x, back.y, back.w, "prev", {
      hover = over, pressed = Feel.pending("shell_back"),
    })
    x = 62
  end

  Draw.textTrackedL("THE PIT LAB", x, 9, C.ink5, Theme.label(9), 1.4)
  Draw.textTrackedL(titleText(ctx), x, 25, C.gold, Theme.title(17), 1.8)

  local st = ctx.status or {}
  local rx = W - 22
  if st.fps then rx = metric(rx, "FPS", tostring(st.fps), C.ink3) end
  if st.profile ~= nil then rx = metric(rx, "FEEL", string.format("%d%%", math.floor(st.profile * 100 + 0.5)), C.gold) end
  if st.sfx ~= nil then rx = metric(rx, "SOUND", st.sfx and "ON" or "OFF", st.sfx and C.regen or C.ink4) end
  if st.fx ~= nil then rx = metric(rx, "SHADER", st.fx and "ON" or "OFF", st.fx and C.regen or C.ink4) end

  -- Footer discret: aide de navigation, sans bloc epais type ancien prototype.
  Draw.rect(0, H - FOOT_H, W, FOOT_H, alpha(C.stone850, 0.92))
  Draw.rect(0, H - FOOT_H, W, 1, alpha(C.brassS, 0.22))
  if ctx.hint then
    Draw.textC(ctx.hint, W / 2, H - FOOT_H + 7, C.ink5, Theme.label(10))
  end

  Draw.finish()
  return back
end

function Shell.backHit(back, mx, my)
  if not back then return false end
  return mx >= back.x and mx <= back.x + back.w and my >= back.y and my <= back.y + back.h
end

Shell.BAR_H, Shell.FOOT_H, Shell.W, Shell.H = BAR_H, FOOT_H, W, H
return Shell
