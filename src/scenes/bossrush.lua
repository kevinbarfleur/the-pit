-- src/scenes/bossrush.lua
-- Premier flux produit PvE post-victoire : on envoie le build final dans le
-- runner bossrush deterministe, puis on affiche un resultat de score lisible.
-- La scene reste RENDER/UI ; la simulation PvE vit dans src/lab/bossrush.lua.

local Bossrush = require("src.lab.bossrush")
local Abominations = require("src.data.abominations")
local Ambient = require("src.fx.ambient")
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Banner = require("src.ui.banner")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Dividers = require("src.ui.dividers")
local Feel = require("src.ui.feel")
local Overlay = require("src.ui.overlay")
local SFX = require("src.audio.sfx")
local T = require("src.core.i18n").t

local Scene = {}
Scene.__index = Scene

local PANEL_W, PANEL_H = 760, 288
local BTN_W, BTN_H, BTN_GAP = 250, 52, 22
local CAUSE_ORDER = { "attack", "cleave", "shock", "burn", "poison", "rot", "bleed", "thorns", "reflect", "fatigue" }

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function scoreSeed(run, payload)
  if payload and payload.seed then return payload.seed end
  local base = run and run.seed or 0
  local wins = run and run.wins or 0
  local losses = run and run.losses or 0
  local round = run and run.round or 0
  return math.floor(base + wins * 1009 + losses * 917 + round * 53 + 4049)
end

