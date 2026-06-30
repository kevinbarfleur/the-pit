-- src/core/tags.lua
-- Pure mechanical tag derivation. No love.* and no rendering dependency.
-- Tags are derived from unit data/effect descriptors so the UI glossary and
-- future exports can explain mechanics without duplicating unit metadata.

local Units = require("src.data.units")
local Relics = require("src.data.relics")
local Whispers = require("src.data.whispers")

local Tags = {}

Tags.categoryOrder = { "affliction", "defense", "offense", "structural", "direction", "newaxis", "type" }

Tags.order = {
  "poison", "bleed", "burn", "rot", "shock", "contagion", "propagation", "conversion", "aggravate",
  "shield", "heal", "regen", "thorns", "taunt", "guard",
  "empower", "growth", "execute", "crit", "cleave", "strip_shield", "vulnerable", "weaken",
  "aura", "commander", "whisper", "multicast", "haste",
  "ahead", "behind", "above", "below",
  "summon", "faint", "mimicry",
  "type", "type_flesh", "type_bone", "type_arcane", "type_abyss", "type_order",
}

Tags.category = {
  poison = "affliction", bleed = "affliction", burn = "affliction", rot = "affliction", shock = "affliction",
  contagion = "affliction", propagation = "affliction", conversion = "affliction", aggravate = "affliction",
  shield = "defense", heal = "defense", regen = "defense", thorns = "defense", taunt = "defense",
  guard = "defense",
  empower = "offense", growth = "offense",
  execute = "offense", crit = "offense", cleave = "offense", strip_shield = "offense",
  vulnerable = "offense", weaken = "offense",
  aura = "structural", commander = "structural", whisper = "structural", multicast = "structural", haste = "structural",
  ahead = "direction", behind = "direction", above = "direction", below = "direction",
  summon = "newaxis", faint = "newaxis", mimicry = "newaxis",
  type = "type", type_flesh = "type", type_bone = "type", type_arcane = "type",
  type_abyss = "type", type_order = "type",
}

local ORDER_INDEX = {}
for i, id in ipairs(Tags.order) do ORDER_INDEX[id] = i end

local AFFLICTION = { poison = true, bleed = true, burn = true, rot = true, shock = true,
  contagion = true, propagation = true, conversion = true, aggravate = true }
local FAMILY = { poison = true, bleed = true, burn = true, rot = true, shock = true }
local TYPE = { flesh = true, bone = true, arcane = true, abyss = true, order = true }

local STAT_TAGS = {
  multicast = "multicast",
  haste = "haste",
  atkInc = "empower",
  dmgReduce = "guard",
  statInc = "growth",
  poisonInc = "poison",
  burnInc = "burn",
  bleedInc = "bleed",
  rotInc = "rot",
  regen = "regen",
  lifesteal = "heal",
}

local OP_TAGS = {
  poison = { "poison" },
  bleed = { "bleed" },
  burn = { "burn" },
  rot = { "rot" },
  shock = { "shock" },
  regen = { "regen" },
  lifesteal = { "heal" },
  heal_on_kill = { "heal" },
  thorns = { "thorns" },
  strip_shield = { "strip_shield", "shield" },
  grant_vuln = { "vulnerable" },
  frenzy_gain = { "growth" },
  execute = { "execute" },
  percent_hp_strike = { "execute" },
  crit = { "crit" },
  bonus_first = { "crit" },
  cleave = { "cleave" },
  summon = { "summon", "faint" },
  scavenge_on_ally_death = { "growth" },
  repeat_ability = { "mimicry" },
  amplify_auras = { "mimicry", "aura" },
  aura_per_unique_type = { "aura", "type", "growth" },
  shield_aura = { "shield", "aura" },
  shield_caster = { "shield" },
  aura_shield = { "shield", "aura" },
  aura_burn_dps = { "burn", "aura" },
  aura_poison_dps = { "poison", "aura" },
  aura_rot_growth = { "rot", "aura" },
  aura_grant_bleed = { "bleed", "aura" },
  spread_burn_on_death = { "propagation", "burn" },
  spread_rot = { "propagation", "rot" },
  convert_to_rot = { "conversion", "bleed", "rot" },
  purge = { "heal" },
  whisper_lineage = { "whisper" },
  whisper_solo = { "whisper" },
}

local function add(seen, id)
  if id and Tags.category[id] then seen[id] = true end
end

local function addAll(seen, list)
  if not list then return end
  for _, id in ipairs(list) do add(seen, id) end
end

local function addFamily(seen, family)
  if FAMILY[family] then add(seen, family) end
end

local function addTargetTags(seen, target)
  if not target then return end
  if target == "ahead" or target == "behind" or target == "above" or target == "below" then
    add(seen, target)
  elseif target == "role:front" then
    add(seen, "ahead")
  elseif target == "role:back" then
    add(seen, "behind")
  elseif target:sub(1, 5) == "type:" then
    local ty = target:match("^type:(%w+)$")
    add(seen, "type")
    if TYPE[ty] then add(seen, "type_" .. ty) end
  end
end

local function addGrantTeamTags(seen, params)
  local p = params or {}
  if p.burnNoDecay then add(seen, "burn") end
  if p.bleedNoExpire then add(seen, "bleed") end
  if p.poisonNoCap or p.poisonDurBonus then add(seen, "poison") end
  if p.shockChain then add(seen, "shock"); add(seen, "propagation") end
  if p.rotEnemies then add(seen, "rot") end
  if p.slowEnemies then add(seen, "bleed") end
  if p.plagueAmp then add(seen, "aggravate") end
  if p.stripEnemyShield then add(seen, "strip_shield"); add(seen, "shield") end
  if p.markEnemiesVuln then add(seen, "vulnerable") end
  if p.teamExecute then add(seen, "execute") end
  if p.pierceHeal then add(seen, "rot") end
  if p.invulnT then add(seen, "shield") end
