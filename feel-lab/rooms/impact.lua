-- feel-lab/rooms/impact.lua
-- Atelier propre pour les impacts de combat: pas de simulation, uniquement
-- feedback visuel/sonore sur une surface proche du jeu actuel.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Slot = require("src.ui.slot")
local Feel = require("lib.feel")
local Juice = require("lib.juice")
local SFX = require("lib.sfx")
local P = require("lib.particles")
local DmgNumbers = require("rooms.dmgnumbers")

local Room = {}
Room.__index = Room

local C = Theme.c
local W, H = 1280, 720
local Number = DmgNumbers.Common
local STAGE = { x = 376, y = 156, w = 520, h = 430 }
local UNIT = { slot = 68, rx = 38, ry = 44 }

local IMPACTS = {
  {
    id = "light", label = "LIGHT HIT", sound = "thud", damage = 12,
    trauma = 0.18, freeze = 0.018, burst = "spark",
    visual = "small lunge, sharp number, no camera domination",
    rule = "use for repeated basic attacks",
  },
  {
    id = "heavy", label = "HEAVY HIT", sound = "thud", damage = 48,
    trauma = 0.44, freeze = 0.055, burst = "ember", ring = true,
    visual = "telegraphed lunge, hitstop, ring, large red number",
    rule = "use when the player must feel a real HP swing",
  },
  {
    id = "dot", label = "DOT TICK", sound = "tick", damage = 7,
    trauma = 0.04, freeze = 0.000, burst = "mote",
    visual = "tiny pulse near the HP bar, restrained number",
    rule = "must not steal focus from active attacks",
  },
  {
    id = "block", label = "BLOCK", sound = "drop", damage = 0,
    trauma = 0.12, freeze = 0.025, burst = "shard",
    visual = "cold shield spark, no red damage language",
    rule = "communicates mitigation without reading like a miss",
  },
  {
    id = "death", label = "DEATH BURST", sound = "defeat", damage = 96,
    trauma = 0.58, freeze = 0.075, burst = "ash", ring = true,
    visual = "target collapses into ash, reward lane remains readable",
    rule = "big payoff, but it must end cleanly before shop/build UI",
  },
}

local IMPACT_BY_ID = {}
for _, i in ipairs(IMPACTS) do IMPACT_BY_ID[i.id] = i end

local DAMAGE_FAMILIES = {
  { id = "attack", label = "ATTACK", sound = "thud" },
  { id = "poison", label = "POISON", sound = "tick" },
  { id = "burn", label = "BURN", sound = "tick" },
  { id = "bleed", label = "BLEED", sound = "thud" },
  { id = "rot", label = "ROT", sound = "drop" },
  { id = "shock", label = "SHOCK", sound = "thud" },
}
local FAMILY_BY_ID = {}
for _, f in ipairs(DAMAGE_FAMILIES) do FAMILY_BY_ID[f.id] = f end

local FONT_STYLES = DmgNumbers.FONT_STYLES or {
  { id = "carved", name = "Cinzel grave" },
  { id = "mono", name = "Space Mono" },
  { id = "pixel", name = "Silkscreen pixel" },
  { id = "operator", name = "Pixel Operator" },
}
local FONT_BY_ID = {}
for _, f in ipairs(FONT_STYLES) do FONT_BY_ID[f.id] = f end

local FX_MODES = {
  { id = "signature", label = "SIGN" },
  { id = "bloom", label = "BLOOM" },
}
local FX_MODE_BY_ID = {}
for _, m in ipairs(FX_MODES) do FX_MODE_BY_ID[m.id] = m end

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function alpha(col, a)
  return { col[1], col[2], col[3], a }
end

local function stageTarget()
  local cx, cy = STAGE.x + 318, STAGE.y + 188
  return {
    cx = cx, cy = cy, rx = UNIT.rx, ry = UNIT.ry,
    frontX = cx - UNIT.rx * 0.88, backX = cx + UNIT.rx * 0.88,
    top = cy - UNIT.ry, bottom = cy + UNIT.ry,
  }
end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, t = 0, active = "heavy",
    damageCause = "attack", fontStyle = "pixel", fxMode = "signature",
    eventT = 0, hp = 82, shownHp = 82, lastDamage = 48,
    didDemo = false,
  }, Room)
  Theme.load()
  return self
end

function Room:enter()
  self.title = "Combat Impact"
end

