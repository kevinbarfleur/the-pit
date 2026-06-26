-- feel-lab/rooms/modals.lua
-- GALERIE DE MODALES — déclenche chaque type via le ModalStack UNIFIÉ (même enrobage/chorégraphie) + des
-- toasts non-bloquants. Démontre la cohérence : tout pop-up entre/sort de la même façon, gèle/dim le fond.

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")
local Modals  = require("lib.modals")
local SFX     = require("lib.sfx")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720

function Room.new(app)
  return setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0 }, Room)
end
function Room:enter() self.title = "Modals & Popups" end
function Room:update(dt) self.t = self.t + (dt or 0) end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

function Room:triggers()
  local app = self.app
  return {
    { id = "confirm_danger", label = "Confirm — abandon run", tone = "cta", note = "Choix lourd : danger gildé sang + shake possible.",
      go = function()
        app.modals:push(Modals.confirm{
          title = "Abandon the run?", danger = true,
          body = "Your descent ends here. The Pit keeps what you found.",
          confirmLabel = "Abandon", cancelLabel = "Keep going",
          onConfirm = function() app.modals:requestClose(); app:toast("Run abandoned.", "bad") end,
          onCancel  = function() app.modals:requestClose() end,
        })
      end },
    { id = "confirm_neutral", label = "Confirm — neutral", tone = "default", note = "Confirmation calme (laiton).",
      go = function()
        app.modals:push(Modals.confirm{
          title = "Reroll the shop?", body = "Spend 1 gold to refresh the offers.",
          confirmLabel = "Reroll", cancelLabel = "Cancel",
          onConfirm = function() app.modals:requestClose(); app:toast("Shop rerolled.", "info") end,
          onCancel  = function() app.modals:requestClose() end,
        })
      end },
    { id = "banner_victory", label = "Banner — VICTORY", tone = "eco", note = "Grand mot du destin + arpège montant.",
      go = function()
        app.modals:push(Modals.banner{ kind = "victory", flavor = "The Pit yields. For now.",
          onClose = function() app.modals:requestClose() end })
      end },
    { id = "banner_defeat", label = "Banner — DEFEAT", tone = "default", note = "Cérémonial sombre + thud.",
      go = function()
        app.modals:push(Modals.banner{ kind = "defeat", flavor = "The dark drinks deep.",
          onClose = function() app.modals:requestClose() end })
      end },
    { id = "toast_good", label = "Toast — acquired", tone = "ghost", note = "Non-bloquant : ne gèle/capte rien.",
      go = function() SFX.play("coin"); app:toast("Relic acquired — Maw of Ash", "good") end },
    { id = "toast_bad", label = "Toast — life lost", tone = "ghost", note = "Feedback discret en bas d'écran.",
      go = function() SFX.play("error"); app:toast("A life is lost.", "bad") end },
  }
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedC("MODALS · POPUPS · TOASTS", W / 2, 96, c.gold, Theme.title(22), 3)
  Draw.textC("One stack, one choreography — every overlay enters/leaves the same way, dims and freezes what's beneath.",
    W / 2, 134, c.ink3, Theme.body(14))
  Draw.divider(W / 2, 162, 720, c.brass, 0.6)

  local trg = self:triggers()
  local cols = 2
  local bw, bh, gx, gy = 440, 64, 40, 22
  local startX = W / 2 - (bw * cols + gx) / 2
  local y0 = 210
  for i, t in ipairs(trg) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local r = { x = startX + col * (bw + gx), y = y0 + row * (bh + gy + 22), w = bw, h = bh }
    Widgets.button(t.id, r, { label = t.label, tone = t.tone, font = Theme.title(17), onClick = t.go }, self:input(r))
    Draw.textC(t.note, r.x + r.w / 2, r.y + r.h + 2, c.ink4, Theme.body(12))
  end

  Draw.textC("Esc closes the top modal · click a button to feel the entrance/exit.", W / 2, H - 70, c.ink5, Theme.flavor(13))
  Draw.finish()
  self.click = nil
end

function Room:mousemoved(mx, my) self.mx, self.my = mx, my end
function Room:mousepressed(mx, my) self.mx, self.my = mx, my; self.click = { x = mx, y = my } end

return Room
