-- src/core/unit_resolver.lua
-- Pure source of truth for level-aware unit stats and authored ability deltas.
-- No love.* and no render/audio dependency.

local Units = require("src.data.units")
local UnitLevels = require("src.data.unit_levels")

local Resolver = {}

Resolver.MAX_LEVEL = 3
Resolver.STAT_LEVEL_MULT = { 1.0, 1.8, 3.0 }

local function clampLevel(level)
  level = math.floor(tonumber(level) or 1)
  if level < 1 then return 1 end
  if level > Resolver.MAX_LEVEL then return Resolver.MAX_LEVEL end
  return level
end
Resolver.clampLevel = clampLevel

local function isArray(t)
  if type(t) ~= "table" then return false end
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" then return false end
    if k > n then n = k end
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true
end

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for i, x in ipairs(v) do out[i] = clone(x) end
  for k, x in pairs(v) do
    if type(k) ~= "number" or k < 1 or k > #v or math.floor(k) ~= k then
      out[k] = clone(x)
    end
  end
  return out
end
Resolver.clone = clone

local function mergeInto(dst, patch)
  if type(patch) ~= "table" then return dst end
  for k, v in pairs(patch) do
    if type(v) == "table" and type(dst[k]) == "table" and not isArray(v) then
      mergeInto(dst[k], v)
    else
      dst[k] = clone(v)
    end
  end
  return dst
end

local function markAuthored(effect)
  if type(effect) == "table" then effect.levelAuthored = true end
end

local function applyEffectPatches(effects, patches)
  if type(patches) ~= "table" then return end
  for idx, patch in pairs(patches) do
    local target = effects[idx]
    if target and type(patch) == "table" then
      mergeInto(target, patch)
      markAuthored(target)
    end
  end
end

local function applyCommandPatch(commandBonus, patch)
  if not (commandBonus and type(patch) == "table") then return commandBonus end
  mergeInto(commandBonus, patch)
  commandBonus.levelAuthored = true
  return commandBonus
end

function Resolver.hasAuthoredLevel(id)
  return UnitLevels[id] ~= nil
end

function Resolver.levelSpec(id, level)
  local spec = UnitLevels[id]
  return spec and spec[clampLevel(level)] or nil
end

function Resolver.statMult(level)
  return Resolver.STAT_LEVEL_MULT[clampLevel(level)] or 1.0
end

function Resolver.statsFor(id, level, opts)
  opts = opts or {}
  local u = Units[id]
  if not u then return nil end
  level = clampLevel(level)
  local m = opts.statMult or Resolver.statMult(level)
  return {
    id = id,
    level = level,
    hp = math.floor((u.hp or 0) * m + 0.5),
    dmg = math.floor((u.dmg or 0) * m + 0.5),
    cd = u.cd,
  }
end

function Resolver.effectsFor(id, level)
  local u = Units[id]
  if not u then return {} end
  level = clampLevel(level)
  local effects = clone(u.effects or {})
  local spec = UnitLevels[id]
  if spec then
    for l = 2, level do
      local patch = spec[l]
      if patch then applyEffectPatches(effects, patch.effects) end
    end
  end
  return effects
end

function Resolver.commandBonusFor(id, level)
  local u = Units[id]
  if not (u and u.commandBonus) then return nil end
  level = clampLevel(level)
  local commandBonus = clone(u.commandBonus)
  local spec = UnitLevels[id]
  if spec then
    for l = 2, level do
      local patch = spec[l]
      if patch then commandBonus = applyCommandPatch(commandBonus, patch.commandBonus) end
    end
  end
  return commandBonus
end

function Resolver.unitForLevel(id, level)
  local u = Units[id]
  if not u then return nil end
  level = clampLevel(level)
  local out = clone(u)
  local stats = Resolver.statsFor(id, level)
  out.level = level
  out.hp = stats.hp
  out.dmg = stats.dmg
  out.cd = stats.cd
  out.effects = Resolver.effectsFor(id, level)
  out.commandBonus = Resolver.commandBonusFor(id, level)
  return out
end

function Resolver.legacyEffectLevelMult(effect, level)
  if effect and effect.levelAuthored then return 1.0 end
  return Resolver.statMult(level)
end

local function valuesFor(effect)
  return clone(effect and effect.params or {})
end

function Resolver.effectFactsFor(id, level, opts)
  opts = opts or {}
  level = clampLevel(level)
  local facts = {}
  local Tags = require("src.core.tags")

  local function add(effect, kind)
    if not effect then return end
    facts[#facts + 1] = {
      source = id,
      level = level,
      kind = kind or "board",
      trigger = effect.trigger,
      op = effect.op,
      target = effect.target,
      tags = Tags.forEffect(effect, { commander = kind == "command" }),
      values = valuesFor(effect),
      public = true,
      levelAuthored = effect.levelAuthored == true,
    }
  end

  if opts.context == "commander" or opts.commander == true then
    add(Resolver.commandBonusFor(id, level), "command")
  else
    for _, e in ipairs(Resolver.effectsFor(id, level)) do add(e, "board") end
    if opts.includeCommand then add(Resolver.commandBonusFor(id, level), "command") end
  end
  return facts
end

function Resolver.levelDeltaSummary(id)
  local out = {}
  if not UnitLevels[id] then return out end
  for level = 2, Resolver.MAX_LEVEL do
    local patch = UnitLevels[id][level]
    if patch then
      out[#out + 1] = {
        level = level,
        clutch = patch.clutch == true,
        transformative = patch.transformative == true,
      }
    end
  end
  return out
end

return Resolver
