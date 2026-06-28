-- tools/scenarios/mechanics.lua
-- MODE P13 -- MECHANIC DIVERSITY AUDIT.
--
-- Data-only roster audit: classifies resolved unit effects by trigger/op/target
-- and by design axis. This answers "are too many monsters just on-hit
-- affliction appliers?" before we rewrite creature abilities.

local Common = require("tools.scenarios.common")
local Resolver = require("src.core.unit_resolver")
local Tags = require("src.core.tags")
local Units = require("src.data.units")

local BASIC_AFFLICTION = { poison = true, burn = true, bleed = true, rot = true, shock = true }
local AFFLICTION_OP = {
  poison = true, burn = true, bleed = true, rot = true, shock = true,
  spread_burn_on_death = true, spread_rot = true, convert_to_rot = true,
  convert_dot = true, grant_affliction_if_absent = true,
  aura_burn_dps = true, aura_poison_dps = true, aura_rot_growth = true, aura_grant_bleed = true,
}
local DEFENSE_OP = {
  shield_aura = true, shield_caster = true, aura_shield = true,
  thorns = true, regen = true, lifesteal = true, purge = true,
}
local OFFENSE_PAYOFF_OP = {
  execute = true, percent_hp_strike = true, crit = true, bonus_first = true,
  cleave = true, strip_shield = true, grant_vuln = true, heal_on_kill = true,
  frenzy_gain = true, scavenge_on_ally_death = true,
}
local SUMMON_OP = { summon = true }
local MIMIC_OP = { repeat_ability = true, amplify_auras = true }
local STRUCTURAL_OP = {
  aura_stat = true, grant_team = true, aura_per_unique_type = true,
  shield_aura = true, aura_shield = true,
  aura_burn_dps = true, aura_poison_dps = true, aura_rot_growth = true, aura_grant_bleed = true,
}
local RELATIVE_TARGET = {
  ahead = true, behind = true, above = true, below = true,
  neighbors = true, team = true,
  ["role:front"] = true, ["role:back"] = true, ["role:center"] = true,
}

local function add(set, key)
  if key and key ~= "" then set[key] = true end
end

