-- feel-lab/rooms/particles.lua
-- Atelier dedie aux explosions et particules. Objectif: juger des presets
-- exportables dans le jeu, sans texture placeholder ni galerie brouillonne.

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

local PRESETS = {
  {
    id = "levelup", label = "LEVEL-UP SEAL", button = "LEVEL-UP",
    sound = "success", trauma = 0.36, freeze = 0.05,
    note = "Validation lisible: sceau or, runes courtes, eclats et cendre.",
    rule = "merge standard, fusion de niveau 2, validation de choix fort",
  },
  {
    id = "levelup_big", label = "ASCENSION BURST", button = "ASCENSION",
    sound = "success", trauma = 0.70, freeze = 0.10,
    note = "Payoff rare: double sceau, flash ivoire, fragments lourds.",
    rule = "niveau 3, cascade finale, moment que le joueur doit attendre",
  },
  {
    id = "seal", label = "RELIC SEAL", button = "RELIC",
    sound = "success", trauma = 0.20, freeze = 0.03,
    note = "Arcane/rot: covenant sombre, joli en capture, pas confetti.",
    rule = "choix de relique, pacte, revelation du grimoire",
  },
  {
    id = "impact", label = "IMPACT BLOOM", button = "IMPACT",
    sound = "thud", trauma = 0.44, freeze = 0.05,
    note = "Coup violent: sang bref, metal arrache, etincelles or.",
    rule = "attaque lourde ou critique, jamais sur un tick de dot",
  },
  {
    id = "death", label = "ASH DEATH", button = "DEATH",
    sound = "defeat", trauma = 0.56, freeze = 0.07,
    note = "Collapse en cendres: disparition sale, centre propre apres le burst.",
    rule = "mort d'unite, sacrifice, suppression de carte/relique",
  },
  {
    id = "unlock", label = "SLOT UNLOCK", button = "UNLOCK",
    sound = "unlock", trauma = 0.24, freeze = 0.04,
    note = "Ouverture de socket: laiton, lock brise, particules retenues.",
    rule = "nouveau slot, palier de board, recompense d'espace strategique",
  },
}

local BY_ID = {}
for _, preset in ipairs(PRESETS) do BY_ID[preset.id] = preset end

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function alpha(col, a)
  return { col[1], col[2], col[3], a }
end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, t = 0,
    active = "levelup_big", eventT = 0, didDemo = false,
    pulse = 0,
  }, Room)
  Theme.load()
  return self
end

function Room:enter()
  self.title = "Particle Forge"
end

function Room:activePreset()
  return BY_ID[self.active] or PRESETS[1]
end

function Room:presetRect(i)
  return { x = 96, y = 244 + (i - 1) * 48, w = 220, h = 38 }
end

function Room:replayRect()
  return { x = 526, y = 528, w = 256, h = 42 }
end

function Room:trigger(preset)
  preset = preset or self:activePreset()
  self.active = preset.id
  self.eventT = 1.24
  self.pulse = 1
  P.clear()
  P.explosion(preset.id, 654, 350)
  if preset.sound then SFX.play(preset.sound) end
  if preset.id == "levelup_big" then
    SFX.ladder(true); SFX.ladder(); SFX.ladder()
  end
  if preset.trauma then Juice.addTrauma(preset.trauma) end
  if preset.freeze and preset.freeze > 0 then Juice.freeze(preset.freeze) end
  Juice.juice_up("particles.stage", preset.id == "levelup_big" and 0.32 or 0.22)
  Juice.juice_up("particles.core", preset.id == "impact" and 0.28 or 0.20)
end

function Room:triggerById(id)
  self:trigger(BY_ID[id] or self:activePreset())
end

function Room:scenario(name)
  if name == "seal" then self:triggerById("seal")
  elseif name == "impact" then self:triggerById("impact")
  elseif name == "unlock" then self:triggerById("unlock")
  else self:triggerById("levelup_big") end
end

function Room:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  if not self.didDemo and self.t > 0.18 then
    self.didDemo = true
    self:trigger(self:activePreset())
  end
  self.eventT = math.max(0, self.eventT - dt)
  self.pulse = self.pulse + (0 - self.pulse) * math.min(1, dt * 4.5)
  P.update(dt * Juice.timeScale())
  for i, preset in ipairs(PRESETS) do
    Feel.hover("particles." .. preset.id, ptIn(self.mx, self.my, self:presetRect(i)))
  end
  Feel.hover("particles.replay", ptIn(self.mx, self.my, self:replayRect()))
end

function Room:drawControls()
  local x, y, w, h = 72, 156, 272, 430
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("PRESETS", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Presets exportables. Une explosion = une intention de jeu.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))
  for i, preset in ipairs(PRESETS) do
    local r = self:presetRect(i)
    local id = "particles." .. preset.id
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, self.active == preset.id and "primary" or "secondary", preset.button, {
      hover = hot, feel = Feel.state(id), id = id,
      mouse = { mx = self.mx, my = self.my }, t = self.t,
    })
  end
end