end

local function materialize(seen, extras)
  local out = {}
  for _, id in ipairs(Tags.order) do
    if seen[id] then out[#out + 1] = id end
  end
  if extras then
    table.sort(extras)
    for _, id in ipairs(extras) do
      if not ORDER_INDEX[id] and not seen[id] then out[#out + 1] = id end
    end
  end
  return out
end

function Tags.isAffliction(id) return AFFLICTION[id] == true end
function Tags.tagCategory(id) return Tags.category[id] end

function Tags.forEffect(effect, opts)
  local seen = {}
  Tags.addEffect(seen, effect, opts)
  return materialize(seen)
end

function Tags.addEffect(seen, effect, opts)
  if not effect then return end
  opts = opts or {}
  local op = effect.op
  local p = effect.params or {}
  if effect.trigger == "on_death" and op == "summon" then add(seen, "faint") end
  if opts.commander then add(seen, "commander") end
  addAll(seen, OP_TAGS[op])
  addTargetTags(seen, effect.target)

  if op == "poison" then
    if p.weaken and p.weaken > 0 then add(seen, "weaken") end
    if p.spread then add(seen, "contagion") end
    if p.shieldEat then add(seen, "strip_shield"); add(seen, "shield") end
    if p.igniteAt or p.igniteBurst then add(seen, "conversion"); add(seen, "burn") end
  elseif op == "bleed" then
    if p.aggravateMult then add(seen, "aggravate") end
  elseif op == "spread_burn_on_death" then
    if p.alsoPoison then add(seen, "poison") end
  elseif op == "convert_dot" then
    add(seen, "conversion")
    addFamily(seen, p.from)
    addFamily(seen, p.to)
  elseif op == "grant_affliction_if_absent" then
    addFamily(seen, p.family)
  elseif op == "purge" then
    addFamily(seen, p.family)
  elseif op == "aura_stat" then
    if not opts.commander then add(seen, "aura") end
    add(seen, STAT_TAGS[p.stat])
  elseif op == "grant_team" then
    addGrantTeamTags(seen, p)
  elseif op == "repeat_ability" then
    if p.who == "ahead" then add(seen, "ahead") end
  end
end

function Tags.forUnit(unitOrId, opts)
  opts = opts or {}
  local id, unit
  if type(unitOrId) == "string" then
    id = unitOrId
    unit = Units[id]
  else
    unit = unitOrId
    id = unit and unit.id
  end
  if not unit then return {} end

  local seen, extras = {}, {}
  local context = opts.context
  local commandContext = context == "commander" or opts.commander == true
  if commandContext then
    if unit.commandBonus then Tags.addEffect(seen, unit.commandBonus, { commander = true }) end
  else
    for _, e in ipairs(unit.effects or {}) do Tags.addEffect(seen, e, opts) end
    if opts.includeCommand and unit.commandBonus then Tags.addEffect(seen, unit.commandBonus, { commander = true }) end
  end
  if unit.type and TYPE[unit.type] then add(seen, "type_" .. unit.type) end
  if not commandContext then
    if unit.taunt then add(seen, "taunt") end
    if unit.strikeHighestHp then add(seen, "execute") end
  end
  if id and Whispers[id] and (opts.includeHidden or opts.includeWhispers) then add(seen, "whisper") end
  for _, tag in ipairs(unit.tags or {}) do
    if Tags.category[tag] then add(seen, tag) else extras[#extras + 1] = tag end
  end
  return materialize(seen, extras)
end

function Tags.forRelic(relicOrId, opts)
  opts = opts or {}
  local r = type(relicOrId) == "string" and Relics[relicOrId] or relicOrId
  if not r then return {} end
  local seen = {}
  local p = r.params or {}
  local op = r.op

  if op == "relic_more_dmg" then
    add(seen, "empower")
  elseif op == "relic_flat_hp" then
    add(seen, "growth")
  elseif op == "relic_dmg_reduce" then
    add(seen, "guard")
  elseif op == "relic_affliction_inc" then
    addFamily(seen, p.family)
  elseif op == "relic_few_units" then
    add(seen, "growth")
  elseif op == "relic_haste" then
    add(seen, "haste")
  elseif op == "relic_second_breath" then
    add(seen, "guard")
  elseif op == "relic_add_effect" and p.effect then
    Tags.addEffect(seen, p.effect, opts)
  elseif op == "relic_aura_stat" then
    add(seen, "aura")
    addTargetTags(seen, p.target)
    add(seen, STAT_TAGS[p.stat])
  elseif op == "relic_rainbow" then
    add(seen, "type")
    add(seen, "growth")
  elseif op == "relic_amplify_auras" then
    add(seen, "mimicry")
    add(seen, "aura")
  end

  return materialize(seen)
end

-- Backward-compatible affliction chips: only the unit's own board effects,
-- not commander text, type tags, or generic defense/offense tags.
function Tags.afflictionsForUnit(unit)
  if not unit then return {} end
  local seen = {}
  for _, e in ipairs(unit.effects or {}) do Tags.addEffect(seen, e) end
  local out = {}
  for _, id in ipairs(Tags.order) do
    if seen[id] and AFFLICTION[id] then out[#out + 1] = id end
  end
  return out
end

return Tags
