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
local Juice = require("src.ui.juice")
local Overlay = require("src.ui.overlay")
local SFX = require("src.audio.sfx")
local I18n = require("src.core.i18n")
local T = I18n.t

local Scene = {}
Scene.__index = Scene

local PANEL_W, PANEL_H = 1080, 390
local BTN_W, BTN_H, BTN_GAP = 250, 52, 22
local CAUSE_ORDER = { "attack", "cleave", "shock", "burn", "poison", "rot", "bleed", "thorns", "reflect", "fatigue" }

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
    scoreFxMilestone = 0,
    scoreFxBucket = 0,
  }, Scene)
  local cx = math.floor(Draw.W / 2)
  self.panel = { x = math.floor(cx - PANEL_W / 2), y = 222, w = PANEL_W, h = PANEL_H }
  self.btnNew = { x = math.floor(cx - BTN_W - BTN_GAP / 2), y = 632, w = BTN_W, h = BTN_H }
  self.btnMenu = { x = math.floor(cx + BTN_GAP / 2), y = 632, w = BTN_W, h = BTN_H }
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

local function blend(a, b, t)
  return {
    (a[1] or 0) * (1 - t) + (b[1] or 0) * t,
    (a[2] or 0) * (1 - t) + (b[2] or 0) * t,
    (a[3] or 0) * (1 - t) + (b[3] or 0) * t,
    1,
  }
end

local function drawEye(cx, cy, r, accent, t)
  local C = Theme.c
  Draw.setColor(C.stone900, 0.96)
  love.graphics.circle("fill", cx, cy, r + 4, 18)
  Draw.setColor(C.ink3, 0.75)
  love.graphics.ellipse("fill", cx, cy, r + 2, r * 0.72, 22)
  Draw.setColor(accent, 0.88)
  love.graphics.ellipse("fill", cx, cy, r, r * 0.54, 22)
  Draw.setColor(C.stone900, 0.92)
  love.graphics.circle("fill", cx + math.sin((t or 0) * 1.8) * 2, cy, math.max(2, r * 0.34), 12)
  Draw.setColor(C.ink, 0.82)
  love.graphics.circle("fill", cx - r * 0.22, cy - r * 0.18, math.max(1.5, r * 0.16), 8)
end

