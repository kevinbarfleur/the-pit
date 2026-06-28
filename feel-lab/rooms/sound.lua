-- feel-lab/rooms/sound.lua
-- Soundboard semantique. Oneiric reste l'identite sonore par defaut ; les autres
-- packs ne sont gardes que pour comparaison ponctuelle, pas comme direction active.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Feel = require("lib.feel")
local SFX = require("lib.sfx")

local Room = {}
Room.__index = Room

local C = Theme.c
local W, H = 1280, 720

local VOCAB = {
  { id = "hover", label = "Hover", group = "UI", note = "soft focus tick" },
  { id = "press", label = "Press", group = "UI", note = "pointer-down body" },
  { id = "back", label = "Back", group = "UI", note = "cancel / retreat" },
  { id = "error", label = "Error", group = "UI", note = "refused action" },
  { id = "coin", label = "Buy", group = "Economy", note = "gold spend" },
  { id = "pickup", label = "Pickup", group = "Board", note = "drag starts" },
  { id = "drop", label = "Drop", group = "Board", note = "release / return" },
  { id = "place", label = "Place", group = "Board", note = "valid socket" },
  { id = "unlock", label = "Unlock", group = "Progress", note = "slot opens" },
  { id = "success", label = "Reward", group = "Reward", note = "relic / victory beat" },
  { id = "thud", label = "Impact", group = "Combat", note = "heavy hit + shake" },
  { id = "defeat", label = "Defeat", group = "Combat", note = "fall into the pit" },
}

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function Room.new(app)
  Theme.load()
  return setmetatable({ app = app, mx = -1, my = -1, t = 0, last = "none", ladder = 0 }, Room)
end

function Room:enter()
  self.title = "SFX Vocabulary"
end

function Room:vocabRect(i)
  local col = (i - 1) % 4
  local row = math.floor((i - 1) / 4)
  return { x = 74 + col * 286, y = 214 + row * 92, w = 252, h = 68 }
end

function Room:update(dt)
  self.t = self.t + (dt or 0)
  for i, v in ipairs(VOCAB) do
    Feel.hover("sfx." .. v.id, ptIn(self.mx, self.my, self:vocabRect(i)))
  end
  for i, p in ipairs(SFX.PACK_LIST) do
    local r = { x = 74 + (i - 1) * 140, y = 548, w = 128, h = 34 }
    Feel.hover("sfx.pack." .. p.id, ptIn(self.mx, self.my, r))
  end
  Feel.hover("sfx.ladder", ptIn(self.mx, self.my, { x = 994, y = 548, w = 184, h = 34 }))
end

function Room:play(id)
  self.last = id
  SFX.play(id)
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("SFX VOCABULARY", 74, 86, C.ink, Theme.title(24), 2)
  Draw.text("Default direction is Oneiric: low, soft, reverberant, never harsh. This page audits action cues, not brand mood.",
    74, 124, C.ink4, Theme.body(14))
  Draw.textR("last: " .. self.last, W - 74, 124, C.gold, Theme.label(12))

  for i, v in ipairs(VOCAB) do
    local r = self:vocabRect(i)
    local hot = ptIn(self.mx, self.my, r)
    Panel.draw(r.x, r.y, r.w, r.h)
    Button.draw(r.x + 10, r.y + 10, 104, 36, (v.group == "Combat" or v.id == "error") and "secondary" or "eco", v.label, {
      hover = hot, feel = Feel.state("sfx." .. v.id), id = "sfx." .. v.id,
    })
    Draw.textTrackedL(v.group:upper(), r.x + 130, r.y + 12, C.gold, Theme.label(9), 1)
    Draw.text(v.note, r.x + 130, r.y + 32, hot and C.ink2 or C.ink4, Theme.body(12))
  end

  Draw.textTrackedL("PACK COMPARISON", 74, 520, C.ink4, Theme.label(10), 1.4)
  Draw.text("Secondary only. Keep Oneiric unless a cue proves wrong in playtest.", 238, 520, C.ink5, Theme.flavor(12))
  for i, p in ipairs(SFX.PACK_LIST) do
    local r = { x = 74 + (i - 1) * 140, y = 548, w = 128, h = 34 }
    local sel = SFX.pack == p.id
    Button.draw(r.x, r.y, r.w, r.h, sel and "primary" or "secondary", p.name, {
      hover = ptIn(self.mx, self.my, r), feel = Feel.state("sfx.pack." .. p.id), id = "sfx.pack." .. p.id,
    })
  end
  local lr = { x = 994, y = 548, w = 184, h = 34 }
  Button.draw(lr.x, lr.y, lr.w, lr.h, "eco", "COMBO LADDER", {
    hover = ptIn(self.mx, self.my, lr), feel = Feel.state("sfx.ladder"), id = "sfx.ladder",
  })

  Draw.text("Every future feel event should call one of these semantic cues, not an ad-hoc sound name buried in a scene.",
    74, H - 66, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  for i, v in ipairs(VOCAB) do
    if ptIn(mx, my, self:vocabRect(i)) then
      Feel.press("sfx." .. v.id, function() self:play(v.id) end, { delay = 0.05 })
      return
    end
  end
  for i, p in ipairs(SFX.PACK_LIST) do
    local r = { x = 74 + (i - 1) * 140, y = 548, w = 128, h = 34 }
    if ptIn(mx, my, r) then
      Feel.press("sfx.pack." .. p.id, function()
        SFX.setPack(p.id); self:play("pop")
      end, { delay = 0.05 })
      return
    end
  end
  if ptIn(mx, my, { x = 994, y = 548, w = 184, h = 34 }) then
    Feel.press("sfx.ladder", function()
      self.ladder = self.ladder % 8 + 1
      self.last = "ladder " .. self.ladder
      SFX.ladder(self.ladder == 1)
    end, { delay = 0.05 })
  end
end

return Room