function Room:scenario(name)
  if name == "poison" then
    self.damageCause = "poison"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.dot)
  elseif name == "bleed" then
    self.damageCause = "bleed"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.heavy)
  elseif name == "burn" then
    self.damageCause = "burn"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.heavy)
  elseif name == "rot" then
    self.damageCause = "rot"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.dot)
  elseif name == "bloom" then
    self.damageCause = "poison"; self.fontStyle = "pixel"; self.fxMode = "bloom"; self:trigger(IMPACT_BY_ID.heavy)
  elseif name == "shock_pixel" then
    self.damageCause = "shock"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.heavy)
  elseif name == "bleed_operator" then
    self.damageCause = "bleed"; self.fontStyle = "operator"; self.fxMode = "signature"; self:trigger(IMPACT_BY_ID.heavy)
  else
    self.damageCause = "attack"; self.fontStyle = "pixel"; self.fxMode = "signature"; self:trigger(self:activeImpact())
  end
  self.didDemo = true
end

function Room:activeImpact()
  return IMPACT_BY_ID[self.active] or IMPACTS[1]
end

function Room:activeFamily()
  return FAMILY_BY_ID[self.damageCause] or DAMAGE_FAMILIES[1]
end

function Room:activeFont()
  return FONT_BY_ID[self.fontStyle] or FONT_STYLES[1]
end

function Room:activeFxMode()
  return FX_MODE_BY_ID[self.fxMode] or FX_MODES[1]
end

function Room:buttonRect(i)
  return { x = 96, y = 226 + (i - 1) * 54, w = 220, h = 40 }
end

function Room:stageReplayRect()
  return { x = 482, y = 528, w = 256, h = 42 }
end

function Room:familyRect(i)
  local col = (i - 1) % 2
  local row = math.floor((i - 1) / 2)
  return { x = 966 + col * 102, y = 396 + row * 32, w = 92, h = 26 }
end

function Room:fontRect(i)
  local col = (i - 1) % 2
  local row = math.floor((i - 1) / 2)
  return { x = 966 + col * 102, y = 522 + row * 25, w = 92, h = 22 }
end

function Room:modeRect(i)
  return { x = 96 + (i - 1) * 112, y = 526, w = 104, h = 28 }
end

local function emitBloomBurst(impact, cause, x, y)
  cause = cause or "attack"
  if impact.id == "block" then
    P.ring(x, y, { r0 = 8, r1 = 70, color = C.shield, style = "seal", notches = 4 })
    P.burst(x, y, {
      type = { "shard", "mote" }, count = 16, speed = { 70, 170 }, life = { 0.26, 0.56 },
      gravity = 10, tint = C.shield,
    })
    return
  end
  if cause == "attack" then
    if impact.id == "death" then P.explosion("death", x, y)
    elseif impact.id == "heavy" then P.explosion("impact", x, y)
    else
      P.burst(x, y, {
        type = impact.burst or "spark",
        count = impact.id == "dot" and 7 or 12,
        speed = { 70, impact.id == "dot" and 120 or 180 },
        life = { 0.18, impact.id == "dot" and 0.38 or 0.55 },
        gravity = 8,
      })
    end
    return
  end

  local col = Number.colOf(cause)
  local strong = impact.id == "heavy" or impact.id == "death"
  local dot = impact.id == "dot"
  local r1 = strong and 92 or (dot and 42 or 64)
  local count = strong and 22 or (dot and 8 or 14)
  local maxSpeed = strong and 250 or (dot and 105 or 170)
  local ptype = ({
    poison = { "mote", "void" },
    burn = { "ember", "flare" },
    bleed = { "blood", "chip" },
    rot = { "void", "ash" },
    shock = { "spark", "flare" },
  })[cause] or "mote"
  P.ring(x, y, {
    color = col, r0 = strong and 12 or 6, r1 = r1, life = strong and 0.42 or 0.30,
    style = cause == "shock" and "shock" or "seal", spokes = cause == "shock" and 7 or 3,
    notches = cause ~= "shock" and 5 or 0,
  })
  P.burst(x, y, {
    type = ptype, count = count, speed = { dot and 34 or 70, maxSpeed },
    life = { dot and 0.26 or 0.20, strong and 0.66 or 0.48 },
    gravity = cause == "burn" and -35 or (cause == "bleed" and 165 or 18),
    drag = dot and 2.8 or 2.2, tint = col, scale = strong and { 1.0, 1.35 } or { 0.8, 1.1 },
  })