local function list(set)
  local out = {}
  for k in pairs(set or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

local function bump(t, key, n)
  key = key or "none"
  t[key] = (t[key] or 0) + (n or 1)
end

local function has(set, key) return set and set[key] == true end

local function starts(s, prefix)
  return tostring(s or ""):sub(1, #prefix) == prefix
end

local function classifyEffect(effect, axes)
  if not effect then return end
  local op = effect.op
  local p = effect.params or {}
  local target = effect.target

  if AFFLICTION_OP[op] or p.family or p.from or p.to then add(axes, "affliction") end
  if DEFENSE_OP[op] or p.stat == "dmgReduce" or p.stat == "regen" or p.stat == "lifesteal" then add(axes, "defense") end
  if OFFENSE_PAYOFF_OP[op] then add(axes, "payoff") end
  if SUMMON_OP[op] then add(axes, "summon"); add(axes, "death") end
  if MIMIC_OP[op] then add(axes, "mimicry") end
  if STRUCTURAL_OP[op] then add(axes, "support") end
  if op == "aura_stat" and (p.stat == "haste" or p.stat == "multicast" or p.stat == "atkInc") then add(axes, "tempo_support") end
  if op == "grant_team" then add(axes, "team_rule") end
  if op == "aura_per_unique_type" or starts(target, "type:") then add(axes, "type_synergy") end
  if RELATIVE_TARGET[target] then add(axes, "position") end
  if target == "ahead" or target == "behind" or target == "above" or target == "below" then add(axes, "directional") end
  if op == "percent_hp_strike" or op == "strip_shield" or op == "execute" then add(axes, "anti_tank") end
  if op == "spread_burn_on_death" or op == "spread_rot" or p.spread then add(axes, "propagation") end
  if op == "convert_to_rot" or op == "convert_dot" or p.igniteAt or p.igniteBurst then add(axes, "conversion") end
  if p.aggravateMult then add(axes, "amplifier") end
end

local function effectSet(id, level, opts)
  local facts = Resolver.effectFactsFor(id, level, opts)
  local axes, ops, triggers, targets, tags = {}, {}, {}, {}, {}
  for _, fact in ipairs(facts) do
    add(ops, fact.op)
    add(triggers, fact.trigger)
    add(targets, fact.target or "self")
    for _, tag in ipairs(fact.tags or {}) do add(tags, tag) end
    classifyEffect(fact, axes)
  end
  return {
    count = #facts,
    axes = axes,
    ops = ops,
    triggers = triggers,
    targets = targets,
    tags = tags,
    facts = facts,
  }
end

local function isSimpleAfflictionOnly(effects)
  if effects.count == 0 then return false end
  for op in pairs(effects.ops) do
    if not BASIC_AFFLICTION[op] then return false end
  end
  return not has(effects.axes, "support")
    and not has(effects.axes, "position")
    and not has(effects.axes, "payoff")
    and not has(effects.axes, "summon")
    and not has(effects.axes, "mimicry")
    and not has(effects.axes, "type_synergy")
    and not has(effects.axes, "anti_tank")
end

local function isLowVariety(row)
  return row.effect_count > 0 and #row.board_axes <= 1 and row.level_authored == false
end

local rows = {}
local summary = {
  units = 0,
  authored_level_units = 0,
  level3_clutch_units = 0,
  simple_affliction_l1 = 0,
  low_variety_units = 0,
  no_board_effect_units = 0,
  axis_counts = {},
  op_counts = {},
  trigger_counts = {},
  target_counts = {},
  tag_counts = {},
  by_rank = {},
}

local simpleIds, lowVarietyIds, noLevelIds, noEffectIds = {}, {}, {}, {}

for _, id in ipairs(Units.order) do
  local u = Units[id]
  local l1 = effectSet(id, 1)
  local command = effectSet(id, 1, { context = "commander" })
  local tags = Tags.forUnit(id)
  local axes = {}
  for k in pairs(l1.axes) do axes[k] = true end
  if command.count > 0 then add(axes, "command") end
  for k in pairs(command.axes) do add(axes, "command_" .. k) end

  local deltas = Resolver.levelDeltaSummary(id)
  local levelAuthored, clutch3 = Resolver.hasAuthoredLevel(id), false
  for _, d in ipairs(deltas) do if d.level == 3 and d.clutch then clutch3 = true end end

  local row = {
    id = id,
    rank = u.rank or u.cost or 1,
    type = u.type,
    dot_family = Units.dotFamily and Units.dotFamily[id] or nil,
    effect_count = l1.count,
    command_effect_count = command.count,
    board_axes = list(l1.axes),
    axes = list(axes),
    ops = list(l1.ops),
    triggers = list(l1.triggers),
    targets = list(l1.targets),
    tags = tags,
    level_authored = levelAuthored,
    level3_clutch = clutch3,
    simple_affliction_l1 = isSimpleAfflictionOnly(l1),
  }
  row.low_variety = isLowVariety(row)
  rows[#rows + 1] = row

  summary.units = summary.units + 1
  if row.level_authored then summary.authored_level_units = summary.authored_level_units + 1 else noLevelIds[#noLevelIds + 1] = id end
  if row.level3_clutch then summary.level3_clutch_units = summary.level3_clutch_units + 1 end
  if row.simple_affliction_l1 then summary.simple_affliction_l1 = summary.simple_affliction_l1 + 1; simpleIds[#simpleIds + 1] = id end
  if row.low_variety then summary.low_variety_units = summary.low_variety_units + 1; lowVarietyIds[#lowVarietyIds + 1] = id end
  if row.effect_count == 0 then summary.no_board_effect_units = summary.no_board_effect_units + 1; noEffectIds[#noEffectIds + 1] = id end

  local rankKey = tostring(row.rank)
  summary.by_rank[rankKey] = summary.by_rank[rankKey] or { units = 0, simple_affliction_l1 = 0, low_variety_units = 0, level3_clutch_units = 0 }
  summary.by_rank[rankKey].units = summary.by_rank[rankKey].units + 1
  if row.simple_affliction_l1 then summary.by_rank[rankKey].simple_affliction_l1 = summary.by_rank[rankKey].simple_affliction_l1 + 1 end
  if row.low_variety then summary.by_rank[rankKey].low_variety_units = summary.by_rank[rankKey].low_variety_units + 1 end
  if row.level3_clutch then summary.by_rank[rankKey].level3_clutch_units = summary.by_rank[rankKey].level3_clutch_units + 1 end

  for _, axis in ipairs(row.axes) do bump(summary.axis_counts, axis) end
  for _, op in ipairs(row.ops) do bump(summary.op_counts, op) end
  for _, trigger in ipairs(row.triggers) do bump(summary.trigger_counts, trigger) end
  for _, target in ipairs(row.targets) do bump(summary.target_counts, target) end
  for _, tag in ipairs(row.tags) do bump(summary.tag_counts, tag) end
end

summary.authored_level_rate = summary.authored_level_units / summary.units
summary.level3_clutch_rate = summary.level3_clutch_units / summary.units
summary.simple_affliction_l1_rate = summary.simple_affliction_l1 / summary.units
summary.low_variety_rate = summary.low_variety_units / summary.units
summary.no_board_effect_rate = summary.no_board_effect_units / summary.units

local recommendations = {
  redesign_first = lowVarietyIds,
  simple_affliction_l1 = simpleIds,
  no_authored_level = noLevelIds,
  no_board_effect = noEffectIds,
  target_next_axes = {
    "position",
    "support",
    "payoff",
    "summon",
    "mimicry",
    "type_synergy",
  },
}

local payload = {
  mode = "mechanics",
  summary = summary,
  recommendations = recommendations,
  rows = rows,
}

local refSummary = {
  units = summary.units,
  authored_level_rate = summary.authored_level_rate,
  level3_clutch_rate = summary.level3_clutch_rate,
  simple_affliction_l1_rate = summary.simple_affliction_l1_rate,
  low_variety_rate = summary.low_variety_rate,
  no_board_effect_rate = summary.no_board_effect_rate,
  axis_counts = summary.axis_counts,
  top_redesign_first = { lowVarietyIds[1], lowVarietyIds[2], lowVarietyIds[3], lowVarietyIds[4], lowVarietyIds[5] },
}

local path = Common.writeReport("mechanics", payload, { refSummary = refSummary })
print(string.format("== P13 MECHANIC DIVERSITY : %d units ==", summary.units))
print(string.format("simple affliction L1 %.1f%% / low-variety %.1f%% / authored level %.1f%% / L3 clutch %.1f%%",
  summary.simple_affliction_l1_rate * 100,
  summary.low_variety_rate * 100,
  summary.authored_level_rate * 100,
  summary.level3_clutch_rate * 100))
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