local function bossKey(run, seed, payload)
  if payload and payload.bossKey then return payload.bossKey end
  local order = Abominations.order
  if not order or #order == 0 then return nil end
  local basis = seed + ((run and run.wins or 0) * 7) + ((run and run.losses or 0) * 13)
  return order[1 + (basis % #order)]
end

local function buildLeftComp(host, payload)
  if payload and payload.left then return payload.left end
  local build = (payload and payload.build) or (host and host.build)
  if not (build and build.buildLeftComp) then return {} end
  local left = build:buildLeftComp()
  local run = (payload and payload.run) or (host and host.run)
  if run and run.applyRelics then run:applyRelics(left) end
  return left
end

local function recordResult(run, result)
  if not (run and result) then return end
  run.bossrushResults = run.bossrushResults or {}
  run.bossrushResults[#run.bossrushResults + 1] = {
    seed = result.seed,
    boss_key = result.boss_key,
    boss_name = result.boss_name,
    score_damage = result.boss_score_damage or 0,
    score_dps = result.boss_score_dps or 0,
    survived = result.survived and true or false,
    survived_score_window = result.survived_score_window and true or false,
    cleared_blockers = result.cleared_blockers and true or false,
    boss_killed = result.boss_killed and true or false,
    damage_by_cause = result.damage_by_cause or {},
    score_damage_by_cause = result.score_damage_by_cause or {},
  }
end

local function computeResult(host, payload)
  payload = payload or {}
  local run = payload.run or (host and host.run)
  local seed = scoreSeed(run, payload)
  local key = bossKey(run, seed, payload)
  local left = buildLeftComp(host, payload)
  if not key or #left == 0 then
    return {
      seed = seed,
      boss_key = key or "none",
      boss_name = T("bossrush.no_boss"),
      cleared_blockers = false,
      survived = false,
      survived_score_window = false,
      boss_killed = false,
      score_ticks = 0,
      score_seconds = 0,
      boss_damage = 0,
      boss_score_damage = 0,
      boss_score_dps = 0,
      boss_hp_remaining = 0,
      boss_hp_max = 0,
      boss_hp_frac = 1,
      damage_by_cause = {},
      score_damage_by_cause = {},
    }
  end
  return Bossrush.run(left, key, seed, {
    hpMult = payload.hpMult or 2,
    cooldownMult = payload.cooldownMult or 0.5,
    scoreTicks = payload.scoreTicks,
    tickCap = payload.tickCap,
    pacingProfile = payload.pacingProfile,
  })
end

function Scene.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local result = computeResult(host, payload)
  recordResult(payload.run or (host and host.run), result)
  local self = setmetatable({
    vw = vw,
    vh = vh,
    t = 0,
    palette = palette,
    host = host,
    payload = payload,
    result = result,
    daChrome = true,
    titleKey = "scene.bossrush",
    hintKey = "ui.hint_bossrush",
    ambient = Ambient.new((result.seed or 0) + 77),
    mx = -100,
    my = -100,
    shownScore = payload.instantScore and (result.boss_score_damage or 0) or 0,
    scorePlayed = false,
  }, Scene)
  local cx = math.floor(Draw.W / 2)
  self.panel = { x = math.floor(cx - PANEL_W / 2), y = 238, w = PANEL_W, h = PANEL_H }
  self.btnNew = { x = math.floor(cx - BTN_W - BTN_GAP / 2), y = 574, w = BTN_W, h = BTN_H }
  self.btnMenu = { x = math.floor(cx + BTN_GAP / 2), y = 574, w = BTN_W, h = BTN_H }
  Feel.reset()
  return self
end

function Scene:update(frameDt)
  self.t = self.t + (frameDt or 1)
  self._anim = Overlay.advance(self._anim, (frameDt or 1) / 60)
  self.ambient:update(frameDt)
  Feel.update(frameDt)
  Feel.hover("bossrush.new", ptIn(self.mx, self.my, self.btnNew))
  Feel.hover("bossrush.menu", ptIn(self.mx, self.my, self.btnMenu))

  local target = self.result and self.result.boss_score_damage or 0
  local dt = (frameDt or 1) / 60
  local k = 1 - math.exp(-dt / 0.42)
  self.shownScore = self.shownScore + (target - self.shownScore) * k
  if math.abs(self.shownScore - target) < 1 then self.shownScore = target end
end

function Scene:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("combat")
  Draw.finish()
end

function Scene:drawWorld() end

local function yn(v)
  return T(v and "bossrush.yes" or "bossrush.no")
end

local function drawMetric(x, y, labelKey, value)
  local C = Theme.c
  local lf = Theme.labelSmall(9)
  local vf = Theme.value(15)
  Draw.textTrackedC(T(labelKey), x, y, C.ink5, lf, 1.2)
  Draw.textC(value, x, y + 22, C.ink, vf)
end

local function causeLabel(cause)
  local key = "combat.cause." .. tostring(cause or "attack")
  local v = T(key)
  if v == key then return tostring(cause or "attack") end
  return v
end

function Scene:drawOverlay(view)
  local C = Theme.c
  local r = self.result or {}
  local tt = self.t / 60
  if not self.scorePlayed then
    self.scorePlayed = true
    SFX.play("success")
  end

  Draw.begin(view)
  local anim = self._anim or 1
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.015, 0.01, 0.025, 0.58 * anim })
  Overlay.pushContent(Draw.W / 2, Draw.H / 2, anim)

  local scoreText = T("bossrush.score", { score = math.floor(self.shownScore + 0.5) })
  Banner.draw(170, 46, 940, "ascension", T("bossrush.word"), {
    subtitle = r.boss_name or T("bossrush.no_boss"),
    score = scoreText,
    hint = T("bossrush.kicker"),
    t = tt,
    h = 174,
  })

  local p = self.panel
  Panel.draw(p.x, p.y, p.w, p.h, { solid = true, accent = C.brass })
  Dividers.text(p.x + p.w / 2, p.y + 22, p.w - 72, T("bossrush.result_title"))

  local score = math.floor((r.boss_score_damage or 0) + 0.5)
  local dps = math.floor((r.boss_score_dps or 0) * 10 + 0.5) / 10
  drawMetric(p.x + 116, p.y + 70, "bossrush.metric_damage", tostring(score))
  drawMetric(p.x + 292, p.y + 70, "bossrush.metric_dps", tostring(dps))
  drawMetric(p.x + 468, p.y + 70, "bossrush.metric_window", yn(r.survived_score_window))
  drawMetric(p.x + 644, p.y + 70, "bossrush.metric_survived", yn(r.survived))

  local hpFrac = math.max(0, math.min(1, r.boss_hp_frac or 0))
  local barX, barY, barW, barH = p.x + 76, p.y + 142, p.w - 152, 14
  Draw.text(T("bossrush.boss_hp"), barX, barY - 22, C.ink4, Theme.labelSmall(9))
  Draw.bar(barX, barY, barW, barH, 1 - hpFrac, C.bloodL, C.stone900, C.iron)
  Draw.textC(T("bossrush.hp_left", {
    hp = math.floor((r.boss_hp_remaining or 0) + 0.5),
    max = math.floor((r.boss_hp_max or 0) + 0.5),
  }), barX + barW / 2, barY + 22, C.ink3, Theme.labelSmall(9))

  local cy = p.y + 206
  Draw.text(T("bossrush.causes"), p.x + 76, cy, C.ink4, Theme.labelSmall(9))
  local map = r.score_damage_by_cause or {}
  local x = p.x + 76
  local wrote = 0
  for _, cause in ipairs(CAUSE_ORDER) do
    local amount = map[cause] or 0
    if amount > 0 and wrote < 4 then
      local label = causeLabel(cause)
      Draw.text(label .. " " .. math.floor(amount + 0.5), x, cy + 24, C.ink2, Theme.labelSmall(10))
      x = x + 154
      wrote = wrote + 1
    end
  end
  if wrote == 0 then
    Draw.text(T("bossrush.no_score_causes"), x, cy + 24, C.ink5, Theme.labelSmall(10))
  end

  Button.draw(self.btnNew.x, self.btnNew.y, self.btnNew.w, self.btnNew.h, "primary", T("bossrush.new_run"), {
    hover = ptIn(self.mx, self.my, self.btnNew),
    feel = Feel.state("bossrush.new"),
    id = "bossrush.new",
    mouse = { mx = self.mx, my = self.my },
    t = tt,
  })
  Button.draw(self.btnMenu.x, self.btnMenu.y, self.btnMenu.w, self.btnMenu.h, "secondary", T("bossrush.menu"), {
    hover = ptIn(self.mx, self.my, self.btnMenu),
    feel = Feel.state("bossrush.menu"),
    id = "bossrush.menu",
  })

  Overlay.popContent()
  if anim < 1 then Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, (1 - anim) * 0.5 }) end
  Draw.finish()
end

function Scene:mousemoved(vx, vy)
  self.mx, self.my = vx * 4, vy * 4
end

function Scene:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx * 4, vy * 4
  if ptIn(self.mx, self.my, self.btnNew) then
    Feel.press("bossrush.new", function() self.host.newRun() end, { delay = Feel.CTA_DELAY })
  elseif ptIn(self.mx, self.my, self.btnMenu) then
    Feel.press("bossrush.menu", function()
      if self.host.abandonRun then self.host.abandonRun()
      elseif self.host.goto then self.host.goto("menu") end
    end)
  end
end

function Scene:mousereleased() end

function Scene:keypressed(key)
  if key == "r" then self.host.newRun()
  elseif key == "m" then
    if self.host.abandonRun then self.host.abandonRun()
    elseif self.host.goto then self.host.goto("menu") end
  end
end

return Scene
