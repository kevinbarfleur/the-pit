-- feel-lab/rooms/flow.lua
-- Explorations UX propres: petits "beats" reutilisables pour transitions,
-- recompenses, scoring et sous-menus. Render-only, aucune simulation.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Slot = require("src.ui.slot")
local Feel = require("lib.feel")
local Juice = require("lib.juice")
local SFX = require("lib.sfx")
local P = require("lib.particles")

local Room = {}
Room.__index = Room

local C = Theme.c
local W, H = 1280, 720

local BEATS = {
  {
    id = "handoff", label = "SCENE HANDOFF", button = "HANDOFF", sound = "whoosh",
    note = "Passage Build -> Combat avec couture organique, pas un swap sec.",
    use = "changement de phase, entree combat, retour bilan",
  },
  {
    id = "rewards", label = "REWARD REVEAL", button = "REWARDS", sound = "success",
    note = "Trois choix qui se revelent en cascade, avec sceau central et focus clair.",
    use = "relique 1-sur-3, grimoire, recompense de palier",
  },
  {
    id = "score", label = "SCORE COUNT-UP", button = "SCORING", sound = "tick",
    note = "Compteur lisible en etapes: base, multiplicateur, total.",
    use = "bilan combat, XP, gold, progression de profondeur",
  },
  {
    id = "submenu", label = "SUBMENU RITUAL", button = "SUBMENU", sound = "drop",
    note = "Sous-menu qui sort d'une dalle, avec dim et bordure vivante.",
    use = "options, details de carte, chronicle, grimoire",
  },
}

local BY_ID = {}
for _, b in ipairs(BEATS) do BY_ID[b.id] = b end

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function clamp01(v) return math.max(0, math.min(1, v or 0)) end
local function smooth(a, b, x)
  if a == b then return x >= b and 1 or 0 end
  local t = clamp01((x - a) / (b - a))
  return t * t * (3 - 2 * t)
end
local function lerp(a, b, t) return a + (b - a) * t end
local function alpha(c, a) return { c[1], c[2], c[3], a } end
local function hash(i, salt) return (math.sin(i * 91.17 + salt * 43.41) * 43758.5453) % 1 end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, t = 0,
    active = "handoff", eventT = 0, dur = 1.65, didDemo = false,
  }, Room)
  Theme.load()
  return self
end

function Room:enter()
  self.title = "UX Beats"
end

function Room:beat()
  return BY_ID[self.active] or BEATS[1]
end

function Room:beatRect(i)
  return { x = 96, y = 244 + (i - 1) * 58, w = 220, h = 42 }
end

function Room:playRect()
  return { x = 526, y = 528, w = 256, h = 42 }
end

function Room:trigger(beat)
  beat = beat or self:beat()
  self.active = beat.id
  self.eventT = self.dur
  P.clear()
  if beat.sound then SFX.play(beat.sound, { pitch = beat.id == "score" and 0.86 or 0.74 }) end
  if beat.id == "rewards" then
    P.explosion("seal", 654, 350)
    SFX.ladder(true); SFX.ladder(); SFX.ladder()
    Juice.addTrauma(0.22)
  elseif beat.id == "score" then
    P.explosion("unlock", 654, 344)
    Juice.addTrauma(0.12)
  elseif beat.id == "submenu" then
    P.explosion("seal", 654, 328)
    Juice.addTrauma(0.18)
  else
    P.explosion("death", 654, 350)
    Juice.addTrauma(0.26)
  end
  Juice.freeze(beat.id == "rewards" and 0.035 or 0.020)
  Juice.juice_up("flow.stage", 0.24)
end

function Room:scenario(name)
  self.didDemo = true
  self:trigger(BY_ID[name] or self:beat())
end

function Room:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  if not self.didDemo and self.t > 0.20 then
    self.didDemo = true
    self:trigger(self:beat())
  end
  self.eventT = math.max(0, self.eventT - dt)
  P.update(dt * Juice.timeScale())
  for i, b in ipairs(BEATS) do
    Feel.hover("flow." .. b.id, ptIn(self.mx, self.my, self:beatRect(i)))
  end
  Feel.hover("flow.play", ptIn(self.mx, self.my, self:playRect()))
end

function Room:progress()
  return 1 - clamp01(self.eventT / self.dur)
end

