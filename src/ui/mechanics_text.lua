-- src/ui/mechanics_text.lua
-- Canonical player-facing wording for unit mechanics. This module converts
-- data descriptors (`effects` / `commandBonus`) into short keyword-token lines,
-- so monster cards do not drift into synonym-heavy prose.

local Units = require("src.data.units")
local Relics = require("src.data.relics")
local I18n = require("src.core.i18n")
local Pacing = require("src.run.pacing")

local T = I18n.t

local MechanicsText = {}

local LABEL = {
  poison = "Poison", bleed = "Bleed", burn = "Burn", rot = "Rot", shock = "Shock",
  contagion = "Contagion", propagation = "Propagate", conversion = "Convert", aggravate = "Aggravate",
  shield = "Shield", heal = "Heal", regen = "Regen", thorns = "Thorns", taunt = "Taunt", guard = "Guard",
  empower = "Empower", growth = "Growth", execute = "Execute", crit = "Crit", cleave = "Cleave",
  strip_shield = "Strip", vulnerable = "Vulnerable", weaken = "Weaken",
  aura = "Aura", commander = "Command", multicast = "Echo", haste = "Haste",
  ahead = "Ahead", behind = "Behind", above = "Above", below = "Below",
  summon = "Spawn", faint = "Faint", mimicry = "Echoform", type = "Type",
  type_flesh = "Flesh", type_bone = "Bone", type_arcane = "Arcane", type_abyss = "Abyss", type_order = "Order",
}

local TYPE_TAG = { flesh = "type_flesh", bone = "type_bone", arcane = "type_arcane", abyss = "type_abyss", order = "type_order" }

local TRIGGER_LABEL = {
  on_hit = "ON HIT",
  on_death = "ENEMY DEATH",
  on_kill = "ON KILL",
  on_attack = "ATTACK",
  on_attacked = "HIT BY",
  combat_start = "START",
  on_low_hp = "LOW HP",
  on_ally_death = "ALLY DEATH",
}

local TRIGGER_PATTERNS = {
  { "^On hit:%s*(.*)$", "ON HIT" },
  { "^Enemy death:%s*(.*)$", "ENEMY DEATH" },
  { "^Burned death:%s*(.*)$", "BURNED DEATH" },
  { "^Rotted death:%s*(.*)$", "ROTTED DEATH" },
  { "^Faint:%s*(.*)$", "FAINT" },
  { "^Ally death:%s*(.*)$", "ALLY DEATH" },
  { "^On death:%s*(.*)$", "DEATH" },
  { "^On kill:%s*(.*)$", "ON KILL" },
  { "^On attack:%s*(.*)$", "ATTACK" },
  { "^When hit:%s*(.*)$", "HIT BY" },
  { "^First attack:%s*(.*)$", "FIRST" },
  { "^Combat start:%s*(.*)$", "START" },
  { "^Every [%d%.]+s:%s*(.*)$", "TIMER" },
  { "^At [^:]+ HP:%s*(.*)$", "LOW HP" },
}

local function kw(id)
  return "[" .. id .. "|" .. (LABEL[id] or id) .. "]"
end

function MechanicsText.triggerLabel(trigger)
  return TRIGGER_LABEL[trigger] or "PASSIVE"
end

function MechanicsText.triggerLabelForEffect(effect)
  if not effect then return "PASSIVE" end
  if effect.trigger == "on_death" then
    if effect.op == "summon" then return "FAINT" end
    if effect.op == "spread_burn_on_death" then return "BURNED DEATH" end
    if effect.op == "spread_rot" then return "ROTTED DEATH" end
    return "ENEMY DEATH"
  end
  return MechanicsText.triggerLabel(effect.trigger)
end

function MechanicsText.extractTrigger(line)
  local s = tostring(line or "")
  for _, spec in ipairs(TRIGGER_PATTERNS) do
    local rest = s:match(spec[1])
    if rest then return spec[2], rest end
  end
  return nil, s
end

local function passiveTitle(unit)
  if not unit or not unit.id then return T("ui.ability") end
  local key = "unit." .. unit.id .. ".passive_name"
  local name = T(key)
  if name == key then return T("ui.ability") end
  return name
end