end

local function emitSignatureBurst(impact, cause, target)
  cause = cause or "attack"
  local x, y = target.frontX, target.cy
  if impact.id == "block" then
    P.ring(x, y, { r0 = 8, r1 = 70, color = C.shield, style = "seal", notches = 4 })
    P.burst(x, y, {
      type = { "shard", "mote" }, count = 16, speed = { 70, 170 }, life = { 0.26, 0.56 },
      gravity = 10, tint = C.shield,
    })
    return
  end
  if impact.id == "death" and cause == "attack" then
    P.explosion("death", target.cx, target.cy)
    return
  end
  P.signature(cause, target.cx, target.cy, {
    target = target,
    heavy = impact.id == "heavy" or impact.id == "death",
    dot = impact.id == "dot",
  })
end

function Room:trigger(impact)
  self.active = impact.id
  self.eventT = 1.18
  self.lastDamage = impact.damage
  P.clear()
  if impact.damage > 0 then
    self.hp = math.max(0, self.hp - impact.damage)
    if self.hp == 0 or impact.id == "death" then self.hp = 82 end
  end
  local family = self:activeFamily()
  if impact.sound then SFX.play(family.sound or impact.sound) end
  if impact.trauma then Juice.addTrauma(impact.trauma) end
  if impact.freeze and impact.freeze > 0 then Juice.freeze(impact.freeze) end
  Juice.juice_up("impact.attacker", impact.id == "heavy" and 0.22 or 0.12)
  Juice.juice_up("impact.target", impact.id == "death" and 0.36 or 0.24)
  local target = stageTarget()
  if self.fxMode == "bloom" then emitBloomBurst(impact, self.damageCause, target.frontX, target.cy)
  else emitSignatureBurst(impact, self.damageCause, target) end
end

function Room:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  if not self.didDemo and self.t > 0.22 then
    self.didDemo = true
    self:trigger(self:activeImpact())
  end
  if self.eventT > 0 then self.eventT = math.max(0, self.eventT - dt) end
  self.shownHp = self.shownHp + (self.hp - self.shownHp) * math.min(1, dt * 10)
  P.update(dt * Juice.timeScale())
  for i, impact in ipairs(IMPACTS) do
    Feel.hover("impact." .. impact.id, ptIn(self.mx, self.my, self:buttonRect(i)))
  end
  for i, family in ipairs(DAMAGE_FAMILIES) do
    Feel.hover("impact.family." .. family.id, ptIn(self.mx, self.my, self:familyRect(i)))
  end
  for i, font in ipairs(FONT_STYLES) do
    Feel.hover("impact.font." .. font.id, ptIn(self.mx, self.my, self:fontRect(i)))
  end
  for i, mode in ipairs(FX_MODES) do
    Feel.hover("impact.mode." .. mode.id, ptIn(self.mx, self.my, self:modeRect(i)))
  end
  Feel.hover("impact.replay", ptIn(self.mx, self.my, self:stageReplayRect()))
end

