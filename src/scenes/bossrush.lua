-- src/scenes/bossrush.lua
-- Flux PvE post-victoire : le build final affronte une abomination EN LIVE
-- (boss + trois generaux). Une fois les generaux brises, une fenetre de
-- scoring compte les degats au boss, puis seulement ensuite le resultat est
-- affiche. Le runner lab reste disponible pour les outils/snapshots instantanes.

local Bossrush = require("src.lab.bossrush")
local Abominations = require("src.data.abominations")
local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local AbominationSprite = require("src.render.abomination_sprite")
local Pacing = require("src.run.pacing")
local Ambient = require("src.fx.ambient")
local NightmareBG = require("src.fx.nightmare_bg")
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Banner = require("src.ui.banner")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Dividers = require("src.ui.dividers")
local Feel = require("src.ui.feel")
local Juice = require("src.ui.juice")
local Overlay = require("src.ui.overlay")
local SFX = require("src.audio.sfx")
local I18n = require("src.core.i18n")
local T = I18n.t

local Scene = {}
Scene.__index = Scene

local PANEL_W, PANEL_H = 1080, 390
local BTN_W, BTN_H, BTN_GAP = 250, 52, 22
local RESULT_W, RESULT_H = 1040, 536
local RESULT_CARD_H = 292
local LIVE_TOP_H = 92
local LIVE_BOTTOM_Y = 612
local CAUSE_ORDER = { "attack", "cleave", "shock", "burn", "poison", "rot", "bleed", "thorns", "reflect", "fatigue" }
local NO_FATIGUE = { start = 999999, base = 0, ramp = 0 }

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function colorFromAccent(hex, fallback)
  if type(hex) ~= "string" then return fallback end
  local raw = hex:match("^#?([%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F])$")
  if not raw then return fallback end
  local n = tonumber(raw, 16)
  if not n then return fallback end
  return Theme.hex(n)
end

local function abomForResult(result)
  return result and Abominations.byKey and Abominations.byKey[result.boss_key] or nil
end

local function bossDisplayName(result)
  if not result then return T("bossrush.no_boss") end
  local key = "bossrush.abomination." .. tostring(result.boss_key or "") .. ".name"
  if I18n.has and I18n.has(key) then return T(key) end
  return result.boss_name or T("bossrush.no_boss")
end

local function hasReturnPayload(self)
  return self and self.payload and type(self.payload.onFinish) == "function"
end

local function finishPrimary(self)
  if hasReturnPayload(self) then self.payload.onFinish(self.result)
  else self.host.newRun() end
end

local function finishSecondary(self)
  if self.host.abandonRun then self.host.abandonRun()
  elseif self.host.goto then self.host.goto("menu") end
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

local function countAlive(arena, pred)
  local n = 0
  for _, u in ipairs((arena and arena.units) or {}) do
    if u.alive and pred(u) then n = n + 1 end
  end
  return n
end

local function bossUnit(arena)
  for _, u in ipairs((arena and arena.units) or {}) do
    if u.spec and u.spec.role == "boss" then return u end
  end
  return nil
end

local function sideAlive(arena, team)
  return countAlive(arena, function(u) return u.team == team and not u.isCommander end)
end

local function rightBlockersAlive(arena)
  return countAlive(arena, function(u)
    return u.team == "right" and not u.isCommander and not (u.spec and u.spec.role == "boss")
  end)
end

local function generalStates(arena, abom)
  local out = {}
  for i, spec in ipairs((abom and abom.generals) or {}) do
    local found = nil
    for _, u in ipairs((arena and arena.units) or {}) do
      if u.team == "right" and u.spec and u.spec.role == "general"
        and (u.id == spec.id or u.spec.id == spec.id) then
        found = u
        break
      end
    end
    out[i] = {
      id = spec.id,
      alive = found and found.alive or false,
      hp = found and found.hp or 0,
      maxHp = found and found.maxHp or (spec.hp or 0),
    }
  end
  return out
end