function Room:drawControls()
  local x, y, w, h = 72, 156, 272, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("UX BEATS", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Explorations courtes pour phases, menus, scoring et recompenses.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))
  for i, b in ipairs(BEATS) do
    local r = self:beatRect(i)
    local id = "flow." .. b.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, self.active == b.id and "primary" or "secondary", b.button, {
      hover = hot, feel = Feel.state(id), id = id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end
end

local function drawMiniBoard(x, y, scale)
  scale = scale or 1
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  for row = 0, 2 do
    for col = 0, 2 do
      local idx = row * 3 + col + 1
      local st = idx == 5 and "selected" or ((idx == 2 or idx == 4) and "neighbor" or "empty")
      Slot.draw(col * 42, row * 42, 36, st, {
        tierCol = C.rot, tierBorder = C.gold, tierGlow = idx == 5,
        level = idx == 5 and 2 or nil,
        affkeys = idx == 5 and { "poison" } or nil,
      })
    end
  end
  love.graphics.pop()
  Draw.reset()
end

function Room:drawHandoff(x, y, w, h, p)
  local seam = smooth(0.08, 0.72, p)
  local leftW = w * (0.52 - seam * 0.16)
  local rightX = x + w * (0.48 + (1 - seam) * 0.22)
  local top = y + 94
  Draw.rect(x + 34, top, leftW, 210, alpha(C.stone800, 0.56), C.iron, 1)
  Draw.textTrackedL("BUILD", x + 58, top + 24, C.gold, Theme.label(12), 1.2)
  drawMiniBoard(x + 84, top + 74, 1.0)
  Draw.rect(rightX, top, w - (rightX - x) - 34, 210, alpha(C.blood, 0.12 + seam * 0.12), C.bloodL, 1)
  Draw.textTrackedL("COMBAT", rightX + 24, top + 24, C.bloodL, Theme.label(12), 1.2)
  for i = 1, 3 do
    local yy = top + 75 + i * 34
    Draw.rect(rightX + 36 + i * 40, yy, 62, 9, C.stone900, C.iron, 1)
    Draw.rect(rightX + 37 + i * 40, yy + 1, 40 + i * 5, 7, C.blood)
  end

  local sx = x + w * 0.50
  for i = 1, 15 do
    local yy = top + 4 + i * 14
    local off = math.sin(i * 1.7 + self.t * 2.2) * (8 + seam * 18)
    local len = 10 + seam * (24 + hash(i, 3.2) * 42)
    Draw.setColor(i % 3 == 0 and C.rot or C.blood, 0.22 + seam * 0.42)
    love.graphics.rectangle("fill", sx + off, yy, len, 4)
  end
  Draw.reset()
end

function Room:drawRewards(x, y, w, h, p)
  local cardW, cardH, gap = 124, 176, 22
  local startX = x + w / 2 - (cardW * 3 + gap * 2) / 2
  for i = 1, 3 do
    local k = smooth(0.10 + (i - 1) * 0.15, 0.48 + (i - 1) * 0.15, p)
    local lift = (1 - k) * 26
    local cx = startX + (i - 1) * (cardW + gap)
    local cy = y + 144 + lift
    love.graphics.push()
    love.graphics.translate(cx + cardW / 2, cy + cardH / 2)
    love.graphics.scale(0.88 + k * 0.12, 0.88 + k * 0.12)
    love.graphics.translate(-(cx + cardW / 2), -(cy + cardH / 2))
    Panel.draw(cx, cy, cardW, cardH, { accent = i == 2 and C.gold or C.brass })
    Draw.textTrackedC("RELIC", cx + cardW / 2, cy + 22, i == 2 and C.gold or C.ink3, Theme.label(9), 1)
    Draw.rect(cx + 30, cy + 50, 64, 64, alpha(i == 2 and C.rot or C.stone800, 0.48), i == 2 and C.gold or C.iron, 1)
    Draw.textWrap(i == 2 and "power spike" or "build plan", cx + 16, cy + 126, cardW - 32, C.ink4, Theme.flavor(12), "center")
    love.graphics.pop()
    if k > 0.25 then
      Draw.setColor(i == 2 and C.gold or C.brass, (k - 0.25) * 0.28)
      love.graphics.rectangle("line", cx - 2, cy - 2, cardW + 4, cardH + 4)
      Draw.reset()
    end
  end
end

function Room:drawScore(x, y, w, h, p)
  local chips = math.floor(lerp(0, 34, smooth(0.04, 0.32, p)) + 0.5)
  local mult = math.floor(lerp(0, 11, smooth(0.28, 0.58, p)) + 0.5)
  local total = math.floor(chips * math.max(1, mult) * smooth(0.54, 0.88, p) + 0.5)
  local bx = x + 74
  local by = y + 148
  local boxes = {
    { "BASE", chips, C.ink2 },
    { "MORE", "x" .. tostring(math.max(1, mult)), C.rot },
    { "TOTAL", total, C.gold },
  }
  for i, b in ipairs(boxes) do
    local k = smooth((i - 1) * 0.18, 0.34 + (i - 1) * 0.18, p)
    local xx = bx + (i - 1) * 148
    Draw.rect(xx, by - k * 10, 126, 96, alpha(C.stone800, 0.52), i == 3 and C.gold or C.iron, 1)
    Draw.textTrackedC(b[1], xx + 63, by + 14 - k * 10, C.ink5, Theme.label(9), 1)
    Draw.textTrackedC(tostring(b[2]), xx + 63, by + 42 - k * 10, b[3], Theme.subhead(i == 3 and 26 or 22), 1.2)
  end
  for i = 1, 18 do
    local k = smooth(0.62, 0.92, p)
    if k > 0 then
      local xx = x + w / 2 + math.cos(i * 2.4) * (30 + hash(i, 4) * 120) * k
      local yy = y + 210 + math.sin(i * 1.9) * (18 + hash(i, 8) * 48) * k
      Draw.setColor(i % 3 == 0 and C.gold or C.brass, 0.12 + 0.42 * (1 - k))
      love.graphics.rectangle("fill", xx, yy, 4, 4)
    end
  end
  Draw.reset()
end

function Room:drawSubmenu(x, y, w, h, p)
  local dim = smooth(0.08, 0.38, p)
  Draw.rect(x + 36, y + 94, w - 72, h - 154, alpha(C.stone900, 0.38), C.iron, 1)
  Draw.textTrackedL("GRIMOIRE ENTRY", x + 62, y + 120, C.gold, Theme.label(11), 1.2)
  Draw.textWrap("Une dalle selectionnee doit ouvrir son detail sans perdre le contexte.",
    x + 62, y + 148, w - 124, C.ink4, Theme.body(13))
  if dim > 0 then
    Draw.rect(x + 36, y + 94, w - 72, h - 154, alpha(C.void, 0.54 * dim))
  end
  local k = smooth(0.18, 0.62, p)
  local mw, mh = 290, 172
  local mx = x + w / 2 - mw / 2
  local my = y + 146 + (1 - k) * 34
  love.graphics.push()
  love.graphics.translate(mx + mw / 2, my + mh / 2)
  love.graphics.scale(0.88 + 0.12 * k, 0.88 + 0.12 * k)
  love.graphics.translate(-(mx + mw / 2), -(my + mh / 2))
  Panel.draw(mx, my, mw, mh, { accent = C.rot })
  Draw.textTrackedL("DETAIL", mx + 24, my + 22, C.gold, Theme.label(10), 1.1)
  Draw.textTrackedL("THE WATCHING SEAL", mx + 24, my + 48, C.ink, Theme.subhead(15), 1.2)
  Draw.textWrap("Le fond s'assombrit, la source reste lisible, le panneau a un climax court.",
    mx + 24, my + 80, mw - 48, C.ink3, Theme.body(12))
  Button.draw(mx + 24, my + mh - 48, 116, 30, "secondary", "CLOSE", { t = self.t })
  love.graphics.pop()
  Draw.reset()
end

function Room:drawStage()
  local x, y, w, h = 376, 156, 520, 430
  local beat = self:beat()
  local p = self:progress()
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("LIVE EXPLORATION", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap(beat.note, x + 24, y + 48, w - 48, C.ink4, Theme.body(13))

  local sc = Juice.scale("flow.stage")
  love.graphics.push()
  love.graphics.translate(x + w / 2, y + h / 2)
  love.graphics.scale(sc, sc)
  love.graphics.translate(-(x + w / 2), -(y + h / 2))
  if beat.id == "rewards" then self:drawRewards(x, y, w, h, p)
  elseif beat.id == "score" then self:drawScore(x, y, w, h, p)
  elseif beat.id == "submenu" then self:drawSubmenu(x, y, w, h, p)
  else self:drawHandoff(x, y, w, h, p) end
  love.graphics.pop()
  Draw.reset()
  P.draw()

  local r = self:playRect()
  Button.draw(r.x, r.y, r.w, r.h, "secondary", "PLAY " .. beat.button, {
    hover = ptIn(self.mx, self.my, r), feel = Feel.state("flow.play"), id = "flow.play",
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
end

function Room:drawInspector()
  local x, y, w, h = 928, 156, 280, 430
  local beat = self:beat()
  Panel.draw(x, y, w, h, { accent = C.brass })
  Draw.textTrackedL("INTENTION", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textTrackedL(beat.label, x + 24, y + 52, C.ink, Theme.subhead(18), 1.3)
  Draw.textWrap(beat.note, x + 24, y + 86, w - 48, C.ink3, Theme.body(12))
  Draw.rect(x + 24, y + 164, w - 48, 78, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("USE CASE", x + 38, y + 178, C.gold, Theme.label(9), 1)
  Draw.textWrap(beat.use, x + 38, y + 198, w - 76, C.ink3, Theme.body(12))
  Draw.rect(x + 24, y + 270, w - 48, 98, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("RULE", x + 38, y + 284, C.gold, Theme.label(9), 1)
  Draw.textWrap("Un beat valide doit rester lisible en une capture, puis gagner en mouvement et en son.",
    x + 38, y + 304, w - 76, C.ink4, Theme.body(12))
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("UX BEATS", 72, 84, C.ink, Theme.title(24), 2)
  Draw.text("Petites explorations autonomes pour les moments qui relient les ecrans du jeu.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("render-only · candidates, not gameplay", W - 72, 126, C.ink5, Theme.body(13))
  self:drawControls()
  self:drawStage()
  self:drawInspector()
  Draw.text("A garder seulement si le beat clarifie une action reelle: phase, choix, bilan ou detail.",
    72, H - 70, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  for i, b in ipairs(BEATS) do
    if ptIn(mx, my, self:beatRect(i)) then
      Feel.press("flow." .. b.id, function() self:trigger(b) end, { delay = 0.10 })
      return
    end
  end
  if ptIn(mx, my, self:playRect()) then
    local beat = self:beat()
    Feel.press("flow.play", function() self:trigger(beat) end, { delay = 0.10 })
  end
end

return Room
