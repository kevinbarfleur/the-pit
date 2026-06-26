-- feel-lab/rooms/menu.lua
-- Room TITRE du lab : porte d'entrée vers les 3 ateliers. Démontre la navigation (switch + transition) et le
-- shell persistant. Boutons-héros avec juice complet.

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")

local Menu = {}
Menu.__index = Menu
local c = Theme.c
local W, H = 1280, 720

function Menu.new(app)
  return setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0 }, Menu)
end

function Menu:enter() self.title = "Feel Lab" end
function Menu:update(dt) self.t = self.t + (dt or 0) end

local ITEMS = {
  { key = "interaction", label = "Interaction Feel",  sub = "hover · click · drag · sound", kind = "slide_left" },
  { key = "components",  label = "Real Components",   sub = "the actual The Pit code — eye buttons · board slots", kind = "slide_left" },
  { key = "levelup",     label = "Level-Up / Fusion", sub = "ta-ta-ta-TAAA · cascade · board/bench/shop", kind = "slide_left" },
  { key = "combat_lab",  label = "Combat Lab",        sub = "real fight · dmg numbers + attack VFX seams · manual bench", kind = "slide_left" },
  { key = "sound",       label = "Sound Design",      sub = "candy · grimdark · visceral · nightmare", kind = "slide_left" },
  { key = "transitions", label = "Scene Transitions", sub = "fade · dissolve · iris · slide", kind = "slide_left" },
  { key = "modals",      label = "Modals & Popups",   sub = "confirm · banner · toast",       kind = "slide_left" },
}

function Menu:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

function Menu:draw(view)
  Draw.begin(view)
  -- titre cérémonial
  Draw.textTrackedC("THE PIT", W / 2, 120, c.ink, Theme.display(96), 4)
  Draw.textTrackedC("· FEEL & FEEDBACK LABORATORY ·", W / 2, 232, c.gold, Theme.title(18), 4)
  Draw.divider(W / 2, 270, 560, c.brass, 0.7)

  local bw, bh, gap = 520, 50, 12
  local x = W / 2 - bw / 2
  local y0 = 278
  for i, it in ipairs(ITEMS) do
    local r = { x = x, y = y0 + (i - 1) * (bh + gap), w = bw, h = bh }
    Widgets.button("menu_" .. it.key, r, {
      label = it.label, tone = (i == 1) and "cta" or "default", font = Theme.title(22),
      onClick = function() self.app:go(it.key, it.kind) end,
    }, self:input(r))
    -- sous-titre sous le bouton
    Draw.textC(it.sub, r.x + r.w / 2, r.y + r.h + 1, c.ink4, Theme.body(13))
  end

  Draw.textC("A standalone playground — nothing here touches the real game.", W / 2, H - 70, c.ink5, Theme.flavor(14))
  Draw.finish()
  self.click = nil
end

function Menu:mousemoved(mx, my) self.mx, self.my = mx, my end
function Menu:mousepressed(mx, my) self.mx, self.my = mx, my; self.click = { x = mx, y = my } end

return Menu
