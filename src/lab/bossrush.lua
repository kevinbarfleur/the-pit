-- src/lab/bossrush.lua
-- Runner PvE/endgame scoring : un build joueur affronte une abomination
-- composee d'un boss et de trois generaux. Les generaux bloquent le focus ;
-- une fois tout bloqueur mort, la fenetre de scoring compte les degats au boss.
--
-- Pure par intention de lab : aucun rendu/audio, RNG seedee via Arena, sortie
-- JSON-friendly pour tools/scenarios/bossrush.lua.

local Arena = require("src.combat.arena")
local Place = require("src.combat.place")
local Pacing = require("src.run.pacing")
local Abominations = require("src.data.abominations")

local Bossrush = {}

local DEFAULT_SCORE_TICKS = 20 * 60
local DEFAULT_TICK_CAP = 60 * 60
local NO_FATIGUE = { start = 999999, base = 0, ramp = 0 }

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = clone(vv) end
  return out
end

local function specFrom(src, col, row, slot)
  local s = clone(src)
  s.col, s.row, s.slot = col, row, slot
  return s
end

-- Formation droite : les trois generaux au front (depth 0), boss derriere
-- (depth 1). Le ciblage existant force donc le joueur a ouvrir le front avant
-- de scorer le boss, sans nouvelle regle de targeting.
function Bossrush.toComp(abom, side)
  if type(abom) == "string" then abom = Abominations.byKey[abom] end
  assert(abom, "abomination inconnue")
  side = side or 1
  local cells = {
    specFrom(abom.boss, 0, 1, 94),
    specFrom(abom.generals[1], 1, 0, 91),
    specFrom(abom.generals[2], 1, 1, 92),
    specFrom(abom.generals[3], 1, 2, 93),
  }
  local b = Place.bounds(cells)
  local comp = {}
  for _, s in ipairs(cells) do
    local x, y = Place.pos(s.col, s.row, side, b)
    comp[#comp + 1] = {
      id = s.id,
      role = s.role,
      abomination = abom.key,
      theme = abom.theme,
      slot = s.slot,
      level = 1,
      hp = s.hp,
      dmg = s.dmg,
      cd = s.cd,
      depth = b.maxC - s.col,
      col = s.col,
      row = s.row,
      aggro = s.aggro,
      taunt = s.taunt,
      shield = s.shield,
      effects = s.effects,
      dmgReduce = s.dmgReduce,
      haste = s.haste,
      atkInc = s.atkInc,
      multicast = s.multicast,
      strikeHighestHp = s.strikeHighestHp,
      shieldCaster = s.shieldCaster,
      x = x,
      y = y,
      facing = (side == 1) and -1 or 1,
    }
  end
  return comp
end

local function countAlive(arena, pred)
  local n = 0
  for _, u in ipairs(arena.units or {}) do
    if u.alive and pred(u) then n = n + 1 end
  end
  return n
end

local function bossUnit(arena)
  for _, u in ipairs(arena.units or {}) do
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

local function sortedCauseMap(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = v end
  return out
end

-- leftComp : compo d'arene deja resolue (Compbuild.toComp ou Build:buildLeftComp).
-- opts = { scoreTicks?, tickCap?, hpMult?, cooldownMult?, fatigue?, pacingProfile? }.
function Bossrush.run(leftComp, abomKey, seed, opts)
  opts = opts or {}
  local abom = Abominations.byKey[abomKey] or Abominations.list[1]
  assert(abom, "abomination inconnue: " .. tostring(abomKey))
  local rightComp = Bossrush.toComp(abom, 1)
  local pacing = Pacing.arenaOptions(opts.pacingProfile)
  if opts.hpMult ~= nil then pacing.hpMult = opts.hpMult end
  if opts.cooldownMult ~= nil then pacing.cooldownMult = opts.cooldownMult end
  pacing.fatigue = opts.fatigue or NO_FATIGUE

  local scoreTicks = opts.scoreTicks or DEFAULT_SCORE_TICKS
  local tickCap = opts.tickCap or DEFAULT_TICK_CAP
  local scorePhase = false
  local scoreStart, scoreElapsed = nil, 0
  local bossDamage, scoreDamage = 0, 0
  local byCause, scoreByCause = {}, {}

  local arena = Arena.new({
    left = leftComp,
    right = rightComp,
    autoReset = false,
    seed = seed or 0,
    hpMult = pacing.hpMult,
    cooldownMult = pacing.cooldownMult,
    fatigue = pacing.fatigue,
  })
  arena.bus:on("damage", function(ev)
    local tgt = ev.target
    if tgt and tgt.spec and tgt.spec.role == "boss" and ev.hp and ev.hp > 0 then
      local cause = ev.cause or "attack"
      bossDamage = bossDamage + ev.hp
      byCause[cause] = (byCause[cause] or 0) + ev.hp
      if scorePhase then
        scoreDamage = scoreDamage + ev.hp
        scoreByCause[cause] = (scoreByCause[cause] or 0) + ev.hp
      end
    end
  end)

  local clearTicks, totalTicks = nil, 0
  for tick = 1, tickCap do
    totalTicks = tick
    scorePhase = scoreStart ~= nil
    arena:update(1.0, tick)

    local boss = bossUnit(arena)
    if not boss or not boss.alive then break end
    if sideAlive(arena, "left") == 0 then break end

    if not scoreStart and rightBlockersAlive(arena) == 0 then
      clearTicks = tick
      scoreStart = tick + 1
    elseif scoreStart and tick >= scoreStart then
      scoreElapsed = tick - scoreStart + 1
      if scoreElapsed >= scoreTicks then break end
    end
  end

  local boss = bossUnit(arena)
  local bossHp, bossMax = boss and boss.hp or 0, boss and boss.maxHp or 0
  local survived = sideAlive(arena, "left") > 0
  local cleared = clearTicks ~= nil
  local scoreSeconds = scoreElapsed / 60
  return {
    boss_key = abom.key,
    boss_name = abom.name,
    theme = abom.theme,
    seed = seed or 0,
    cleared_blockers = cleared,
    clear_ticks = clearTicks or 0,
    clear_seconds = cleared and (clearTicks / 60) or 0,
    survived = survived,
    survived_score_window = survived and cleared and scoreElapsed >= scoreTicks,
    total_ticks = totalTicks,
    total_seconds = totalTicks / 60,
    score_ticks = scoreElapsed,
    score_seconds = scoreSeconds,
    boss_damage = bossDamage,
    boss_score_damage = scoreDamage,
    boss_score_dps = (scoreSeconds > 0) and (scoreDamage / scoreSeconds) or 0,
    boss_hp_remaining = bossHp,
    boss_hp_max = bossMax,
    boss_hp_frac = (bossMax > 0) and (bossHp / bossMax) or 0,
    boss_killed = boss ~= nil and not boss.alive,
    damage_by_cause = sortedCauseMap(byCause),
    score_damage_by_cause = sortedCauseMap(scoreByCause),
  }
end

Bossrush.DEFAULT_SCORE_TICKS = DEFAULT_SCORE_TICKS
Bossrush.DEFAULT_TICK_CAP = DEFAULT_TICK_CAP

return Bossrush