local function effectBlock(effect, title, opts)
  local lines = MechanicsText.effectLines(effect, opts)
  local label = MechanicsText.triggerLabelForEffect(effect)
  local clean = {}
  for _, line in ipairs(lines) do
    local extracted, rest = MechanicsText.extractTrigger(line)
    if extracted then
      if #clean == 0 or label == "PASSIVE" or label == "START" then label = extracted end
      line = rest
    end
    clean[#clean + 1] = line
  end
  if #clean == 0 then clean[1] = T("mech.none") end
  return {
    trigger = label,
    triggerId = effect and effect.trigger,
    op = effect and effect.op,
    title = title or T("ui.ability"),
    lines = clean,
  }
end

local function appendBlock(out, block)
  local last = out[#out]
  if last and block and last.trigger == block.trigger and last.title == block.title then
    for _, line in ipairs(block.lines or {}) do last.lines[#last.lines + 1] = line end
  elseif block then
    out[#out + 1] = block
  end
end

local function pct(v, opts)
  opts = opts or {}
  local n = math.floor((tonumber(v) or 0) * 100 + 0.5)
  local s = tostring(n) .. "%"
  if opts.signed and n >= 0 then s = "+" .. s end
  return s
end

local function secs(frames)
  local v = (tonumber(frames) or 0) / 60
  if math.abs(v - math.floor(v + 0.5)) < 0.05 then return tostring(math.floor(v + 0.5)) end
  return string.format("%.1f", v)
end

local function number(v)
  if v == nil then return "0" end
  if type(v) == "number" and math.abs(v - math.floor(v + 0.5)) < 0.001 then return tostring(math.floor(v + 0.5)) end
  return tostring(v)
end

local function positive(v)
  v = tonumber(v)
  return v and v > 0
end

local function familyToken(family)
  if LABEL[family] then return kw(family) end
  return tostring(family or "affliction")
end

local function targetText(target)
  if not target or target == "team" then return T("mech.target.team") end
  if target == "neighbors" then return T("mech.target.neighbors") end
  if target == "ahead" or target == "role:front" then return T("mech.target.ahead", { ahead = kw("ahead") }) end
  if target == "behind" or target == "role:back" then return T("mech.target.behind", { behind = kw("behind") }) end
  if target == "above" then return T("mech.target.above", { above = kw("above") }) end
  if target == "below" then return T("mech.target.below", { below = kw("below") }) end
  if target == "role:center" then return T("mech.target.center") end
  if target == "tier:1" then return T("mech.target.tier1") end
  if target == "level:1" then return T("mech.target.level1") end
  local ty = target:match("^type:(%w+)$")
  if ty then return T("mech.target.type", { type = kw(TYPE_TAG[ty] or "type") }) end
  return tostring(target)
end

local function statText(stat, value)
  if stat == "atkInc" then return T("mech.stat.empower", { empower = kw("empower"), value = pct(value, { signed = true }) }) end
  if stat == "dmgReduce" then return T("mech.stat.guard", { guard = kw("guard"), value = pct(value) }) end
  if stat == "haste" then return T("mech.stat.haste", { haste = kw("haste"), value = pct(value, { signed = true }) }) end
  if stat == "multicast" then return T("mech.stat.echo", { echo = kw("multicast"), value = number(value) }) end
  if stat == "poisonInc" then return T("mech.stat.affliction", { tag = kw("poison"), value = pct(value, { signed = true }) }) end
  if stat == "burnInc" then return T("mech.stat.affliction", { tag = kw("burn"), value = pct(value, { signed = true }) }) end
  if stat == "bleedInc" then return T("mech.stat.affliction", { tag = kw("bleed"), value = pct(value, { signed = true }) }) end
  if stat == "rotInc" then return T("mech.stat.affliction", { tag = kw("rot"), value = pct(value, { signed = true }) }) end
  if stat == "regen" then return T("mech.stat.regen", { regen = kw("regen"), value = number(value) }) end
  if stat == "lifesteal" then return T("mech.stat.heal", { heal = kw("heal"), value = pct(value) }) end
  if stat == "statInc" then return T("mech.stat.growth", { growth = kw("growth"), value = pct(value, { signed = true }) }) end
  return tostring(stat or "stat") .. " " .. tostring(value or "")
end

local function addGrantTeamLines(out, params)
  local p = params or {}
  if p.burnNoDecay then out[#out + 1] = T("mech.grant.burn_no_decay", { burn = kw("burn") }) end
  if p.bleedNoExpire then out[#out + 1] = T("mech.grant.bleed_no_expire", { bleed = kw("bleed") }) end
  if p.poisonNoCap or p.poisonDurBonus then
    if p.poisonNoCap and p.poisonDurBonus then
      out[#out + 1] = T("mech.grant.poison_no_cap", { poison = kw("poison"), dur = secs(p.poisonDurBonus) })
    elseif p.poisonNoCap then
      out[#out + 1] = T("mech.grant.poison_no_cap_base", { poison = kw("poison") })
    else
      out[#out + 1] = T("mech.grant.poison_duration", { poison = kw("poison"), dur = secs(p.poisonDurBonus) })
    end
  end
  if p.shockChain then out[#out + 1] = T("mech.grant.shock_chain", { shock = kw("shock"), propagation = kw("propagation"), value = number(p.shockChain) }) end
  if p.rotEnemies then
    local r = p.rotEnemies
    out[#out + 1] = T("mech.grant.rot_enemies", { rot = kw("rot"), base = number(r.base or 1), dur = secs(r.dur or 0) })
  end
  if p.slowEnemies then out[#out + 1] = T("mech.grant.slow_enemies", { bleed = kw("bleed"), value = pct(p.slowEnemies) }) end
  if p.plagueAmp then out[#out + 1] = T("mech.grant.plague_amp", { aggravate = kw("aggravate"), value = pct(p.plagueAmp, { signed = true }) }) end
  if p.stripEnemyShield then out[#out + 1] = T("mech.grant.strip_enemy_shield", { strip = kw("strip_shield"), shield = kw("shield"), value = pct(p.stripEnemyShield) }) end
  if p.markEnemiesVuln then out[#out + 1] = T("mech.grant.vulnerable", { vulnerable = kw("vulnerable"), value = pct(p.markEnemiesVuln, { signed = true }) }) end
  if p.teamExecute then
    out[#out + 1] = T("mech.grant.team_execute", {
      execute = kw("execute"),
      bonus = pct(p.teamExecute.bonus, { signed = true }),
      threshold = pct(p.teamExecute.threshold),
    })
  end
  if p.pierceHeal then out[#out + 1] = T("mech.grant.pierce_heal", { rot = kw("rot"), value = pct(p.pierceHeal) }) end
  if p.invulnT then out[#out + 1] = T("mech.grant.invuln", { shield = kw("shield"), dur = secs(p.invulnT) }) end
end

function MechanicsText.effectLines(effect, opts)
  opts = opts or {}
  local out = {}
  if not effect then return out end
  local p = effect.params or {}
  local op = effect.op

  if op == "poison" then
    if positive(p.dps or p.base) then
      out[#out + 1] = T("mech.poison", { poison = kw("poison"), dps = number(p.dps or p.base), dur = secs(p.dur) })
    else
      out[#out + 1] = T("mech.poison_utility", { poison = kw("poison"), dur = secs(p.dur) })
    end
    if p.weaken then out[#out + 1] = T("mech.weaken", { weaken = kw("weaken"), value = pct(p.weaken) }) end
    if p.spread then out[#out + 1] = T("mech.contagion", { contagion = kw("contagion"), poison = kw("poison") }) end
    if p.shieldEat then out[#out + 1] = T("mech.strip_poison", { strip = kw("strip_shield"), shield = kw("shield"), value = pct(p.shieldEat) }) end
    if p.igniteAt or p.igniteBurst then out[#out + 1] = T("mech.convert_poison_burn", { conversion = kw("conversion"), poison = kw("poison"), burn = kw("burn") }) end
  elseif op == "bleed" then
    if positive(p.dps) then
      out[#out + 1] = T("mech.bleed", { bleed = kw("bleed"), dps = number(p.dps), dur = secs(p.dur), slow = pct(p.slowPct or 0) })
    else
      out[#out + 1] = T("mech.bleed_slow", { bleed = kw("bleed"), dur = secs(p.dur), slow = pct(p.slowPct or 0) })
    end
    if p.aggravateMult then out[#out + 1] = T("mech.bleed_aggravate", { aggravate = kw("aggravate"), mult = number(p.aggravateMult) }) end
  elseif op == "burn" then
    out[#out + 1] = T("mech.burn", { burn = kw("burn"), dps = number(p.dps), dur = secs(p.dur) })
    if p.refresh then out[#out + 1] = T("mech.burn_refresh", { burn = kw("burn") }) end
    if p.decayPct then out[#out + 1] = T("mech.burn_decay", { burn = kw("burn"), value = pct(p.decayPct) }) end
  elseif op == "rot" then
    out[#out + 1] = T("mech.rot", {
      rot = kw("rot"), base = number(p.base), growth = number(p.growth or p.passiveRamp or 0),
      cap = number(p.capDps or 0), dur = secs(p.dur),
    })
    if positive(p.maxHpFrac) then out[#out + 1] = T("mech.rot_maxhp", { rot = kw("rot"), maxhp = pct(p.maxHpFrac) }) end
  elseif op == "shock" then
    out[#out + 1] = T("mech.shock", { shock = kw("shock"), add = number(p.add or 1), cap = number(p.cap or 0) })
  elseif op == "regen" then
    out[#out + 1] = T("mech.regen", { regen = kw("regen"), value = number(p.value) })
  elseif op == "lifesteal" then
    out[#out + 1] = T("mech.lifesteal", { heal = kw("heal"), value = pct(p.frac) })
  elseif op == "heal_on_kill" then
    out[#out + 1] = T("mech.heal_on_kill", { heal = kw("heal"), value = number(p.value) })
  elseif op == "thorns" then
    out[#out + 1] = T("mech.thorns", { thorns = kw("thorns"), value = number(p.value) })
  elseif op == "purge" then
    out[#out + 1] = T("mech.purge", { heal = kw("heal"), threshold = pct(p.threshold), family = familyToken(p.family), stacks = number(p.maxStacks) })
  elseif op == "bonus_first" then
    out[#out + 1] = T("mech.bonus_first", { crit = kw("crit"), value = number(p.value) })
  elseif op == "execute" then
    out[#out + 1] = T("mech.execute", { execute = kw("execute"), bonus = pct(p.bonus, { signed = true }), threshold = pct(p.threshold) })
  elseif op == "percent_hp_strike" then
    out[#out + 1] = T("mech.percent_hp", { execute = kw("execute"), frac = pct(p.frac), cap = number(p.cap) })
  elseif op == "cleave" then
    out[#out + 1] = T("mech.cleave", { cleave = kw("cleave"), value = pct(p.frac) })
  elseif op == "strip_shield" then
    out[#out + 1] = T("mech.strip_shield", { strip = kw("strip_shield"), shield = kw("shield"), value = pct(p.frac) })
  elseif op == "grant_vuln" then
    out[#out + 1] = T("mech.vulnerable", { vulnerable = kw("vulnerable"), value = pct(p.value, { signed = true }), dur = secs(p.dur) })
  elseif op == "shield_aura" then
    out[#out + 1] = T("mech.shield_aura", { aura = kw("aura"), target = targetText(effect.target), shield = kw("shield"), value = number(p.value) })
  elseif op == "shield_caster" then
    out[#out + 1] = T("mech.shield_caster", { target = targetText(effect.target), shield = kw("shield"), value = number(p.value), cd = Pacing.formatCooldown(p.cd) })
  elseif op == "aura_shield" then
    out[#out + 1] = T("mech.aura_shield", { aura = kw("aura"), target = targetText(effect.target), shield = kw("shield"), value = pct(p.valueInc or 0, { signed = true }), cdr = pct(p.cdr or 0) })
  elseif op == "aura_burn_dps" then
    out[#out + 1] = T("mech.aura_affliction", { aura = kw("aura"), target = targetText(effect.target), tag = kw("burn"), value = pct(p.inc or 0, { signed = true }) })
  elseif op == "aura_poison_dps" then
    out[#out + 1] = T("mech.aura_affliction", { aura = kw("aura"), target = targetText(effect.target), tag = kw("poison"), value = pct(p.inc or 0, { signed = true }) })
  elseif op == "aura_rot_growth" then
    out[#out + 1] = T("mech.aura_rot_growth", { aura = kw("aura"), target = targetText(effect.target), rot = kw("rot"), value = number(p.bonus or 0) })
  elseif op == "aura_grant_bleed" then
    out[#out + 1] = T("mech.aura_grant_bleed", { aura = kw("aura"), target = targetText(effect.target), bleed = kw("bleed"), dps = number(p.dps), dur = secs(p.dur) })
  elseif op == "aura_stat" then
    local key = opts.commander and "mech.command_stat" or "mech.aura_stat"
    out[#out + 1] = T(key, {
      aura = kw("aura"), commander = kw("commander"),
      target = targetText(effect.target), stat = statText(p.stat, p.value),
    })
  elseif op == "grant_team" then
    addGrantTeamLines(out, p)
  elseif op == "grant_affliction_if_absent" then
    out[#out + 1] = T("mech.grant_affliction_if_absent", { tag = familyToken(p.family), dps = number(p.dps), dur = secs(p.dur) })
  elseif op == "frenzy_gain" then
    out[#out + 1] = T("mech.frenzy_gain", { growth = kw("growth"), value = pct(p.per or 0, { signed = true }), cap = number(p.cap or 0) })
  elseif op == "spread_burn_on_death" then
    out[#out + 1] = T("mech.spread_burn", { propagation = kw("propagation"), burn = kw("burn"), value = pct(p.frac or 0), dur = secs(p.dur or 0) })
    if p.alsoPoison then out[#out + 1] = T("mech.spread_also_poison", { propagation = kw("propagation"), poison = kw("poison") }) end
  elseif op == "spread_rot" then
    out[#out + 1] = T("mech.spread_rot", { propagation = kw("propagation"), rot = kw("rot"), base = number(p.base), dur = secs(p.dur) })
  elseif op == "convert_to_rot" then
    out[#out + 1] = T("mech.convert_to_rot", { conversion = kw("conversion"), bleed = kw("bleed"), rot = kw("rot"), base = number(p.base), cap = number(p.capDps or 0) })
  elseif op == "summon" then
    out[#out + 1] = T("mech.summon", { summon = kw("summon"), token = T("unit." .. tostring(p.token) .. ".name") })
  elseif op == "scavenge_on_ally_death" then
    out[#out + 1] = T("mech.scavenge", { growth = kw("growth"), value = number(p.value), stat = tostring(p.stat or "stat"), cap = number(p.cap) })
  elseif op == "repeat_ability" then
    out[#out + 1] = T("mech.repeat_ability", { mimicry = kw("mimicry"), target = targetText(p.who == "ahead" and "ahead" or "neighbors") })
  elseif op == "amplify_auras" then
    out[#out + 1] = T("mech.amplify_auras", { mimicry = kw("mimicry"), aura = kw("aura"), value = pct(p.frac, { signed = true }) })
  elseif op == "aura_per_unique_type" then
    out[#out + 1] = T("mech.aura_per_unique_type", { type = kw("type"), growth = kw("growth"), dmg = number(p.dmgPerType), hp = number(p.hpPerType) })
  else
    out[#out + 1] = T("mech.unknown", { op = tostring(op or "?") })
  end

  return out
end

function MechanicsText.unitLines(unitOrId)
  local unit = type(unitOrId) == "string" and Units[unitOrId] or unitOrId
  if not unit then return {} end
  local out = {}
  if unit.taunt then out[#out + 1] = T("mech.unit_taunt", { taunt = kw("taunt") }) end
  for _, effect in ipairs(unit.effects or {}) do
    local lines = MechanicsText.effectLines(effect)
    for _, line in ipairs(lines) do out[#out + 1] = line end
  end
  if unit.strikeHighestHp then out[#out + 1] = T("mech.unit_highest_hp", { execute = kw("execute") }) end
  if #out == 0 then out[#out + 1] = T("mech.none") end
  return out
end

function MechanicsText.unitBlocks(unitOrId)
  local unit = type(unitOrId) == "string" and Units[unitOrId] or unitOrId
  if not unit then return {} end
  local title = passiveTitle(unit)
  local out = {}
  if unit.taunt then
    appendBlock(out, {
      trigger = "PASSIVE",
      title = title,
      lines = { T("mech.unit_taunt", { taunt = kw("taunt") }) },
    })
  end
  for _, effect in ipairs(unit.effects or {}) do
    appendBlock(out, effectBlock(effect, title))
  end
  if unit.strikeHighestHp then
    appendBlock(out, {
      trigger = "PASSIVE",
      title = title,
      lines = { T("mech.unit_highest_hp", { execute = kw("execute") }) },
    })
  end
  if #out == 0 then
    out[#out + 1] = { trigger = "PASSIVE", title = title, lines = { T("mech.none") } }
  end
  return out
end

function MechanicsText.commandLines(unitOrId)
  local unit = type(unitOrId) == "string" and Units[unitOrId] or unitOrId
  if not unit or not unit.commandBonus then return {} end
  local out = {}
  for _, line in ipairs(MechanicsText.effectLines(unit.commandBonus, { commander = true })) do
    if line:find("[commander|", 1, true) then
      out[#out + 1] = line
    else
      out[#out + 1] = T("mech.command_wrap", { commander = kw("commander"), line = line })
    end
  end
  return out
end

function MechanicsText.commandBlock(unitOrId)
  local unit = type(unitOrId) == "string" and Units[unitOrId] or unitOrId
  if not unit or not unit.commandBonus then return nil end
  local block = effectBlock(unit.commandBonus, T("ui.command_prefix"), { commander = true })
  block.trigger = "COMMAND"
  for i, line in ipairs(block.lines or {}) do
    block.lines[i] = line:gsub("^%[commander|Command%]%s*%-%s*", "")
  end
  return block
end

local function relic(idOrRelic)
  if type(idOrRelic) == "string" then return Relics[idOrRelic] end
  return idOrRelic
end

local function addEffectLines(out, effect)
  for _, line in ipairs(MechanicsText.effectLines(effect or {})) do
    out[#out + 1] = line
  end
end

function MechanicsText.relicLines(idOrRelic)
  local r = relic(idOrRelic)
  if not r then return {} end
  local out, p = {}, r.params or {}
  local op = r.op

  if op == "relic_more_dmg" then
    out[#out + 1] = "Team gains " .. kw("empower") .. " " .. pct(p.mult, { signed = true }) .. " attack damage."
  elseif op == "relic_flat_hp" then
    out[#out + 1] = "Team gains " .. kw("growth") .. " +" .. number(p.value) .. " HP."
  elseif op == "relic_dmg_reduce" then
    out[#out + 1] = "Team gains " .. kw("guard") .. " -" .. pct(p.frac) .. " attack damage taken."
  elseif op == "relic_affliction_inc" then
    out[#out + 1] = "Team " .. familyToken(p.family) .. " deals " .. pct(p.inc, { signed = true }) .. " damage."
  elseif op == "relic_few_units" then
    out[#out + 1] = "At " .. number(p.max or 3) .. " or fewer units: team gains " .. kw("growth") .. " "
      .. pct(p.dmgInc, { signed = true }) .. " damage and " .. pct(p.hpInc, { signed = true }) .. " HP."
  elseif op == "relic_haste" then
    out[#out + 1] = "Team gains " .. kw("haste") .. " " .. pct(p.value, { signed = true }) .. "."
  elseif op == "relic_second_breath" then
    out[#out + 1] = "Each ally gains " .. kw("guard") .. ": survive one lethal hit at 1 HP."
  elseif op == "relic_add_effect" and p.effect then
    addEffectLines(out, p.effect)
  elseif op == "relic_aura_stat" then
    out[#out + 1] = targetText(p.target or "team") .. ": " .. statText(p.stat, p.value) .. "."
  elseif op == "relic_rainbow" then
    out[#out + 1] = kw("type") .. ": team gains " .. kw("growth") .. " +" .. number(p.dmgPerType)
      .. " damage and +" .. number(p.hpPerType) .. " HP per unique type."
  elseif op == "relic_amplify_auras" then
    local scope = p.dotOnly and "affliction " or ""
    out[#out + 1] = kw("mimicry") .. ": " .. scope .. kw("aura") .. " bonuses gain "
      .. pct(p.frac, { signed = true }) .. "."
  elseif r.runOp == "shop_xp" then
    out[#out + 1] = "Shop gains +" .. number(p.amount) .. " XP immediately."
  elseif r.runOp == "shop_tier_up" then
    out[#out + 1] = "Shop tier increases by +1."
  elseif r.runOp == "shop_tier_down" then
    out[#out + 1] = "Shop offers roll one tier lower."
  elseif r.runOp == "shop_freeze" then
    out[#out + 1] = "Unlock +" .. number(p.slots or 1) .. " shop freeze slot."
  elseif r.eco and r.eco.carryover then
    out[#out + 1] = "Gold carries between rounds; gain interest up to +" .. number(r.eco.interestCap or 0) .. "."
  elseif r.eco and r.eco.onWin then
    out[#out + 1] = "On victory: gain +" .. number(r.eco.onWin) .. " gold next round."
  elseif r.eco and r.eco.perRound then
    out[#out + 1] = "Each round: gain +" .. number(r.eco.perRound) .. " gold."
  elseif r.eco and r.eco.sellFrac then
    out[#out + 1] = "Selling a unit refunds " .. pct(r.eco.sellFrac) .. " of its cost."
  else
    out[#out + 1] = T("relic." .. tostring(r.id) .. ".effect")
  end

  return out
end

return MechanicsText