local function drawStageTarget(cx, cy, preset, pulse)
  local sc = Juice.scale("particles.stage") + pulse * 0.05
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(sc, sc)
  love.graphics.translate(-cx, -cy)

  Draw.setColor(C.brass, 0.12 + pulse * 0.18)
  love.graphics.rectangle("line", cx - 112, cy - 112, 224, 224)
  Draw.setColor(C.blood, 0.10 + pulse * 0.12)
  love.graphics.rectangle("line", cx - 92, cy - 92, 184, 184)

  Draw.setColor(C.brass, 0.20 + pulse * 0.12)
  love.graphics.setLineWidth(2)
  love.graphics.line(cx - 106, cy, cx - 50, cy)
  love.graphics.line(cx + 50, cy, cx + 106, cy)
  love.graphics.line(cx, cy - 106, cx, cy - 50)
  love.graphics.line(cx, cy + 50, cx, cy + 106)
  love.graphics.setLineWidth(1)
  Draw.reset()
  Slot.draw(cx - 34, cy - 34, 68, "selected", {
    tierCol = preset.id == "seal" and C.rot or C.gold,
    tierBorder = preset.id == "impact" and C.bloodL or C.gold,
    tierGlow = true,
    level = preset.id == "levelup_big" and 3 or 2,
    affkeys = preset.id == "death" and { "rot", "bleed" } or { "burn", "poison" },
  })

  love.graphics.pop()
  Draw.reset()
end

function Room:drawStage()
  local x, y, w, h = 376, 156, 520, 430
  local preset = self:activePreset()
  Panel.draw(x, y, w, h)
  Draw.textTrackedL("EXPLOSION SURFACE", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textWrap("Scene volontairement simple: si le burst ne semble pas precieux ici, il ne survivra pas dans Build ou Combat.",
    x + 24, y + 48, w - 48, C.ink4, Theme.body(13))

  local cx, cy = 654, 350
  Draw.divider(cx, y + 122, w - 90, C.brass, 0.35)
  drawStageTarget(cx, cy, preset, self.pulse)

  if self.eventT > 0 then
    local k = self.eventT / 1.24
    Draw.textC(preset.id == "impact" and "HIT" or "VALIDATED", cx, cy + 100 - (1 - k) * 26,
      preset.id == "impact" and C.bloodL or C.gold, Theme.label(15))
  end
  P.draw()

  local r = self:replayRect()
  Button.draw(r.x, r.y, r.w, r.h, "secondary", "REPLAY " .. preset.button, {
    hover = ptIn(self.mx, self.my, r), feel = Feel.state("particles.replay"), id = "particles.replay",
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
end

function Room:drawInspector()
  local x, y, w, h = 928, 156, 280, 430
  local preset = self:activePreset()
  Panel.draw(x, y, w, h, { accent = C.brass })
  Draw.textTrackedL("INSPECTOR", x + 24, y + 22, C.gold, Theme.subhead(13), 1.8)
  Draw.textTrackedL(preset.label, x + 24, y + 50, C.ink, Theme.subhead(18), 1.4)
  Draw.textWrap(preset.note, x + 24, y + 88, w - 48, C.ink3, Theme.body(13))

  Draw.rect(x + 24, y + 166, w - 48, 82, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("TIMING", x + 38, y + 180, C.gold, Theme.label(9), 1)
  Draw.text("hitstop " .. string.format("%.0fms", (preset.freeze or 0) * 1000), x + 38, y + 202, C.ink3, Theme.body(12))
  Draw.text("trauma " .. string.format("%.2f", preset.trauma or 0), x + 38, y + 222, C.ink4, Theme.body(12))
  Draw.text("particles " .. tostring(P.count()), x + 148, y + 222, C.ink5, Theme.body(12))

  Draw.rect(x + 24, y + 264, w - 48, 122, alpha(C.stone800, 0.34), C.iron, 1)
  Draw.textTrackedL("USE RULE", x + 38, y + 278, C.gold, Theme.label(9), 1)
  Draw.textWrap(preset.rule, x + 38, y + 300, w - 76, C.ink3, Theme.body(12))
  Draw.textTrackedL("TEXTURE CONTRACT", x + 38, y + 350, C.ink5, Theme.label(9), 1)
  Draw.textWrap("baked pixel sprites / palette locked / no generic alpha",
    x + 38, y + 368, w - 76, C.ink5, Theme.flavor(11))
end

function Room:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("PARTICLE FORGE", 72, 84, C.ink, Theme.title(24), 2)
  Draw.text("Explosions, validations et bursts de niveau: le flashy doit rester dans l'ame de The Pit.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("worked sprites · palette locked · exportable presets", W - 72, 126, C.ink5, Theme.body(13))

  self:drawControls()
  self:drawStage()
  self:drawInspector()

  Draw.text("But: definir une bibliotheque de particules reutilisable avant tout branchement dans le jeu principal.",
    72, H - 70, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  for i, preset in ipairs(PRESETS) do
    if ptIn(mx, my, self:presetRect(i)) then
      Feel.press("particles." .. preset.id, function() self:trigger(preset) end, { delay = 0.10 })
      return
    end
  end
  if ptIn(mx, my, self:replayRect()) then
    local preset = self:activePreset()
    Feel.press("particles.replay", function() self:trigger(preset) end, { delay = 0.10 })
  end
end

return Room
