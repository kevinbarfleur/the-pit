-- feel-lab/rooms/components.lua
-- Planche propre des vrais atomes UI du style The Pit: boutons, slots, panels
-- et drag/drop. Elle sert de reference visuelle, pas de catalogue exhaustif.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Slot = require("src.ui.slot")
local Feel = require("lib.feel")
local Juice = require("lib.juice")
local SFX = require("lib.sfx")
local B = require("lib.behavior")

local Room = {}
Room.__index = Room

local C = Theme.c
local W, H = 1280, 720
local CELL = 60
local LOCKED = 9

local RECTS = {
  cta = { x = 96, y = 224, w = 256, h = 48 },
  reroll = { x = 96, y = 292, w = 122, h = 40 },
  level = { x = 230, y = 292, w = 122, h = 40 },
  strike = { x = 96, y = 350, w = 256, h = 42 },
  score = { x = 96, y = 410, w = 154, h = 42 },
  reset = { x = 266, y = 410, w = 86, h = 42 },
  ic1 = { x = 96, y = 470, w = 38, h = 38 },
  ic2 = { x = 146, y = 470, w = 38, h = 38 },
  ic3 = { x = 196, y = 470, w = 38, h = 38 },
  ic4 = { x = 246, y = 470, w = 38, h = 38 },
}

local TOKENS = {
  { tierCol = C.ink3, level = 1, aff = {} },
  { tierCol = C.poison, level = 2, aff = { "shock" } },
  { tierCol = C.shield, tierBorder = C.shield, level = 1, aff = { "bleed" } },
  { tierCol = C.rot, tierBorder = C.rot, level = 3, aff = { "rot" } },
  { tierCol = C.gold, tierBorder = C.gold, tierGlow = true, level = 2, aff = { "poison", "burn" } },
}

local function hit(r, mx, my)
  return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

local function adjacent(a, b)
  local ca, ra = (a - 1) % 3, math.floor((a - 1) / 3)
  local cb, rb = (b - 1) % 3, math.floor((b - 1) / 3)
  return math.abs(ca - cb) + math.abs(ra - rb) == 1
end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, t = 0,
    score = 0, shown = 0, combo = 0,
  }, Room)
  Theme.load()
  self.benchX0, self.benchY, self.benchStep = 852, 258, 66
  self.boardX0, self.boardY0, self.boardStep = 902, 372, 74
  self.cells = {}
  for i = 1, 9 do self.cells[i] = { token = nil } end
  self.tokens = {}
  for i, spec in ipairs(TOKENS) do
    local hx, hy = self:homePos(i)
    self.tokens[i] = {
      home = i, tierCol = spec.tierCol, tierBorder = spec.tierBorder,
      tierGlow = spec.tierGlow, level = spec.level, aff = spec.aff,
      cell = nil, d = { px = hx, py = hy, gx = hx, gy = hy },
    }
  end
  self:place(1, 5); self:place(2, 2); self:place(3, 4)
  return self
end

function Room:enter()
  self.title = "Real Components"
end

function Room:scenario(name)
  if name == "eyes" then
    local r = RECTS.cta
    self.mx, self.my = r.x + r.w / 2, r.y + r.h / 2
  end
end

function Room:homePos(i)
  return self.benchX0 + (i - 1) * self.benchStep, self.benchY
end

function Room:cellPos(idx)
  local col, row = (idx - 1) % 3, math.floor((idx - 1) / 3)
  return self.boardX0 + col * self.boardStep, self.boardY0 + row * self.boardStep
end

function Room:cellCenter(idx)
  local x, y = self:cellPos(idx)
  return x + CELL / 2, y + CELL / 2
end

function Room:restTarget(tk)
  if tk.cell then return self:cellPos(tk.cell) end
  return self:homePos(tk.home)
end

function Room:place(i, idx)
  local tk = self.tokens[i]
  tk.cell = idx
  self.cells[idx].token = i
  local x, y = self:cellPos(idx)
  tk.d.px, tk.d.py, tk.d.gx, tk.d.gy = x, y, x, y