local function sortedCauseMap(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = v end
  return out
end

local function recordResult(run, result)
  if not (run and result) then return end
  run.bossrushResults = run.bossrushResults or {}
  run.bossrushResults[#run.bossrushResults + 1] = {
    seed = result.seed,
    boss_key = result.boss_key,
    boss_name = result.boss_name,
    generals = result.generals or {},
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
      generals = {},
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
  local run = payload.run or (host and host.run)
  local seed = scoreSeed(run, payload)
  local key = bossKey(run, seed, payload)
  local left = buildLeftComp(host, payload)
  local abom = key and Abominations.byKey[key] or nil
  local instant = payload.instantScore and true or false
  local result = nil
  local arena, renderer = nil, nil
  if instant then
    result = computeResult(host, payload)
    recordResult(run, result)
  elseif not key or not abom or #left == 0 then
    result = {
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
      generals = {},
      damage_by_cause = {},
      score_damage_by_cause = {},
    }
    recordResult(run, result)
  else
    local pacing = Pacing.arenaOptions(payload.pacingProfile)
    pacing.hpMult = (payload.hpMult ~= nil) and payload.hpMult or 2
    pacing.cooldownMult = (payload.cooldownMult ~= nil) and payload.cooldownMult or 0.5
    pacing.fatigue = payload.fatigue or NO_FATIGUE
    arena = Arena.new({
      left = left,
      right = Bossrush.toComp(abom, 1),
      autoReset = false,
      seed = seed,
      hpMult = pacing.hpMult,
      cooldownMult = pacing.cooldownMult,
      fatigue = pacing.fatigue,
    })
    renderer = ArenaDraw.new(arena, palette)
  end
  local self = setmetatable({
    vw = vw,
    vh = vh,
    t = 0,
    palette = palette,
    host = host,
    payload = payload,
    run = run,
    bossKey = key,
    abom = abom,
    left = left,
    arena = arena,
    renderer = renderer,
    result = result,
    paused = false,
    speed = 1,
    skipping = false,
    scoreTicks = payload.scoreTicks or Bossrush.DEFAULT_SCORE_TICKS,
    tickCap = payload.tickCap or Bossrush.DEFAULT_TICK_CAP,
    clearTicks = nil,
    scoreStartTick = nil,
    scoreElapsed = 0,
    scoreActive = false,
    bossDamage = 0,
    scoreDamage = 0,
    damageByCause = {},
    scoreDamageByCause = {},
    daChrome = true,
    nativeWorld = true,
    titleKey = "scene.bossrush",
    hintKey = "ui.hint_bossrush",
    ambient = Ambient.new(((result and result.seed) or seed or 0) + 77),
    nightmareBg = NightmareBG.new(seed + 77),
    mx = -100,
    my = -100,
    shownScore = 0,
    liveShownScore = 0,
    scorePlayed = false,
    scoreFxMilestone = 0,
    scoreFxBucket = 0,
    liveScoreFxBucket = 0,
  }, Scene)
  local cx = math.floor(Draw.W / 2)
  self.panel = { x = math.floor(cx - PANEL_W / 2), y = 222, w = PANEL_W, h = PANEL_H }
  self.btnNew = { x = math.floor(cx - BTN_W - BTN_GAP / 2), y = 632, w = BTN_W, h = BTN_H }
  self.btnMenu = { x = math.floor(cx + BTN_GAP / 2), y = 632, w = BTN_W, h = BTN_H }
  if self.arena then
    self.arena.bus:on("damage", function(ev)
      local tgt = ev and ev.target
      if tgt and tgt.spec and tgt.spec.role == "boss" and ev.hp and ev.hp > 0 then
        local cause = ev.cause or "attack"
        self.bossDamage = self.bossDamage + ev.hp
        self.damageByCause[cause] = (self.damageByCause[cause] or 0) + ev.hp
        if self.scoreActive then
          self.scoreDamage = self.scoreDamage + ev.hp
          self.scoreDamageByCause[cause] = (self.scoreDamageByCause[cause] or 0) + ev.hp
          self:_onScoreDamage(ev.hp, self.scoreDamage, cause)
        end
      end
    end)
  end
  Feel.reset()
  return self
end

function Scene:_liveSnapshot()
  local boss = bossUnit(self.arena)
  local bossHp, bossMax = boss and boss.hp or 0, boss and boss.maxHp or 0
  local scoreSeconds = (self.scoreElapsed or 0) / 60
  return {
    boss_key = self.bossKey,
    boss_name = self.abom and self.abom.name,
    theme = self.abom and self.abom.theme,
    seed = self.payload and self.payload.seed or 0,
    cleared_blockers = self.clearTicks ~= nil,
    clear_ticks = self.clearTicks or 0,
    clear_seconds = self.clearTicks and (self.clearTicks / 60) or 0,
    survived = sideAlive(self.arena, "left") > 0,
    survived_score_window = sideAlive(self.arena, "left") > 0 and self.clearTicks ~= nil and self.scoreElapsed >= self.scoreTicks,
    total_ticks = self.t or 0,
    total_seconds = (self.t or 0) / 60,
    score_ticks = self.scoreElapsed or 0,
    score_seconds = scoreSeconds,
    boss_damage = self.bossDamage or 0,
    boss_score_damage = self.scoreDamage or 0,
    boss_score_dps = (scoreSeconds > 0) and ((self.scoreDamage or 0) / scoreSeconds) or 0,
    boss_hp_remaining = bossHp,
    boss_hp_max = bossMax,
    boss_hp_frac = (bossMax > 0) and (bossHp / bossMax) or 0,
    boss_killed = boss ~= nil and not boss.alive,
    generals = generalStates(self.arena, self.abom),
    damage_by_cause = sortedCauseMap(self.damageByCause),
    score_damage_by_cause = sortedCauseMap(self.scoreDamageByCause),
  }
end

function Scene:_finishLive()
  if self.result then return end
  self.result = self:_liveSnapshot()
  recordResult(self.run, self.result)
  self.skipping = false
  self.shownScore = 0
  self.liveShownScore = self.scoreDamage or 0
  self.scorePlayed = false
  self.scoreFxMilestone = 0
  self.scoreFxBucket = 0
  self.liveScoreFxBucket = 0
  self._anim = nil
end

function Scene:_onScoreDamage(gain, total, _cause)
  gain = gain or 0
  total = total or 0
  local boss = bossUnit(self.arena)
  local maxHp = (boss and boss.maxHp) or (self.abom and self.abom.boss and self.abom.boss.hp) or 0
  local bucketSize = math.max(70, maxHp / 32)
  local bucket = math.floor(total / bucketSize)
  if bucket <= (self.liveScoreFxBucket or 0) then return end
  self.liveScoreFxBucket = bucket
  if bucket == 1 then SFX.ladder(true) else SFX.ladder(false) end
  local weight = math.min(1, gain / 120)
  Juice.juice_up("bossrush.live_score", 0.09 + 0.12 * weight)
  Juice.juice_up("bossrush.live_meter", 0.06 + 0.06 * weight)
  Juice.addTrauma(0.010 + 0.025 * weight)
  if gain >= 80 then
    SFX.play("thud", { vol = 0.28, pitch = 0.86 })
    Juice.freeze(0.012)
  end
end

function Scene:_updateLiveScore(frameDt)
  local target = self.scoreDamage or 0
  local dt = (frameDt or 1) / 60
  local k = 1 - math.exp(-dt / 0.18)
  self.liveShownScore = (self.liveShownScore or 0) + (target - (self.liveShownScore or 0)) * k
  if math.abs((self.liveShownScore or 0) - target) < 0.7 then self.liveShownScore = target end
end

function Scene:_step(frameDt)
  self.t = self.t + frameDt
  self.scoreActive = self.scoreStartTick ~= nil and self.t >= self.scoreStartTick
  self.arena:update(frameDt, self.t)
  self.renderer:update(frameDt, self.t)

  if not self.clearTicks and rightBlockersAlive(self.arena) == 0 then
    self.clearTicks = self.t
    self.scoreStartTick = self.t + 1
    SFX.ladder(true)
    SFX.play("success", { vol = 0.42, pitch = 0.82 })
    Juice.juice_up("bossrush.phase", 0.14)
    Juice.juice_up("bossrush.live_score", 0.18)
    Juice.juice_up("bossrush.live_meter", 0.12)
    Juice.addTrauma(0.018)
  elseif self.scoreStartTick and self.t >= self.scoreStartTick then
    self.scoreElapsed = math.min(self.scoreTicks, self.scoreElapsed + frameDt)
  end

  local boss = bossUnit(self.arena)
  local leftAlive = sideAlive(self.arena, "left")
  if not boss or not boss.alive or leftAlive == 0 or self.scoreElapsed >= self.scoreTicks
    or self.t >= self.tickCap or self.arena.over then
    self:_finishLive()
  end
end

function Scene:_updateResult(frameDt)
  if not self.scorePlayed then
    self.scorePlayed = true
    SFX.ladder(true)
    SFX.play("success")
    Juice.juice_up("bossrush.phase", 0.12)
    Juice.juice_up("bossrush.score", 0.12)
  end

  local target = self.result and self.result.boss_score_damage or 0
  local dt = (frameDt or 1) / 60
  local k = 1 - math.exp(-dt / 0.42)
  local before = self.shownScore or 0
  self.shownScore = self.shownScore + (target - self.shownScore) * k
  if math.abs(self.shownScore - target) < 1 then self.shownScore = target end

  if target > 0 then
    local frac = clamp01(self.shownScore / target)
    while self.scoreFxMilestone < 4 and frac >= (self.scoreFxMilestone + 1) * 0.25 do
      self.scoreFxMilestone = self.scoreFxMilestone + 1
      SFX.ladder(self.scoreFxMilestone == 1)
      Juice.juice_up("bossrush.score", 0.14 + 0.04 * self.scoreFxMilestone)
      Juice.juice_up("bossrush.phase", 0.08)
      Juice.addTrauma(0.018 + 0.008 * self.scoreFxMilestone)
      if self.scoreFxMilestone == 4 then
        SFX.play("thud", { vol = 0.42, pitch = 0.94 })
        Juice.freeze(0.025)
      end
    end

    local bucketSize = math.max(250, target / 12)
    local bucket = math.floor(self.shownScore / bucketSize)
    if bucket > self.scoreFxBucket and self.shownScore > before + 1 then
      self.scoreFxBucket = bucket
      Juice.juice_up("bossrush.score_tick", 0.05)
    end
  end
end

function Scene:update(frameDt)
  frameDt = frameDt or 1
  self._anim = Overlay.advance(self._anim, (frameDt or 1) / 60)
  Feel.update(frameDt)
  if self.nightmareBg then self.nightmareBg:update(frameDt / 60) end
  self.ambient:update(frameDt)
  Feel.hover("bossrush.new", ptIn(self.mx, self.my, self.btnNew))
  Feel.hover("bossrush.menu", ptIn(self.mx, self.my, self.btnMenu))
  Feel.hover("bossrush.pause", ptIn(self.mx, self.my, self._btnPause))
  Feel.hover("bossrush.spd1", ptIn(self.mx, self.my, self._btnSpd1))
  Feel.hover("bossrush.spd2", ptIn(self.mx, self.my, self._btnSpd2))
  Feel.hover("bossrush.skip", ptIn(self.mx, self.my, self._btnSkip))

  if self.result then
    self:_updateResult(frameDt)
    return
  end

  self:_updateLiveScore(frameDt)
  if self.paused then return end
  local steps = self.skipping and 240 or (self.speed or 1)
  for _ = 1, steps do
    self:_step(frameDt)
    if self.result then break end
  end
  if self.renderer then self.renderer:flushAudio() end
end

function Scene:drawBack(view)
  Draw.begin(view)
  if self.nightmareBg then self.nightmareBg:draw(0, 0, Draw.W, Draw.H)
  else self.ambient:draw("combat") end
  Draw.finish()
end

function Scene:drawWorld()
  if self.renderer and not self.result then self.renderer:draw(false) end
end

local function yn(v)
  return T(v and "bossrush.yes" or "bossrush.no")
end

local function int(v)
  return tostring(math.floor((v or 0) + 0.5))
end

local function oneDecimal(v)
  return tostring(math.floor((v or 0) * 10 + 0.5) / 10)
end

local function drawMetric(x, y, labelKey, value)
  local C = Theme.c
  local lf = Theme.labelSmall(9)
  local vf = Theme.value(15)
  Draw.textTrackedC(T(labelKey), x, y, C.ink5, lf, 1.2)
  Draw.textC(value, x, y + 22, C.ink, vf)
end

local function drawMiniMetric(x, y, w, labelKey, value, accent)
  local C = Theme.c
  Draw.rect(x, y, w, 42, { C.stone900[1], C.stone900[2], C.stone900[3], 0.62 }, C.brassD, 1)
  Draw.rect(x, y, 3, 42, accent or C.brassS)
  Draw.textTrackedL(T(labelKey), x + 12, y + 7, C.ink5, Theme.labelSmall(8), 1.0)
  Draw.textR(value, x + w - 12, y + 18, C.ink, Theme.value(12))
end

local function effectColor(op)
  local C = Theme.c
  if op == "burn" or op == "spread_burn_on_death" then return C.burn end
  if op == "poison" then return C.poison end
  if op == "bleed" then return C.bleed end
  if op == "rot" then return C.rot end
  if op == "shock" then return C.shock end
  if op == "thorns" or op == "reflect" then return C.bloodL end
  if op == "regen" or op == "lifesteal" then return C.regen end
  if op == "execute" or op == "percent_hp_strike" then return C.bloodL end
  if op == "grant_vuln" then return C.ember end
  if op == "grant_team" then return C.gold end
  return C.brassS
end

local function opLabel(op)
  op = tostring(op or "attack")
  local key = "bossrush.op." .. op
  local v = T(key)
  if v ~= key then return v end
  return string.upper((op:gsub("_", " ")))
end

local function primaryThreat(spec)
  if not spec then return T("bossrush.op.attack"), Theme.c.ink3 end
  if spec.taunt then return T("bossrush.op.taunt"), Theme.c.gold end
  if (spec.shield or 0) > 0 then return T("bossrush.op.shield"), Theme.c.shield end
  if (spec.dmgReduce or 0) > 0 then return T("bossrush.op.armor"), Theme.c.steel end
  local effects = spec.effects or {}
  for _, e in ipairs(effects) do
    if e and e.op then return opLabel(e.op), effectColor(e.op) end
  end
  return T("bossrush.op.attack"), Theme.c.ink3
end

local function collectThreats(abom)
  local out, seen = {}, {}
  local function addFrom(spec)
    for _, e in ipairs((spec and spec.effects) or {}) do
      local op = e and e.op
      local label = op and opLabel(op)
      if label and not seen[label] then
        seen[label] = true
        out[#out + 1] = { label = label, color = effectColor(op) }
      end
    end
  end
  if abom then
    addFrom(abom.boss)
    for _, g in ipairs(abom.generals or {}) do addFrom(g) end
  end
  return out
end

local function drawTag(x, y, label, color, w)
  local C = Theme.c
  w = w or math.max(74, (Theme.labelSmall(9):getWidth(label) or 0) + 24)
  Draw.rect(x, y, w, 22, { C.stone900[1], C.stone900[2], C.stone900[3], 0.72 }, color, 1)
  Draw.rect(x, y, 3, 22, color)
  Draw.textC(label, x + w / 2 + 2, y + 5, color, Theme.labelSmall(9))
  return w
end

local function drawBossSeal(x, y, w, h, abom, accent, t)
  local C = Theme.c
  Draw.rect(x, y, w, h, { C.stone900[1], C.stone900[2], C.stone900[3], 0.74 }, C.iron, 2)
  Draw.rect(x + 2, y + 2, w - 4, h - 4, nil, C.brassD, 1)
  local cx, cy = x + w / 2, y + h / 2 + 8
  local pulse = 0.5 + 0.5 * math.sin((t or 0) * 1.4)
  Draw.setColor(accent, 0.08 + pulse * 0.05)
  love.graphics.circle("fill", cx, cy, h * 0.52)
  Draw.setColor(accent, 0.20)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", cx, cy, h * 0.40)
  Draw.setColor(C.brassD, 0.90)
  love.graphics.circle("line", cx, cy, h * 0.26)
  for i = 1, 8 do
    local a = (i / 8) * math.pi * 2 + (t or 0) * 0.18
    local r1, r2 = h * 0.18, h * (0.38 + 0.05 * math.sin((t or 0) + i))
    Draw.setColor(accent, 0.25)
    love.graphics.line(cx + math.cos(a) * r1, cy + math.sin(a) * r1,
      cx + math.cos(a) * r2, cy + math.sin(a) * r2)
  end
  AbominationSprite.drawBossIcon(abom and abom.key or "leviathan", cx, cy + 2, w * 0.34, h * 0.72, 0.94)
  love.graphics.setLineWidth(1)
  Draw.textTrackedC(T("bossrush.boss_role"), cx, y + 12, C.ink5, Theme.labelSmall(8), 1.6)
  local family = string.upper(tostring((abom and abom.theme) or "-"))
  Draw.textC(T("bossrush.family", { family = family }), cx, y + h - 22, C.ink3, Theme.labelSmall(9))
end

local function drawGeneralRow(x, y, w, idx, spec, state, fallbackCleared)
  local C = Theme.c
  local label, col = primaryThreat(spec)
  local cleared = fallbackCleared and true or false
  if state then cleared = not state.alive end
  local status = cleared and T("bossrush.general_broken") or T("bossrush.general_blocks")
  local statusColor = cleared and C.ink4 or C.bloodL
  Draw.rect(x, y, w, 31, { C.stone900[1], C.stone900[2], C.stone900[3], 0.54 }, C.brassD, 1)
  Draw.rect(x, y, 4, 31, col)
  Draw.textTrackedL(T("bossrush.general_n", { n = idx }), x + 12, y + 7, C.ink2, Theme.labelSmall(9), 1.1)
  drawTag(x + 100, y + 4, label, col, 92)
  Draw.textR(status, x + w - 10, y + 8, statusColor, Theme.labelSmall(9))
end

local function drawEncounter(x, y, w, h, abom, result, accent, t)
  local C = Theme.c
  Dividers.text(x + w / 2, y - 3, w, T("bossrush.encounter_title"))
  drawBossSeal(x, y + 22, w, 116, abom, accent, t)
  Draw.textTrackedL(T("bossrush.threats"), x, y + 150, C.ink5, Theme.labelSmall(8), 1.0)
  local tx = x
  local threats = collectThreats(abom)
  for i = 1, math.min(3, #threats) do
    local tag = threats[i]
    local tw = drawTag(tx, y + 169, tag.label, tag.color)
    tx = tx + tw + 8
  end
  if #threats == 0 then
    Draw.text(T("bossrush.no_threats"), x, y + 171, C.ink5, Theme.labelSmall(9))
  end
  local gy = y + 196
  for i = 1, 3 do
    drawGeneralRow(x, gy + (i - 1) * 32, w, i, abom and abom.generals and abom.generals[i],
      result.generals and result.generals[i], result.cleared_blockers)
  end
end

local function drawPhaseRail(x, y, w, result, accent)
  local C = Theme.c
  Dividers.text(x + w / 2, y - 3, w, T("bossrush.phase_title"))
  local phases = {
    { key = "bossrush.phase_generals", ok = result.cleared_blockers, status = result.cleared_blockers and "bossrush.phase_done" or "bossrush.phase_blocked" },
    { key = "bossrush.phase_score", ok = (result.score_ticks or 0) > 0, status = result.cleared_blockers and "bossrush.phase_open" or "bossrush.phase_locked" },
    { key = "bossrush.phase_result", ok = true, status = result.boss_killed and "bossrush.phase_boss_dead" or "bossrush.phase_closed" },
  }
  local gap = 12
  local bw = math.floor((w - gap * 2) / 3)
  local sc = Juice.scale("bossrush.phase")
  love.graphics.push()
  love.graphics.translate(x + w / 2, y + 46)
  love.graphics.scale(sc, sc)
  love.graphics.translate(-(x + w / 2), -(y + 46))
  for i, ph in ipairs(phases) do
    local bx = x + (i - 1) * (bw + gap)
    local col = ph.ok and accent or C.ink5
    Draw.rect(bx, y + 20, bw, 52, { C.stone900[1], C.stone900[2], C.stone900[3], 0.58 }, C.brassD, 1)
    Draw.rect(bx, y + 20, 4, 52, col)
    Draw.textTrackedL(T(ph.key), bx + 13, y + 29, ph.ok and C.ink2 or C.ink4, Theme.labelSmall(8), 1.0)
    Draw.text(T(ph.status), bx + 13, y + 49, col, Theme.labelSmall(9))
  end
  love.graphics.pop()
end

local function drawScoreBlock(x, y, w, result, shownScore, accent)
  local C = Theme.c
  local sc = Juice.scale("bossrush.score")
  local cx = x + w / 2
  Draw.rect(x, y, w, 70, { C.stone900[1], C.stone900[2], C.stone900[3], 0.58 }, C.brassD, 1)
  Draw.rect(x, y, 4, 70, accent)
  Draw.textTrackedC(T("bossrush.metric_damage"), cx, y + 10, C.ink5, Theme.labelSmall(9), 1.4)
  love.graphics.push()
  love.graphics.translate(cx, y + 36)
  love.graphics.scale(sc, sc)
  Draw.textC(tostring(math.floor((shownScore or 0) + 0.5)), 0, -10, C.ink, Theme.value(30))
  love.graphics.pop()
  local dps = math.floor((result.boss_score_dps or 0) * 10 + 0.5) / 10
  drawMiniMetric(x, y + 84, 148, "bossrush.metric_dps", tostring(dps), accent)
  drawMiniMetric(x + 160, y + 84, 150, "bossrush.metric_window", yn(result.survived_score_window), accent)
  drawMiniMetric(x + 322, y + 84, 150, "bossrush.metric_survived", yn(result.survived), accent)
  drawMiniMetric(x + 484, y + 84, w - 484, "bossrush.metric_clear", T("bossrush.seconds", { s = math.floor((result.clear_seconds or 0) * 10 + 0.5) / 10 }), accent)
end

local function causeLabel(cause)
  local key = "combat.cause." .. tostring(cause or "attack")
  local v = T(key)
  if v == key then return tostring(cause or "attack") end
  return v
end

local function causeColor(cause)
  if cause == "attack" or cause == "cleave" then return Theme.c.bloodL end
  if cause == "fatigue" then return Theme.c.ink4 end
  return effectColor(cause)
end

local function drawCauseChip(x, y, w, cause, amount)
  local C = Theme.c
  local col = causeColor(cause)
  Draw.rect(x, y, w, 26, { C.stone900[1], C.stone900[2], C.stone900[3], 0.66 }, C.brassD, 1)
  Draw.rect(x, y, 4, 26, col)
  Draw.textTrackedL(string.upper(causeLabel(cause)), x + 12, y + 7, col, Theme.labelSmall(8), 0.8)
  Draw.textR(tostring(math.floor((amount or 0) + 0.5)), x + w - 10, y + 7, C.ink, Theme.value(10))
end

local function livePanel(x, y, w, h, accent)
  local C = Theme.c
  local ix, iy, iw, ih = Panel.draw(x, y, w, h, {
    solid = true,
    border = C.brassD,
    fill1 = C.stone850,
    fill2 = C.stone900,
  })
  if accent then Draw.rect(ix, iy, 3, ih, accent) end
  return ix, iy, iw, ih
end

local function drawLiveGeneralsStrip(x, y, w, h, abom, snap, accent)
  local C = Theme.c
  local ix, iy, iw = livePanel(x, y, w, h, accent)
  Draw.textTrackedL(T("bossrush.live_generals"), ix + 14, iy + 10, C.ink4, Theme.labelSmall(8), 1.1)
  local cellW, gap = math.floor((iw - 44) / 3), 10
  for i = 1, 3 do
    local spec = abom and abom.generals and abom.generals[i] or nil
    local state = snap.generals and snap.generals[i]
    local label, col = primaryThreat(spec)
    local cleared = snap.cleared_blockers or (state and not state.alive)
    local bx = ix + 14 + (i - 1) * (cellW + gap)
    local by = iy + 34
    Draw.rect(bx, by, cellW, 32, { C.stone900[1], C.stone900[2], C.stone900[3], 0.62 }, cleared and C.iron or col, 1)
    Draw.rect(bx, by, 3, 32, cleared and C.ink5 or col)
    Draw.textTrackedL(T("bossrush.general_n", { n = i }), bx + 10, by + 7, cleared and C.ink5 or C.ink2, Theme.labelSmall(8), 0.8)
    Draw.textR(cleared and T("bossrush.general_broken") or label, bx + cellW - 8, by + 7, cleared and C.ink5 or col, Theme.labelSmall(8))
  end
end

local function drawLiveScore(x, y, w, self, snap, accent)
  local C = Theme.c
  local open = self.scoreStartTick ~= nil
  local ix, iy, iw = livePanel(x, y, w, 74, open and accent or C.bloodL)
  Draw.textTrackedL(T("bossrush.metric_damage"), ix + 14, iy + 10, C.ink5, Theme.labelSmall(8), 1.1)
  Draw.text(T(open and "bossrush.live_score_open" or "bossrush.phase_locked"), ix + 14, iy + 28, open and accent or C.ink4, Theme.labelSmall(9))

  local secondsLeft = math.max(0, (self.scoreTicks - (self.scoreElapsed or 0)) / 60)
  local barPct = open and clamp01((self.scoreElapsed or 0) / self.scoreTicks) or 0
  local sc = Juice.scale("bossrush.live_score")
  love.graphics.push()
  love.graphics.translate(ix + iw - 74, iy + 34)
  love.graphics.scale(sc, sc)
  Draw.textR(int(self.liveShownScore or self.scoreDamage or 0), 58, -12, C.ink, Theme.value(26))
  love.graphics.pop()
  Draw.rect(ix + 14, iy + 58, iw - 28, 7, { C.stone800[1], C.stone800[2], C.stone800[3], 0.82 }, C.iron, 1)
  local meterSc = Juice.scale("bossrush.live_meter")
  local fillW = math.floor((iw - 30) * barPct)
  if fillW > 0 then
    local cx = ix + 15 + fillW / 2
    love.graphics.push()
    love.graphics.translate(cx, iy + 61)
    love.graphics.scale(meterSc, 1)
    Draw.rect(-fillW / 2, -3, fillW, 5, accent)
    love.graphics.pop()
  end
  local timerText = open and T("bossrush.live_timer", { s = string.format("%.1f", secondsLeft) })
    or T("bossrush.live_window_locked")
  Draw.text(timerText, ix + 14, iy + 40, C.ink3, Theme.labelSmall(8))
  if open then
    local dps = math.floor((snap.boss_score_dps or 0) * 10 + 0.5) / 10
    Draw.text(T("bossrush.live_dps", { dps = tostring(dps) }), ix + 102, iy + 40, C.ink3, Theme.labelSmall(8))
  end
end

function Scene:_drawControls(x, y)
  local C = Theme.c
  local f = Theme.labelSmall(8)
  x = x or (Draw.W - 364)
  y = y or (Draw.H - 42)
  Draw.textTrackedL(T("bossrush.live_controls_short"), x, y - 18, C.ink5, f, 0.9)
  local segs = {
    { id = "pause", label = self.paused and T("ui.resume") or T("ui.pause"), on = self.paused, w = 96 },
    { id = "spd1", label = "1x", on = (self.speed == 1) and not self.skipping, w = 52 },
    { id = "spd2", label = "2x", on = (self.speed == 2) and not self.skipping, w = 52 },
    { id = "skip", label = T("ui.speed_skip"), on = self.skipping, w = 88 },
  }
  local sx = x
  for _, s in ipairs(segs) do
    local r = { x = sx, y = y, w = s.w, h = 30 }
    local hot = ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, s.on and "eco" or "secondary", s.label, {
      hover = hot,
      feel = Feel.state("bossrush." .. s.id),
      id = "bossrush." .. s.id,
    })
    if s.id == "pause" then self._btnPause = r
    elseif s.id == "spd1" then self._btnSpd1 = r
    elseif s.id == "spd2" then self._btnSpd2 = r
    else self._btnSkip = r end
    sx = sx + s.w + 8
  end
end

function Scene:drawLiveOverlay(view)
  local C = Theme.c
  local snap = self:_liveSnapshot()
  local abom = self.abom
  local accent = colorFromAccent(abom and abom.accent, C.brassS)
  local boss = bossUnit(self.arena)

  -- Les overlays de combat (noms, barres, nombres) passent SOUS le chrome bossrush.
  if self.renderer then self.renderer:drawOverlay(view) end

  Draw.begin(view)
  -- Header compact : phase a gauche, boss au centre, score live a droite.
  Draw.rect(0, 0, Draw.W, LIVE_TOP_H, { C.void[1], C.void[2], C.void[3], 0.76 })
  Draw.rect(0, LIVE_TOP_H - 1, Draw.W, 1, { C.brassS[1], C.brassS[2], C.brassS[3], 0.24 })

  local phaseOpen = self.scoreStartTick ~= nil
  local phaseCol = phaseOpen and accent or C.bloodL
  local phaseX, phaseY, phaseW = 24, 18, 260
  local pix, piy, piw = livePanel(phaseX, phaseY, phaseW, 54, phaseCol)
  Draw.textTrackedL(T("bossrush.live_phase"), pix + 12, piy + 8, C.ink5, Theme.labelSmall(8), 1.0)
  Draw.text(T(phaseOpen and "bossrush.live_score_open" or "bossrush.live_break"), pix + 12, piy + 26, phaseCol, Theme.subhead(13))

  Draw.textTrackedC(T("bossrush.word"), Draw.W / 2, 12, C.ink4, Theme.labelSmall(9), 1.7)
  Draw.textC(bossDisplayName(snap), Draw.W / 2, 30, C.ink, Theme.subhead(21))

  local hpFrac = boss and boss.maxHp and boss.maxHp > 0 and math.max(0, boss.hp / boss.maxHp) or 0
  local bx, by, bw, bh = 410, 62, 460, 9
  Draw.bar(bx, by, bw, bh, hpFrac, C.bloodL, C.stone900, C.iron)
  local hpText = boss and T("bossrush.hp_left", {
    hp = math.floor((boss.hp or 0) + 0.5),
    max = math.floor((boss.maxHp or 0) + 0.5),
  }) or T("bossrush.no_boss")
  Draw.textC(hpText, bx + bw / 2, by + 13, C.ink3, Theme.labelSmall(8))

  drawLiveScore(Draw.W - 380, 18, 292, self, snap, accent)

  -- Bande basse : etat des generaux + score window + controles. Elle reste sous le plateau de combat.
  Draw.rect(0, LIVE_BOTTOM_Y - 1, Draw.W, 1, { C.brassS[1], C.brassS[2], C.brassS[3], 0.16 })
  Draw.rect(0, LIVE_BOTTOM_Y, Draw.W, Draw.H - LIVE_BOTTOM_Y, { C.void[1], C.void[2], C.void[3], 0.64 })
  drawLiveGeneralsStrip(24, LIVE_BOTTOM_Y + 14, 520, 70, abom, snap, accent)

  local sx, sy, sw = 566, LIVE_BOTTOM_Y + 14, 294
  local six, siy, siw = livePanel(sx, sy, sw, 70, accent)
  Draw.textTrackedL(T("bossrush.live_window"), six + 14, siy + 10, C.ink5, Theme.labelSmall(8), 1.0)
  local pct = clamp01((self.scoreElapsed or 0) / math.max(1, self.scoreTicks))
  Draw.bar(six + 14, siy + 34, siw - 28, 8, pct, accent, C.stone900, C.iron)
  local windowText = self.scoreStartTick and
    T("bossrush.live_timer", { s = string.format("%.1f", math.max(0, (self.scoreTicks - (self.scoreElapsed or 0)) / 60)) })
    or T("bossrush.live_window_locked")
  Draw.textC(windowText, six + siw / 2, siy + 49, C.ink3, Theme.labelSmall(8))

  self:_drawControls(900, LIVE_BOTTOM_Y + 34)
  Draw.finish()
end

local function drawResultMetric(x, y, w, h, labelKey, value, accent)
  local C = Theme.c
  Draw.rect(x, y, w, h, { C.stone900[1], C.stone900[2], C.stone900[3], 0.62 }, C.brassD, 1)
  Draw.rect(x, y, 3, h, accent)
  Draw.textTrackedC(T(labelKey), x + w / 2, y + 8, C.ink5, Theme.labelSmall(8), 0.9)
  Draw.textC(value, x + w / 2, y + 28, C.ink, Theme.value(15))
end

local function drawResultBossCard(x, y, w, h, abom, r, accent, t)
  local C = Theme.c
  local ix, iy, iw, ih = Panel.draw(x, y, w, h, { solid = true, accent = accent, fill1 = C.stone850, fill2 = C.stone900 })
  Draw.textTrackedC(T("bossrush.word"), ix + iw / 2, iy + 12, C.ink5, Theme.labelSmall(8), 1.2)
  Draw.textC(bossDisplayName(r), ix + iw / 2, iy + 30, C.ink, Theme.subhead(15))
  drawBossSeal(ix + 26, iy + 58, iw - 52, 132, abom, accent, t)
  local hpFrac = math.max(0, math.min(1, r.boss_hp_frac or 0))
  Draw.textTrackedL(T("bossrush.boss_hp"), ix + 22, iy + ih - 62, C.ink5, Theme.labelSmall(8), 0.9)
  Draw.bar(ix + 22, iy + ih - 39, iw - 44, 9, 1 - hpFrac, C.bloodL, C.stone900, C.iron)
  Draw.textC(T("bossrush.hp_left", {
    hp = math.floor((r.boss_hp_remaining or 0) + 0.5),
    max = math.floor((r.boss_hp_max or 0) + 0.5),
  }), ix + iw / 2, iy + ih - 24, C.ink3, Theme.labelSmall(8))
end

local function drawResultScoreCard(x, y, w, h, r, shownScore, accent)
  local C = Theme.c
  local ix, iy, iw, ih = Panel.draw(x, y, w, h, { solid = true, accent = accent, fill1 = C.stone800, fill2 = C.stone900 })
  local sc = Juice.scale("bossrush.score")
  Draw.textTrackedC(T("bossrush.metric_damage"), ix + iw / 2, iy + 18, C.ink5, Theme.labelSmall(9), 1.3)
  love.graphics.push()
  love.graphics.translate(ix + iw / 2, iy + 76)
  love.graphics.scale(sc, sc)
  Draw.textC(int(shownScore), 0, -30, C.gold, Theme.value(42))
  love.graphics.pop()
  Dividers.brass(ix + iw / 2, iy + 118, iw - 80)
  local dps = math.floor((r.boss_score_dps or 0) * 10 + 0.5) / 10
  drawResultMetric(ix + 18, iy + 140, 116, 56, "bossrush.metric_dps", tostring(dps), accent)
  drawResultMetric(ix + 148, iy + 140, 116, 56, "bossrush.metric_window", yn(r.survived_score_window), accent)
  drawResultMetric(ix + 278, iy + 140, iw - 296, 56, "bossrush.metric_survived", yn(r.survived), accent)
  local clear = T("bossrush.seconds", { s = oneDecimal(r.clear_seconds or 0) })
  Draw.textTrackedC(T("bossrush.metric_clear"), ix + iw / 2, iy + ih - 42, C.ink5, Theme.labelSmall(8), 0.9)
  Draw.textC(clear, ix + iw / 2, iy + ih - 24, C.ink3, Theme.labelSmall(10))
end

local function drawResultSources(x, y, w, h, r, accent)
  local C = Theme.c
  local ix, iy, iw = Panel.draw(x, y, w, h, { solid = true, accent = accent, fill1 = C.stone850, fill2 = C.stone900 })
  Dividers.text(ix + iw / 2, iy + 12, iw - 36, T("bossrush.causes"))
  local map = r.score_damage_by_cause or {}
  local rows, total = {}, 0
  for _, cause in ipairs(CAUSE_ORDER) do
    local amount = map[cause] or 0
    if amount > 0 then
      rows[#rows + 1] = { cause = cause, amount = amount }
      total = total + amount
    end
  end
  if #rows == 0 then
    Draw.textWrap(T("bossrush.no_score_causes"), ix + 22, iy + 52, iw - 44, C.ink4, Theme.body(12), "center")
    return
  end
  table.sort(rows, function(a, b) return a.amount > b.amount end)
  for i = 1, math.min(5, #rows) do
    local row = rows[i]
    local cy = iy + 48 + (i - 1) * 32
    local col = causeColor(row.cause)
    Draw.textTrackedL(string.upper(causeLabel(row.cause)), ix + 22, cy + 2, col, Theme.labelSmall(8), 0.7)
    Draw.textR(int(row.amount), ix + iw - 22, cy + 2, C.ink, Theme.value(10))
    local barW = iw - 148
    Draw.rect(ix + 22, cy + 20, barW, 6, { C.stone900[1], C.stone900[2], C.stone900[3], 0.8 }, C.iron, 1)
    Draw.rect(ix + 23, cy + 21, math.floor((barW - 2) * math.min(1, row.amount / math.max(1, total))), 4, col)
  end
end

function Scene:drawOverlay(view)
  if not self.result then
    self:drawLiveOverlay(view)
    return
  end

  local C = Theme.c
  local r = self.result or {}
  local tt = self.t / 60
  local abom = abomForResult(r)
  local accent = colorFromAccent(abom and abom.accent, C.brassS)

  Draw.begin(view)
  local anim = self._anim or 1
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.015, 0.01, 0.025, 0.58 * anim })
  Overlay.pushContent(Draw.W / 2, Draw.H / 2, anim)

  local px = math.floor((Draw.W - RESULT_W) / 2)
  local py = 62
  Panel.draw(px, py, RESULT_W, RESULT_H, { solid = true, accent = C.brass, fill1 = C.stone800, fill2 = C.stone900 })
  Draw.textTrackedC(T("bossrush.result_title"), Draw.W / 2, py + 26, C.ink4, Theme.labelSmall(10), 1.6)
  Draw.textC(bossDisplayName(r), Draw.W / 2, py + 48, C.ink, Theme.subhead(23))
  Dividers.brass(Draw.W / 2, py + 84, RESULT_W - 120)

  drawResultBossCard(px + 28, py + 112, 284, RESULT_CARD_H, abom, r, accent, tt)
  drawResultScoreCard(px + 336, py + 112, 396, RESULT_CARD_H, r, self.shownScore, accent)
  drawResultSources(px + 756, py + 112, 256, RESULT_CARD_H, r, accent)

  local phaseY = py + RESULT_H - 96
  drawPhaseRail(px + 28, phaseY, RESULT_W - 56, r, accent)

  Button.draw(self.btnNew.x, self.btnNew.y, self.btnNew.w, self.btnNew.h, "primary",
    T(hasReturnPayload(self) and "bossrush.back_pg" or "bossrush.new_run"), {
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
  if not self.result then
    if ptIn(self.mx, self.my, self._btnPause) then Feel.press("bossrush.pause"); self.paused = not self.paused; return end
    if ptIn(self.mx, self.my, self._btnSpd1) then Feel.press("bossrush.spd1"); self.speed, self.skipping = 1, false; return end
    if ptIn(self.mx, self.my, self._btnSpd2) then Feel.press("bossrush.spd2"); self.speed, self.skipping = 2, false; return end
    if ptIn(self.mx, self.my, self._btnSkip) then Feel.press("bossrush.skip"); self.skipping = true; return end
    return
  end
  if ptIn(self.mx, self.my, self.btnNew) then
    Feel.press("bossrush.new", function() finishPrimary(self) end, { delay = Feel.CTA_DELAY })
  elseif ptIn(self.mx, self.my, self.btnMenu) then
    Feel.press("bossrush.menu", function() finishSecondary(self) end)
  end
end

function Scene:mousereleased() end

function Scene:keypressed(key)
  if not self.result then
    if key == "space" then self.paused = not self.paused
    elseif key == "1" then self.speed, self.skipping = 1, false
    elseif key == "2" then self.speed, self.skipping = 2, false
    elseif key == "s" then self.skipping = true end
    return
  end
  if key == "r" then finishPrimary(self)
  elseif key == "m" then finishSecondary(self) end
end

return Scene