function Room:drawControls()
  local x, y, w, h = 72, 156, 272, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("IMPACT TYPES", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Une action par famille de feedback. Les variantes fortes ne doivent pas polluer les ticks faibles.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))
  for i, impact in ipairs(IMPACTS) do
    local r = self:buttonRect(i)
    local id = "impact." .. impact.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, self.active == impact.id and "primary" or "secondary", impact.label, {
      hover = hot, feel = Feel.state(id), id = id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end
  Draw.textTrackedL("FX STYLE", x + 24, y + 348, C.gold, Theme.label(9), 1)
  for i, mode in ipairs(FX_MODES) do
    local r = self:modeRect(i)
    local hot = ptIn(self.mx, self.my, r)
    local selected = self.fxMode == mode.id
    Button.draw(r.x, r.y, r.w, r.h, selected and "eco" or "secondary", mode.label, {
      hover = hot, feel = Feel.state("impact.mode." .. mode.id), id = "impact.mode." .. mode.id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end
end

local function hpBar(x, y, w, pct)
  Draw.rect(x, y, w, 10, C.stone900, C.iron, 1)
  Draw.rect(x + 1, y + 1, math.max(0, (w - 2) * pct), 8, C.blood)
end

local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function drawOutlinedText(str, x, y, font, radius, col, alpha)
  for oy = -radius, radius do
    for ox = -radius, radius do
      if not (ox == 0 and oy == 0) and ox * ox + oy * oy <= radius * radius + 0.25 then
        Draw.text(str, x + ox, y + oy, { col[1], col[2], col[3], alpha }, font)
      end
    end
  end
end

local function drawImpactNumber(text, cx, cy, col, size, alpha, scale, cause, fontStyle)
  local font = (Number and Number.fontFor and Number.fontFor(fontStyle, size)) or Theme.displayBig(size)
  local w = Draw.textWidth(text, font)
  local h = font:getHeight()
  local iconScale = math.max(2, math.floor(size / 9 + 0.5))
  local iconW = 8 * iconScale
  love.graphics.push()
  love.graphics.translate(math.floor(cx + 0.5), math.floor(cy + 0.5))
  love.graphics.scale(scale or 1)
  if cause and text:sub(1, 1) == "-" then
    local iconY = -iconW / 2 + math.floor(iconScale * 1.25 + 0.5)
    Number.icon(cause, -w / 2 - iconW - 9, iconY, iconScale, col, alpha)
  end
  drawOutlinedText(text, -w / 2, -h / 2, font, size >= 42 and 5 or 4, { 0.018, 0.006, 0.010 }, 0.94 * alpha)
  drawOutlinedText(text, -w / 2, -h / 2, font, 1, mix(col, C.blood, 0.45), 0.78 * alpha)
  love.graphics.setBlendMode("add")
  Draw.text(text, -w / 2 - 1, -h / 2, { col[1], col[2], col[3], 0.30 * alpha }, font)
  Draw.text(text, -w / 2 + 1, -h / 2 - 1, { C.gold[1], C.gold[2], C.gold[3], 0.11 * alpha }, font)
  love.graphics.setBlendMode("alpha")
  local main = (cause == "attack" or cause == "cleave") and mix(col, C.ink, 0.06) or mix(col, C.ink, 0.12)
  Draw.text(text, -w / 2, -h / 2, { main[1], main[2], main[3], alpha }, font)
  Draw.text(text, -w / 2, -h / 2 - 1, { 1, 0.90, 0.72, 0.22 * alpha }, font)
  love.graphics.pop()
  Draw.reset()
end

function Room:drawUnit(x, y, label, side, hp, id, tint)
  local scale = Juice.scale(id)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-x, -y)
  Slot.draw(x - 34, y - 34, 68, "selected", {
    tierCol = tint or C.rot, tierBorder = side == "enemy" and C.bloodL or C.gold,
    tierGlow = side == "enemy", level = side == "enemy" and 2 or 1,
    affkeys = side == "enemy" and { "rot" } or { "burn" },
  })
  love.graphics.pop()
  Draw.reset()
  Draw.textC(label, x, y + 46, C.ink3, Theme.label(11))
  hpBar(x - 54, y + 64, 108, math.max(0, math.min(1, hp / 100)))
end

function Room:drawStage()
  local x, y, w, h = STAGE.x, STAGE.y, STAGE.w, STAGE.h
  local impact = self:activeImpact()
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("COMBAT SURFACE", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Surface statique pour juger la lisibilite des coups sans bruit de simulation.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))

  Draw.divider(x + w / 2, y + 118, w - 74, C.brass, 0.45)
  local k = self.eventT > 0 and math.min(1, self.eventT / 1.18) or 0
  local attackShift = (1 - k) * 0
  if self.eventT > 0 then attackShift = math.sin((1 - k) * math.pi) * 28 end
  local ax, ay = x + 150 + attackShift, y + 188
  local tx, ty = x + 318, y + 188
  P.draw("back")
  self:drawUnit(ax, ay, "ALLY", "ally", 100, "impact.attacker", C.poison)
  self:drawUnit(tx, ty, "ENEMY", "enemy", self.shownHp, "impact.target", C.rot)

  Draw.setColor(C.brass, 0.18)
  love.graphics.setLineWidth(2)
  love.graphics.line(ax + 48, ay, tx - 48, ty)
  love.graphics.setLineWidth(1)
  Draw.reset()

  P.draw("front")
  if self.eventT > 0 then
    local rise = (1 - k) * 42
    local cause = self.damageCause or "attack"
    local col = impact.id == "block" and C.shield or (impact.damage > 0 and Number.colOf(cause) or C.ink3)
    local text = impact.damage > 0 and ("-" .. tostring(impact.damage)) or "BLOCK"
    local size = impact.id == "heavy" and 46 or (impact.id == "death" and 52 or 34)
    local pop = 1 + math.max(0, k - 0.70) * 0.55
    drawImpactNumber(text, tx + 86, ty - 30 - rise, col, size, math.min(1, k * 1.5), pop, cause, self.fontStyle)
  end

  local r = self:stageReplayRect()
  Button.draw(r.x, r.y, r.w, r.h, "secondary", "REPLAY " .. impact.label, {
    hover = ptIn(self.mx, self.my, r), feel = Feel.state("impact.replay"), id = "impact.replay",
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
end

function Room:drawInspector()
  local x, y, w, h = 928, 156, 280, 430
  local impact = self:activeImpact()
  Panel.draw(x, y, w, h, { accent = C.brass })
  Draw.textTrackedL("CONTRACT", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textTrackedL(impact.label, x + 24, y + 50, C.ink, Theme.subhead(18), 1.4)
  Draw.textWrap(impact.visual, x + 24, y + 82, w - 48, C.ink3, Theme.body(12))

  Draw.rect(x + 24, y + 130, w - 48, 58, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("TIMING", x + 38, y + 142, C.gold, Theme.label(9), 1)
  Draw.text("hitstop " .. string.format("%.0fms", (impact.freeze or 0) * 1000), x + 38, y + 161, C.ink3, Theme.body(12))
  Draw.text("trauma " .. string.format("%.2f", impact.trauma or 0), x + 146, y + 161, C.ink4, Theme.body(12))

  Draw.rect(x + 24, y + 218, w - 48, 132, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("DAMAGE FAMILY", x + 38, y + 232, C.gold, Theme.label(9), 1)
  for i, family in ipairs(DAMAGE_FAMILIES) do
    local r = self:familyRect(i)
    local selected = self.damageCause == family.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, selected and "eco" or "secondary", family.label, {
      hover = hot, feel = Feel.state("impact.family." .. family.id), id = "impact.family." .. family.id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end

  Draw.rect(x + 24, y + 348, w - 48, 72, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("NUMBER FONT", x + 38, y + 362, C.gold, Theme.label(9), 1)
  local labels = { carved = "CINZEL", mono = "MONO", pixel = "PIXEL", operator = "OPER" }
  for i, font in ipairs(FONT_STYLES) do
    local r = self:fontRect(i)
    local selected = self.fontStyle == font.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, selected and "eco" or "secondary", labels[font.id] or font.id:upper(), {
      hover = hot, feel = Feel.state("impact.font." .. font.id), id = "impact.font." .. font.id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("COMBAT IMPACT", 72, 84, C.ink, Theme.title(24), 2)
  Draw.text("Atelier de coups lisibles: impact, chiffre, son et camera doivent rester proportionnes.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("no simulation state · presentation only", W - 72, 126, C.ink5, Theme.body(13))

  self:drawControls()
  self:drawStage()
  self:drawInspector()

  Draw.text("But: definir un vocabulaire d'impact reutilisable avant de le brancher au vrai combat.",
    72, H - 70, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  for i, impact in ipairs(IMPACTS) do
    if ptIn(mx, my, self:buttonRect(i)) then
      Feel.press("impact." .. impact.id, function() self:trigger(impact) end, { delay = 0.10 })
      return
    end
  end
  for i, family in ipairs(DAMAGE_FAMILIES) do
    if ptIn(mx, my, self:familyRect(i)) then
      Feel.press("impact.family." .. family.id, function()
        self.damageCause = family.id
        self:trigger(self:activeImpact())
      end, { delay = 0.08 })
      return
    end
  end
  for i, font in ipairs(FONT_STYLES) do
    if ptIn(mx, my, self:fontRect(i)) then
      Feel.press("impact.font." .. font.id, function()
        self.fontStyle = font.id
        self:trigger(self:activeImpact())
      end, { delay = 0.08 })
      return
    end
  end
  for i, mode in ipairs(FX_MODES) do
    if ptIn(mx, my, self:modeRect(i)) then
      Feel.press("impact.mode." .. mode.id, function()
        self.fxMode = mode.id
        self:trigger(self:activeImpact())
      end, { delay = 0.08 })
      return
    end
  end
  if ptIn(mx, my, self:stageReplayRect()) then
    local impact = self:activeImpact()
    Feel.press("impact.replay", function() self:trigger(impact) end, { delay = 0.10 })
  end
end

return Room