end

function Room:strike()
  Juice.addTrauma(0.42)
  Juice.freeze(0.05)
  Juice.juice_up("cmp.strike", 0.22)
  SFX.play("thud")
  self.flash = 0.55
end

function Room:scorePlus()
  local add = 60 + math.floor((love and love.math.random() or math.random()) * 180)
  self.score = self.score + add
  self.combo = self.combo + 1
  SFX.ladder(self.combo == 1)
  Juice.juice_up("cmp.score", 0.20)
  Juice.addTrauma(0.10)
end

function Room:resetScore()
  self.score, self.combo = 0, 0
end

function Room:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  for i, tk in ipairs(self.tokens) do
    if i ~= self.dragging then
      local tx, ty = self:restTarget(tk)
      tk.d.gx, tk.d.gy = tx, ty
    end
    B.dragApply(tk.d, dt)
  end
  for _, id in ipairs({ "cta", "reroll", "level", "strike", "score", "reset", "ic1", "ic2", "ic3", "ic4" }) do
    Feel.hover("cmp." .. id, hit(RECTS[id], self.mx, self.my))
  end
  self.shown = self.shown + (self.score - self.shown) * math.min(1, dt * 9)
  if self.flash and self.flash > 0.01 then self.flash = self.flash * math.pow(0.02, dt) end
end

function Room:hoverCell()
  if not self.dragging then return nil end
  local tk = self.tokens[self.dragging]
  local cx, cy = tk.d.px + CELL / 2, tk.d.py + CELL / 2
  local best, bestD
  for idx = 1, 9 do
    if idx ~= LOCKED then
      local ccx, ccy = self:cellCenter(idx)
      local dx, dy = ccx - cx, ccy - cy
      local dist = dx * dx + dy * dy
      if dist < CELL * CELL and (not bestD or dist < bestD) then best, bestD = idx, dist end
    end
  end
  return best
end