local function drawTentacle(cx, cy, ang, len, amp, width, color, t)
  local pts = {}
  for i = 0, 7 do
    local q = i / 7
    local wob = math.sin(q * 4.1 + (t or 0) * 1.5 + ang * 2.0) * amp * q
    pts[#pts + 1] = cx + math.cos(ang) * len * q + math.cos(ang + math.pi / 2) * wob
    pts[#pts + 1] = cy + math.sin(ang) * len * q + math.sin(ang + math.pi / 2) * wob
  end
  love.graphics.setLineWidth(width)
  Draw.setColor(color, 0.78)
  love.graphics.line(pts)
  love.graphics.setLineWidth(1)
end

local function drawToothRing(cx, cy, r, accent)
  local C = Theme.c
  Draw.setColor(C.stone900, 0.95)
  love.graphics.circle("fill", cx, cy, r + 3, 24)
  Draw.setColor(accent, 0.22)
  love.graphics.circle("line", cx, cy, r + 1, 24)
  for i = 1, 14 do
    local a = (i / 14) * math.pi * 2
    local x1, y1 = cx + math.cos(a) * (r - 1), cy + math.sin(a) * (r - 1)
    local x2, y2 = cx + math.cos(a) * (r - 6), cy + math.sin(a) * (r - 6)
    Draw.setColor(C.ink3, 0.86)
    love.graphics.polygon("fill", x1, y1, x2 - math.sin(a) * 2, y2 + math.cos(a) * 2,
      x2 + math.sin(a) * 2, y2 - math.cos(a) * 2)
  end
  Draw.setColor(C.stone900, 0.88)
  love.graphics.circle("fill", cx, cy, math.max(4, r - 12), 18)
end

local function drawAbominationAvatar(cx, cy, size, abom, accent, t)
  local C = Theme.c
  local key = abom and abom.key or ""
  local theme = abom and abom.theme or ""
  local base = blend(accent, C.ink, 0.30)
  local shadow = blend(accent, C.stone900, 0.58)
  local pale = blend(accent, C.ink, 0.62)
  local s = size / 72
  local bob = math.sin((t or 0) * 1.2) * 1.5
  love.graphics.push()
  love.graphics.translate(cx, cy + bob)
  love.graphics.scale(s, s)
  love.graphics.translate(-cx, -cy)

  if key == "kraken" or theme == "sea" then
    for i = -4, 4 do
      drawTentacle(cx, cy + 8, math.pi / 2 + i * 0.22, 38 + math.abs(i) * 5, 8, 5 - math.min(3, math.abs(i)), shadow, t)
    end
    Draw.setColor(base, 0.92)
    love.graphics.ellipse("fill", cx, cy - 14, 28, 24, 28)
    drawEye(cx - 9, cy - 10, 8, accent, t)
    drawEye(cx + 9, cy - 10, 8, accent, (t or 0) + 0.4)
    drawToothRing(cx, cy + 6, 10, accent)
  elseif key == "regard" or theme == "eye" then
    Draw.setColor(shadow, 0.94)
    love.graphics.ellipse("fill", cx, cy, 34, 39, 30)
    for i = 1, 14 do
      local a = i / 14 * math.pi * 2 + (t or 0) * 0.08
      drawEye(cx + math.cos(a) * 24, cy + math.sin(a) * 24, 4, accent, (t or 0) + i)
    end
    drawEye(cx, cy - 2, 15, accent, t)
  elseif key == "ossuaire" or theme == "bone" then
    Draw.setColor(pale, 0.88)
    love.graphics.ellipse("fill", cx, cy - 18, 19, 16, 18)
    Draw.setColor(C.stone900, 0.92)
    love.graphics.circle("fill", cx - 7, cy - 18, 4, 10)
    love.graphics.circle("fill", cx + 7, cy - 18, 4, 10)
    Draw.setColor(pale, 0.82)
    love.graphics.line(cx - 18, cy - 31, cx - 30, cy - 48, cx - 26, cy - 29)
    love.graphics.line(cx + 18, cy - 31, cx + 30, cy - 48, cx + 26, cy - 29)
    love.graphics.setLineWidth(3)
    love.graphics.line(cx, cy - 4, cx, cy + 26)
    for i = 0, 4 do
      local yy = cy + i * 6
      love.graphics.line(cx, yy, cx - (18 - i * 2), yy + 5)
      love.graphics.line(cx, yy, cx + (18 - i * 2), yy + 5)
    end
    love.graphics.setLineWidth(1)
    drawEye(cx, cy + 25, 6, accent, t)
  elseif key == "idole" or theme == "sacred" then
    Draw.setColor(accent, 0.42)
    love.graphics.ellipse("line", cx, cy - 29, 31, 14, 36)
    Draw.setColor(base, 0.94)
    love.graphics.rectangle("fill", cx - 19, cy - 18, 38, 45)
    Draw.setColor(shadow, 0.96)
    love.graphics.rectangle("fill", cx - 13, cy - 11, 26, 31)
    drawEye(cx, cy + 2, 8, accent, t)
    Draw.setColor(pale, 0.82)
    love.graphics.rectangle("fill", cx - 26, cy - 13, 8, 30)
    love.graphics.rectangle("fill", cx + 18, cy - 13, 8, 30)
  elseif key == "brasier" or theme == "burn" then
    Draw.setColor(shadow, 0.96)
    love.graphics.ellipse("fill", cx, cy + 8, 27, 24, 24)
    Draw.setColor(accent, 0.88)
    love.graphics.polygon("fill", cx, cy - 41, cx - 13, cy - 2, cx + 13, cy - 2)
    love.graphics.polygon("fill", cx - 18, cy - 31, cx - 28, cy + 2, cx - 7, cy - 5)
    love.graphics.polygon("fill", cx + 18, cy - 31, cx + 28, cy + 2, cx + 7, cy - 5)
    drawEye(cx, cy + 5, 15, accent, t)
  elseif key == "floraison" or theme == "mycelium" then
    Draw.setColor(shadow, 0.94)
    love.graphics.ellipse("fill", cx, cy + 13, 23, 25, 24)
    for i, dx in ipairs({ -26, -12, 0, 14, 27 }) do
      local hh = (i == 3) and 18 or 11
      Draw.setColor(base, 0.92)
      love.graphics.rectangle("fill", cx + dx - 3, cy - 7 - hh * 0.25, 6, 24)
      Draw.setColor(accent, 0.86)
      love.graphics.ellipse("fill", cx + dx, cy - 10 - hh, 15, 8, 18)
    end
    drawEye(cx - 7, cy + 10, 5, accent, t)
    drawEye(cx + 8, cy + 7, 5, accent, (t or 0) + 0.5)
  elseif key == "devoreur" or theme == "void" then
    drawToothRing(cx, cy, 31, accent)
    for i = 1, 8 do
      local a = i / 8 * math.pi * 2 + 0.18
      drawTentacle(cx + math.cos(a) * 25, cy + math.sin(a) * 25, a, 20, 5, 3, shadow, t)
    end
    drawEye(cx, cy, 7, accent, t)
  elseif key == "vermine" or theme == "worm" then
    local pts = { { -28, 25 }, { -16, 13 }, { -5, 4 }, { 8, -7 }, { 21, -20 } }
    for i = 1, #pts do
      local p = pts[i]
      Draw.setColor(i % 2 == 0 and base or shadow, 0.94)
      love.graphics.ellipse("fill", cx + p[1], cy + p[2], 15 - i, 11 - i * 0.5, 18)
      Draw.setColor(C.stone900, 0.65)
      love.graphics.line(cx + p[1] - 10, cy + p[2], cx + p[1] + 10, cy + p[2])
    end
    drawToothRing(cx + 24, cy - 22, 11, accent)
  else
    for i = -3, 3 do
      drawTentacle(cx, cy + 5, math.pi / 2 + i * 0.28, 32 + math.abs(i) * 5, 7, 4, shadow, t)
    end
    Draw.setColor(base, 0.92)
    love.graphics.ellipse("fill", cx, cy + 6, 33, 27, 28)
    drawEye(cx - 10, cy, 5, accent, t)
    drawEye(cx + 10, cy, 5, accent, (t or 0) + 0.5)
    drawEye(cx, cy - 8, 8, accent, t)
  end

  love.graphics.pop()
  Draw.reset()
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
  drawAbominationAvatar(cx, cy + 2, h * 0.56, abom, accent, t)
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

function Scene:drawOverlay(view)
  local C = Theme.c
  local r = self.result or {}
  local tt = self.t / 60
  local abom = abomForResult(r)
  local accent = colorFromAccent(abom and abom.accent, C.brassS)

  Draw.begin(view)
  local anim = self._anim or 1
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.015, 0.01, 0.025, 0.58 * anim })
  Overlay.pushContent(Draw.W / 2, Draw.H / 2, anim)

  local scoreText = T("bossrush.score", { score = math.floor(self.shownScore + 0.5) })
  Banner.draw(170, 46, 940, "ascension", T("bossrush.word"), {
    subtitle = bossDisplayName(r),
    score = scoreText,
    hint = T("bossrush.kicker"),
    t = tt,
    h = 174,
  })

  local p = self.panel
  Panel.draw(p.x, p.y, p.w, p.h, { solid = true, accent = C.brass })
  Dividers.text(p.x + p.w / 2, p.y + 22, p.w - 72, T("bossrush.result_title"))

  local leftX, leftY, leftW = p.x + 36, p.y + 50, 318
  local rightX, rightY = leftX + leftW + 36, p.y + 50
  local rightW = p.x + p.w - rightX - 36
  drawEncounter(leftX, leftY, leftW, p.h - 78, abom, r, accent, tt)
  drawPhaseRail(rightX, rightY, rightW, r, accent)
  drawScoreBlock(rightX, rightY + 94, rightW, r, self.shownScore, accent)

  local hpFrac = math.max(0, math.min(1, r.boss_hp_frac or 0))
  local barX, barY, barW, barH = rightX, rightY + 248, rightW, 13
  Draw.text(T("bossrush.boss_hp"), barX, barY - 22, C.ink4, Theme.labelSmall(9))
  Draw.bar(barX, barY, barW, barH, 1 - hpFrac, C.bloodL, C.stone900, C.iron)
  Draw.textC(T("bossrush.hp_left", {
    hp = math.floor((r.boss_hp_remaining or 0) + 0.5),
    max = math.floor((r.boss_hp_max or 0) + 0.5),
  }), barX + barW / 2, barY + 22, C.ink3, Theme.labelSmall(9))

  local cy = rightY + 276
  Draw.text(T("bossrush.causes"), rightX, cy, C.ink4, Theme.labelSmall(9))
  local map = r.score_damage_by_cause or {}
  local x = rightX
  local wrote = 0
  for _, cause in ipairs(CAUSE_ORDER) do
    local amount = map[cause] or 0
    if amount > 0 and wrote < 4 then
      drawCauseChip(x, cy + 21, 142, cause, amount)
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
