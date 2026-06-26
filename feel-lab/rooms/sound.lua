-- feel-lab/rooms/sound.lua
-- ATELIER SOUND DESIGN — compare 4 PACKS sonores (Candy/Grimdark/Visceral/Nightmare) et AUDITIONNE chaque son
-- du vocabulaire d'UI. Le pack choisi s'applique à TOUT le lab (le son suit la DA). Démontre qu'on échange une
-- ambiance entière sans toucher l'UI (même noms de vocabulaire, recettes de synthèse différentes).

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")
local SFX     = require("lib.sfx")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720

-- vocabulaire auditionnable (nom interne -> libellé + ton de bouton)
local VOCAB = {
  { "hover", "Hover", "default" }, { "tick", "Tick", "default" },
  { "press", "Press", "default" }, { "click", "Click", "default" },
  { "pop", "Pop", "default" },     { "back", "Back / cancel", "default" },
  { "coin", "Coin", "eco" },       { "pickup", "Pickup", "default" },
  { "drop", "Drop", "default" },   { "whoosh", "Whoosh", "default" },
  { "error", "Error", "cta" },     { "success", "Success", "eco" },
  { "thud", "Thud (impact)", "default" }, { "defeat", "Defeat (fall)", "cta" },
}

function Room.new(app)
  return setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0, lcount = 0 }, Room)
end
function Room:enter() self.title = "Sound Design" end
function Room:update(dt) self.t = self.t + (dt or 0) end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

function Room:playLadder()
  self.lcount = self.lcount % 8 + 1
  SFX.ladder(self.lcount == 1)
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedC("SOUND DESIGN", W / 2, 92, c.gold, Theme.title(24), 3)
  Draw.textC("Pick a mood — it applies to the whole lab. Then audition each sound below.", W / 2, 130, c.ink3, Theme.body(14))

  -- ── sélecteur de pack ────────────────────────────────────────────────────────────────────────────────
  local packs = SFX.PACK_LIST
  local ph, gap = 56, 14
  local pw = math.min(268, (W - 120 - gap * (#packs - 1)) / #packs)  -- adaptatif (tient 5 packs)
  local x0 = W / 2 - (pw * #packs + gap * (#packs - 1)) / 2
  for i, p in ipairs(packs) do
    local r = { x = x0 + (i - 1) * (pw + gap), y = 164, w = pw, h = ph }
    local sel = (SFX.pack == p.id)
    Widgets.button("pack_" .. p.id, r, { label = p.name, tone = sel and "cta" or "ghost", font = Theme.title(18),
      onClick = function() SFX.setPack(p.id); SFX.play("pop") end }, self:input(r))
  end
  -- description du pack courant
  local cur
  for _, p in ipairs(packs) do if p.id == SFX.pack then cur = p end end
  if cur then Draw.textC(cur.desc, W / 2, 230, c.ink2, Theme.flavor(15)) end

  -- ── volume maître + on/off ───────────────────────────────────────────────────────────────────────────
  Draw.textTrackedC("MASTER", W / 2 - 150, 268, c.ink4, Theme.label(11), 2)
  local mR = { x = W / 2 - 200, y = 286, w = 40, h = 38 }
  local pR = { x = W / 2 - 60, y = 286, w = 40, h = 38 }
  Widgets.button("vol_min", mR, { label = "-", tone = "default", onClick = function() SFX.setMaster(SFX.master - 0.1) end }, self:input(mR))
  Widgets.button("vol_max", pR, { label = "+", tone = "default", onClick = function() SFX.setMaster(SFX.master + 0.1) end }, self:input(pR))
  Draw.textC(string.format("%d%%", math.floor(SFX.master * 100 + 0.5)), W / 2 - 110, 295, c.ink, Theme.label(17))
  local tR = { x = W / 2 + 40, y = 290, w = 56, h = 30 }
  Widgets.toggle("snd_on", tR, { on = SFX.enabled, label = "Sound",
    onClick = function() local on = SFX.toggle(); self.app:setSfx(on) end }, self:input(tR))

  Draw.divider(W / 2, 350, W - 200, c.brass, 0.5)

  -- ── grille d'audition ────────────────────────────────────────────────────────────────────────────────
  Draw.textTrackedC("AUDITION", W / 2, 366, c.gold, Theme.title(14), 3)
  local cols = 4
  local bw, bh, gx, gy = 260, 50, 24, 18
  local gridW = bw * cols + gx * (cols - 1)
  local sx = W / 2 - gridW / 2
  local y0 = 402
  for i, v in ipairs(VOCAB) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local r = { x = sx + col * (bw + gx), y = y0 + row * (bh + gy), w = bw, h = bh }
    Widgets.button("au_" .. v[1], r, { label = v[2], tone = v[3], font = Theme.title(15),
      onClick = function() SFX.play(v[1]) end }, self:input(r))
  end
  -- ladder (combo) à part : suit la grille, monte d'un cran à chaque clic
  local li = #VOCAB
  local lr = { x = sx + (li % cols) * (bw + gx), y = y0 + math.floor(li / cols) * (bh + gy), w = bw, h = bh }
  Widgets.button("au_ladder", lr, { label = "Ladder (combo) ^", tone = "eco", font = Theme.title(15),
    onClick = function() self:playLadder() end }, self:input(lr))

  Draw.textC("Hovering a tile also plays the pack's hover sound. The combo ladder climbs each click.",
    W / 2, H - 64, c.ink5, Theme.flavor(13))
  Draw.finish()
  self.click = nil
end

function Room:mousemoved(mx, my) self.mx, self.my = mx, my end
function Room:mousepressed(mx, my) self.mx, self.my = mx, my; self.click = { x = mx, y = my } end

return Room