function Room:drawButtonsPanel()
  local x, y, w, h = 72, 156, 320, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("BUTTONS", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.text("primary, economy, secondary, ghost, icon", x + 24, y + 50, C.ink5, Theme.label(11))

  Button.draw(RECTS.cta.x, RECTS.cta.y, RECTS.cta.w, RECTS.cta.h, "primary", "ENTER THE PIT", {
    hover = hit(RECTS.cta, self.mx, self.my), feel = Feel.state("cmp.cta"), id = "cmp.cta",
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
  Button.draw(RECTS.reroll.x, RECTS.reroll.y, RECTS.reroll.w, RECTS.reroll.h, "secondary", "REROLL", {
    hover = hit(RECTS.reroll, self.mx, self.my), feel = Feel.state("cmp.reroll"), id = "cmp.reroll",
  })
  Button.draw(RECTS.level.x, RECTS.level.y, RECTS.level.w, RECTS.level.h, "eco", "LEVEL", {
    cost = 5, hover = hit(RECTS.level, self.mx, self.my), feel = Feel.state("cmp.level"), id = "cmp.level",
  })
  Button.draw(RECTS.strike.x, RECTS.strike.y, RECTS.strike.w, RECTS.strike.h, "secondary", "STRIKE", {
    hover = hit(RECTS.strike, self.mx, self.my), feel = Feel.state("cmp.strike"), id = "cmp.strike",
  })
  Button.draw(RECTS.score.x, RECTS.score.y, RECTS.score.w, RECTS.score.h, "eco", "+ SCORE", {
    hover = hit(RECTS.score, self.mx, self.my), feel = Feel.state("cmp.score"), id = "cmp.score",
  })
  Button.ghost(RECTS.reset.x, RECTS.reset.y, RECTS.reset.w, RECTS.reset.h, "RESET", {
    hover = hit(RECTS.reset, self.mx, self.my),
  })

  local kinds = { ic1 = "sigil", ic2 = "prev", ic3 = "next", ic4 = "gear" }
  for _, id in ipairs({ "ic1", "ic2", "ic3", "ic4" }) do
    local r = RECTS[id]
    Button.icon(r.x, r.y, r.w, kinds[id], { hover = hit(r, self.mx, self.my), pressed = Feel.pending("cmp." .. id) })
  end

  local sc = Juice.scale("cmp.score")
  love.graphics.push()
  love.graphics.translate(x + w / 2, y + h - 54)
  love.graphics.scale(sc, sc)
  Draw.textC(string.format("%d", math.floor(self.shown + 0.5)), 0, -14, C.gold, Theme.display(34))
  love.graphics.pop()
  Draw.reset()
  Draw.textC(self.combo > 0 and ("combo x" .. self.combo) or "score feedback", x + w / 2, y + h - 28, C.ink5, Theme.label(11))
end

function Room:drawSlotsPanel()
  local x, y, w, h = 440, 156, 320, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("SLOTS", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.text("all current board states in one grid", x + 24, y + 50, C.ink5, Theme.label(11))

  local states = {
    { "empty", "empty" }, { "selected", "unit" }, { "neighbor", "synergy" },
    { "drop", "drop" }, { "locked", "locked" }, { "hover", "hover" },
  }
  for i, sd in ipairs(states) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local sx, sy = x + 38 + col * 88, y + 92 + row * 92
    local opts = {}
    if sd[1] == "selected" then opts = { tierCol = C.poison, level = 2, affkeys = { "burn" } } end
    Slot.draw(sx, sy, 56, sd[1], opts)
    Draw.textC(sd[2], sx + 28, sy + 62, C.ink4, Theme.label(10))
  end

  Draw.textTrackedL("PANEL", x + 24, y + 294, C.gold, Theme.subhead(12), 1.5)
  local ix, iy, iw = Panel.draw(x + 24, y + 322, w - 48, 78)
  Draw.textTrackedL("MAW OF ASH", ix + 14, iy + 12, C.ember, Theme.title(14), 1)
  Draw.text("clean surface; mood comes from shader and motion", ix + 14, iy + 42, C.ink4, Theme.flavor(12))
end

function Room:drawDragPanel()
  local x, y, w, h = 808, 156, 400, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("DRAG / BOARD", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.text("swap pieces, preserve grid, show adjacency", x + 24, y + 50, C.ink5, Theme.label(11))

  Draw.textTrackedL("BENCH", x + 24, y + 94, C.ink5, Theme.label(9), 1.2)
  for i = 1, #self.tokens do
    local bx, by = self:homePos(i)
    Slot.draw(bx, by, CELL, "empty", {})
  end

  Draw.textTrackedL("BOARD", x + 24, y + 222, C.ink5, Theme.label(9), 1.2)
  local hc = self:hoverCell()
  for idx = 1, 9 do
    local sx, sy = self:cellPos(idx)
    local state = "empty"
    if idx == LOCKED then state = "locked"
    elseif idx == hc then state = self.cells[idx].token and "hover" or "drop" end
    Slot.draw(sx, sy, CELL, state, {})
  end
  for a = 1, 9 do
    if self.cells[a].token then
      for b = a + 1, 9 do
        if self.cells[b].token and adjacent(a, b) then
          local ax, ay = self:cellCenter(a)
          local bx, by = self:cellCenter(b)
          Slot.edge(ax, ay, bx, by, true, 2)
        end
      end
    end
  end
  for i = 1, #self.tokens do if i ~= self.dragging then self:drawToken(self.tokens[i], false) end end
  if self.dragging then self:drawToken(self.tokens[self.dragging], true) end
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("REAL COMPONENTS", 72, 84, C.ink, Theme.title(24), 2)
  Draw.text("Reference courte des composants actuels: meme style, memes proportions, memes reactions.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("current atoms only", W - 72, 126, C.ink5, Theme.body(13))

  self:drawButtonsPanel()
  self:drawSlotsPanel()
  self:drawDragPanel()

  if self.flash and self.flash > 0.01 then
    Draw.setColor(C.ember, 0.12 * self.flash)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Draw.reset()
  end
  Draw.text("Cette page reste volontairement compacte: les effets complexes vont dans Contract, Impact ou Fusion.",
    72, H - 70, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:drawToken(tk, isDrag)
  local fx = B.dragFx(tk.d)
  local px, py = tk.d.px, tk.d.py
  local cx, cy = px + CELL / 2, py + CELL / 2
  if fx.shadow then
    Draw.setColor(C.void, 0.34)
    love.graphics.rectangle("fill", px + 5, py + (-fx.dy) + 9, CELL, CELL)
    Draw.reset()
  end
  love.graphics.push()
  love.graphics.translate(cx, cy + fx.dy)
  love.graphics.rotate(fx.rot or 0)
  love.graphics.scale(fx.scale or 1, fx.scale or 1)
  love.graphics.translate(-cx, -cy)
  Slot.draw(px, py, CELL, "selected", {
    tierCol = tk.tierCol, tierBorder = tk.tierBorder, tierGlow = tk.tierGlow,
    level = tk.level, affkeys = tk.aff,
  })
  love.graphics.pop()
  Draw.reset()
end

function Room:tokenAt(mx, my)
  for i = #self.tokens, 1, -1 do
    local d = self.tokens[i].d
    if mx >= d.px and mx <= d.px + CELL and my >= d.py and my <= d.py + CELL then return i end
  end
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  if hit(RECTS.cta, mx, my) then Feel.press("cmp.cta", function() self:strike() end, { delay = Feel.CTA_DELAY }); return end
  if hit(RECTS.reroll, mx, my) then Feel.press("cmp.reroll", function() SFX.play("whoosh"); Juice.addTrauma(0.08) end); return end
  if hit(RECTS.level, mx, my) then Feel.press("cmp.level", function() self:scorePlus() end); return end
  if hit(RECTS.strike, mx, my) then Feel.press("cmp.strike", function() self:strike() end); return end
  if hit(RECTS.score, mx, my) then Feel.press("cmp.score", function() self:scorePlus() end); return end
  if hit(RECTS.reset, mx, my) then Feel.press("cmp.reset", function() self:resetScore() end); return end
  for _, id in ipairs({ "ic1", "ic2", "ic3", "ic4" }) do
    if hit(RECTS[id], mx, my) then Feel.press("cmp." .. id); return end
  end
  local i = self:tokenAt(mx, my)
  if i then
    local tk = self.tokens[i]
    self.dragFrom = { cell = tk.cell }
    if tk.cell then self.cells[tk.cell].token = nil end
    tk.cell = nil
    self.dragging = i
    B.dragBegin(tk.d, mx, my, mx - tk.d.px, my - tk.d.py)
    SFX.play("pickup")
  end
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
  if self.dragging then B.dragMove(self.tokens[self.dragging].d, mx, my) end
end

function Room:mousereleased(mx, my)
  if not self.dragging then return end
  local i = self.dragging
  local tk = self.tokens[i]
  B.dragEnd(tk.d)
  local best = self:hoverCell()
  local from = self.dragFrom or { cell = nil }
  if best then
    local occ = self.cells[best].token
    if occ and occ ~= i then
      local other = self.tokens[occ]
      other.cell = from.cell
      if from.cell then self.cells[from.cell].token = occ end
      SFX.play("drop"); Juice.addTrauma(0.12)
    else
      SFX.play("drop"); Juice.addTrauma(0.08)
    end
    tk.cell = best
    self.cells[best].token = i
  else
    tk.cell = from.cell
    if from.cell then self.cells[from.cell].token = i end
    SFX.play("drop", { pitch = 0.9 })
  end
  self.dragging, self.dragFrom = nil, nil
end

return Room
