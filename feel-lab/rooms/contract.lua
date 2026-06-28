-- feel-lab/rooms/contract.lua
-- Contrat operationnel du Feel Lab. Chaque action cle est jugee sur la meme
-- grille: mouvement, son, delai, payoff, echec. Aucun composant de l'ancien lab.

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

local ACTIONS = {
  {
    id = "cta", label = "FIGHT CTA", variant = "primary", sound = "press", delay = 0.80,
    visual = "press sound on pointer-down, button sink, eyes close, then blood transition",
    payoff = "combat transition starts only after the click has been heard and felt",
    fail = "disabled CTA is quiet, flat and visually locked",
    trauma = 0.18, burst = "ember",
  },
  {
    id = "buy", label = "BUY UNIT", variant = "eco", cost = 1, sound = "coin", delay = 0.12,
    visual = "gold counter punches, offer disappears, destination slot warms",
    payoff = "unit settles on board or bench with a soft place cue",
    fail = "no spend without enough gold; short error pad",
    trauma = 0.08, burst = "mote",
  },
  {
    id = "drop", label = "DROP VALID", variant = "secondary", sound = "place", delay = 0.08,
    visual = "slot glow, piece nudge, synergy edge appears if relevant",
    payoff = "piece locks to the 3x3 grid without layout shift",
    fail = "invalid drop springs back to origin",
    trauma = 0.10, burst = "shard",
  },
  {
    id = "merge", label = "MERGE", variant = "secondary", sound = "success", delay = 0.16,
    visual = "copies converge, ring expands, target punches, short hitstop",
    payoff = "level text resolves and the next strategic space opens",
    fail = "no partial merge state left behind",
    trauma = 0.42, freeze = 0.06, burst = "shard", ring = true,
  },
  {
    id = "relic", label = "RELIC PICK", variant = "secondary", sound = "success", delay = 0.16,
    visual = "card seal flashes, chosen relic settles into the run language",
    payoff = "selection is final and the build surface receives the change",
    fail = "refuse gives gold only when the UI says so explicitly",
    trauma = 0.18, burst = "mote", ring = true,
  },
  {
    id = "hit", label = "COMBAT HIT", variant = "secondary", sound = "thud", delay = 0.00,
    visual = "attacker lunge, impact flash, damage number pops then drifts",
    payoff = "HP delta is readable before the next action steals focus",
    fail = "miss or block uses a smaller, colder cue",
    trauma = 0.36, freeze = 0.045, burst = "ember",
  },
  {
    id = "unlock", label = "UNLOCK SLOT", variant = "secondary", sound = "unlock", delay = 0.14,
    visual = "locked socket opens, brass rim warms, adjacency edges breathe",
    payoff = "the player sees a new planning affordance, not just +1 slot",
    fail = "max level state is explicit and non-clickable",
    trauma = 0.12, burst = "mote", icon = "unlock",
  },
}

local ACTION_BY_ID = {}
for _, a in ipairs(ACTIONS) do ACTION_BY_ID[a.id] = a end

local CTA_TRANSITIONS = {
  { id = "blood_button", label = "BUTTON MELT", short = "MELT" },
  { id = "blood_bloom", label = "RADIAL BLOOM", short = "BLOOM" },
  { id = "blood_rain", label = "TOP DRIP", short = "DRIP" },
}

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function alpha(col, a)
  return { col[1], col[2], col[3], a }
end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, t = 0,
    active = "cta", eventT = 0, gold = 10, shownGold = 10,
    level = 1, hitValue = 42, ctaTransition = "blood_button",
  }, Room)
  Theme.load()
  return self
end

function Room:enter()
  self.title = "Feedback Contract"
end

function Room:activeAction()
  return ACTION_BY_ID[self.active] or ACTIONS[1]
end

function Room:actionRect(i)
  return { x = 96, y = 238 + (i - 1) * 42, w = 208, h = 34 }
end

function Room:stageButtonRect()
  return { x = 872, y = 520, w = 272, h = 42 }
end

function Room:transitionRect(i)
  return { x = 384 + (i - 1) * 122, y = 526, w = 112, h = 34 }
end

function Room:selectTransition(id)
  self.ctaTransition = id or self.ctaTransition
  SFX.play("tick", { vol = 0.75 })
end

function Room:startCtaTransition(sourceRect)
  self.eventT = 0.78
  Juice.addTrauma(0.28)
  Juice.freeze(0.035)
  local pitch = self.ctaTransition == "blood_button" and 0.64 or (self.ctaTransition == "blood_bloom" and 0.72 or 0.82)
  SFX.play("whoosh", { pitch = pitch, vol = 0.92 })
  if self.app and self.app.go then
    self.app:go("impact", self.ctaTransition, { originRectDesign = sourceRect })
  else
    self:payoff(self:activeAction())
  end
end

function Room:payoff(a)
  self.active = a.id
  self.eventT = 0.78
  if a.sound and a.sound ~= "press" then SFX.play(a.sound) end
  if a.id == "merge" then
    SFX.ladder(true); SFX.ladder(); SFX.ladder()
    self.level = math.min(3, self.level + 1)
  elseif a.id == "buy" then
    self.gold = math.max(0, self.gold - 1)
  elseif a.id == "hit" then
    self.hitValue = self.hitValue + 17
  elseif a.id == "unlock" then
    self.level = math.min(3, self.level + 1)
  end
  if a.trauma then Juice.addTrauma(a.trauma) end
  if a.freeze then Juice.freeze(a.freeze) end
  Juice.juice_up("contract." .. a.id, a.id == "merge" and 0.30 or 0.18)
  Juice.juice_up("contract.stage", a.id == "hit" and 0.26 or 0.18)
  local x, y = 1010, 374
  if a.id == "merge" then
    P.explosion("levelup", x, y)
  elseif a.id == "relic" then
    P.explosion("seal", x, y)
  elseif a.id == "hit" then
    P.explosion("impact", x, y)
  elseif a.id == "unlock" then
    P.explosion("unlock", x, y)
  else
    P.burst(x, y, {
      type = a.burst or "mote",
      count = 14,
      speed = { 70, 150 },
      life = { 0.28, 0.62 },
      gravity = 14,
    })
  end
end

function Room:trigger(a)
  local id = "contract." .. a.id
  self.active = a.id
  Feel.press(id, function() self:payoff(a) end, { delay = a.delay or 0.12 })
end

function Room:playStage()
  local a = self:activeAction()
  if a.id == "cta" then
    local r = self:stageButtonRect()
    Feel.press("contract.stage", function() self:startCtaTransition(r) end, { delay = a.delay or Feel.CTA_DELAY })
  else
    Feel.press("contract.stage", function() self:payoff(a) end, { delay = a.delay or 0.12 })
  end
end

function Room:scenario(name)
  local r = self:stageButtonRect()
  if name == "blood_button" then
    self.ctaTransition = "blood_button"
    self:startCtaTransition(r)
  elseif name == "blood_rain" then
    self.ctaTransition = "blood_rain"
    self:startCtaTransition(r)
  elseif name == "blood_bloom" then
    self.ctaTransition = "blood_bloom"
    self:startCtaTransition(r)
  end
end

function Room:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  P.update(dt * Juice.timeScale())
  if self.eventT > 0 then self.eventT = math.max(0, self.eventT - dt) end
  self.shownGold = self.shownGold + (self.gold - self.shownGold) * math.min(1, dt * 9)
  for i, a in ipairs(ACTIONS) do
    Feel.hover("contract." .. a.id, ptIn(self.mx, self.my, self:actionRect(i)))
  end
  if self:activeAction().id == "cta" then
    for i, tr in ipairs(CTA_TRANSITIONS) do
      Feel.hover("contract.transition." .. tr.id, ptIn(self.mx, self.my, self:transitionRect(i)))
    end
  end
  Feel.hover("contract.stage", ptIn(self.mx, self.my, self:stageButtonRect()))
end

local function metric(x, y, label, value, col)
  Draw.textTrackedL(label:upper(), x, y, C.ink5, Theme.label(9), 1)
  Draw.textTrackedL(tostring(value):upper(), x, y + 16, col or C.ink2, Theme.label(13), 1.1)
end

function Room:drawActionList()
  local x, y, w, h = 72, 156, 260, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("ACTIONS", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.text("Selectionne l'action a auditer.", x + 24, y + 50, C.ink4, Theme.body(13))
  for i, a in ipairs(ACTIONS) do
    local r = self:actionRect(i)
    local id = "contract." .. a.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, a.variant, a.label, {
      hover = hot, feel = Feel.state(id), id = id,
      mouse = { mx = self.mx, my = self.my }, t = self.t, cost = a.cost,
    })
  end
end

function Room:drawDetailRow(x, y, w, label, value, col)
  Draw.rect(x, y, w, 56, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL(label:upper(), x + 14, y + 10, col or C.gold, Theme.label(9), 1)
  Draw.textWrap(value, x + 112, y + 9, w - 126, C.ink3, Theme.body(12))
end

function Room:drawContractDetail()
  local x, y, w, h = 360, 156, 420, 430
  local a = self:activeAction()
  Panel.draw(x, y, w, h, { accent = C.brass })
  Draw.textTrackedL("CONTRACT", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textTrackedL(a.label, x + 24, y + 50, C.ink, Theme.subhead(21), 1.5)
  Draw.text("sound: " .. (a.sound or "-") .. "   delay: " .. string.format("%.2fs", a.delay or 0),
    x + 24, y + 84, C.ink5, Theme.label(11))

  local yy = y + 120
  self:drawDetailRow(x + 24, yy, w - 48, "visual", a.visual, C.gold); yy = yy + 66
  self:drawDetailRow(x + 24, yy, w - 48, "payoff", a.payoff, C.rot); yy = yy + 66
  self:drawDetailRow(x + 24, yy, w - 48, "failure", a.fail, C.ink4); yy = yy + 66

  if a.id == "cta" then
    Draw.textTrackedL("TRANSITION", x + 24, yy + 10, C.gold, Theme.label(9), 1.1)
    Draw.text("press cue now, scene later", x + 158, yy + 10, C.ink5, Theme.label(10))
    for i, tr in ipairs(CTA_TRANSITIONS) do
      local r = self:transitionRect(i)
      local id = "contract.transition." .. tr.id
      local hot = ptIn(self.mx, self.my, r)
      Button.draw(r.x, r.y, r.w, r.h, self.ctaTransition == tr.id and "primary" or "secondary", tr.short, {
        hover = hot, feel = Feel.state(id), id = id,
        mouse = { mx = self.mx, my = self.my }, t = self.t,
      })
    end
  else
    Draw.textTrackedL("VALIDATION", x + 24, yy + 10, C.gold, Theme.label(9), 1.1)
    Draw.textWrap("Une capture doit rester propre. En mouvement, l'action doit etre comprise sans lire cette fiche.",
      x + 24, yy + 30, w - 48, C.ink4, Theme.flavor(13))
  end
end

function Room:drawBoard(x, y)
  local startX, startY, step, s = x + 90, y + 132, 68, 56
  for row = 0, 2 do
    for col = 0, 2 do
      local idx = row * 3 + col + 1
      local state = "empty"
      if idx == 9 and self.level < 3 then state = "locked" end
      if idx == 5 then state = "selected" end
      if idx == 2 or idx == 4 then state = "neighbor" end
      Slot.draw(startX + col * step, startY + row * step, s, state, {
        tierCol = C.rot, tierBorder = C.gold, tierGlow = idx == 5,
        level = idx == 5 and self.level or nil,
        affkeys = idx == 5 and { "poison", "burn" } or nil,
      })
    end
  end
  Slot.edge(startX + s / 2 + step, startY + s / 2, startX + s / 2 + step, startY + s / 2 + step, true, 2)
  Slot.edge(startX + s / 2, startY + s / 2 + step, startX + s / 2 + step, startY + s / 2 + step, true, 2)
  return startX + step + s / 2, startY + step + s / 2
end

function Room:drawStage()
  local x, y, w, h = 808, 156, 400, 430
  local a = self:activeAction()
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("LIVE SURFACE", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Mini surface Build: HUD, plateau, feedback et bouton de relecture.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))

  metric(x + 24, y + 88, "gold", string.format("%02d", math.floor(self.shownGold + 0.5)), C.gold)
  metric(x + 102, y + 88, "level", "LV" .. self.level, C.rot)
  metric(x + 188, y + 88, "state", self.eventT > 0 and "armed" or "idle", self.eventT > 0 and C.ember or C.ink4)
  metric(x + 292, y + 88, "action", a.id, C.ink2)

  local cx, cy = self:drawBoard(x, y)
  local sc = Juice.scale("contract.stage")
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(sc, sc)
  Draw.textC("LV" .. self.level, 0, -74, C.gold, Theme.label(16))
  if self.eventT > 0 then
    Draw.textC(tostring(self.hitValue), 0, 72, a.id == "hit" and C.bloodL or C.ink3, Theme.displayBig(28))
  end
  love.graphics.pop()
  Draw.reset()
  P.draw()

  local r = self:stageButtonRect()
  local variant = a.id == "cta" and "primary" or (a.variant == "eco" and "eco" or "secondary")
  Button.draw(r.x, r.y, r.w, r.h, variant, "PLAY " .. a.label, {
    hover = ptIn(self.mx, self.my, r), feel = Feel.state("contract.stage"), id = "contract.stage",
    mouse = { mx = self.mx, my = self.my }, t = self.t, cost = a.cost,
  })
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("FEEDBACK CONTRACT", 72, 84, C.ink, Theme.title(24), 2)
  Draw.text("Une action n'est validee que si le mouvement, le son, le delai et le payoff racontent la meme chose.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("capture first · motion second · port to game last", W - 72, 126, C.ink5, Theme.body(13))

  self:drawActionList()
  self:drawContractDetail()
  self:drawStage()

  Draw.text("Cette page remplace les brainstorms: un effet non beau ici ne doit pas arriver dans Build, Combat ou Grimoire.",
    72, H - 70, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  for i, a in ipairs(ACTIONS) do
    if ptIn(mx, my, self:actionRect(i)) then self:trigger(a); return end
  end
  if self:activeAction().id == "cta" then
    for i, tr in ipairs(CTA_TRANSITIONS) do
      if ptIn(mx, my, self:transitionRect(i)) then
        Feel.press("contract.transition." .. tr.id, function() self:selectTransition(tr.id) end, { delay = 0.08 })
        return
      end
    end
  end
  if ptIn(mx, my, self:stageButtonRect()) then
    self:playStage()
  end
end

return Room
