-- src/lab/coherence.lua
-- Pure analysis layer for the balance lab: derive player-intent synergies from
-- resolved unit facts, then score teams separately from combat win rate.
-- No love.*, no RNG, no simulation mutation.

local Units = require("src.data.units")
local Resolver = require("src.core.unit_resolver")
local RunState = require("src.run.state")
local Economy = require("src.run.economy")
local Relics = require("src.data.relics")

local Coherence = {}

local FAMILIES = { "poison", "burn", "bleed", "rot", "shock" }
local FAMILY_SET = {}
for _, id in ipairs(FAMILIES) do FAMILY_SET[id] = true end

local LEVEL_COPIES = { 1, 3, 9 }
local DEFAULT_COST = 3
local DEFAULT_VARIANT = "baseline"
local ECON_ALIASES = {
  current = "baseline",
  sap_like = "sap_cost",
  curved_income = "early_curve",
}
Coherence.ECON_VARIANTS = Economy.profiles
Coherence.ECON_ORDER = Economy.order

local function resolveEconomyProfile(id)
  local key = ECON_ALIASES[id or DEFAULT_VARIANT] or id or DEFAULT_VARIANT
  return Economy.resolve(key), key
end

local function clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function r3(x)
  return math.floor((x or 0) * 1000 + 0.5) / 1000
end

local function add(set, key, amount)
  if not key then return end
  set[key] = (set[key] or 0) + (amount or 1)
end

local function has(set, key)
  return (set and set[key] or 0) > 0
end

local function listFromSet(set, order)
  local out, seen = {}, {}
  for _, id in ipairs(order or {}) do
    if has(set, id) then
      out[#out + 1] = id
      seen[id] = true
    end
  end
  local extra = {}
  for id in pairs(set or {}) do
    if not seen[id] and set[id] and set[id] ~= 0 then extra[#extra + 1] = id end
  end
  table.sort(extra)
  for _, id in ipairs(extra) do out[#out + 1] = id end
  return out
end

local function unitCost(id, variant)
  local u = Units[id]
  if not u then return DEFAULT_COST end
  return Economy.unitCost(variant, u, DEFAULT_COST)
end

local function factTargetIsNeighbor(fact)
  return fact and fact.target == "neighbors"
end

local function addTarget(profile, fact)
  if not factTargetIsNeighbor(fact) then return end
  add(profile.targets, "neighbors")
end

local function addStat(profile, stat, amount)
  if stat == "poisonInc" then add(profile.amplifies, "poison", amount)
  elseif stat == "burnInc" then add(profile.amplifies, "burn", amount)
  elseif stat == "bleedInc" then add(profile.amplifies, "bleed", amount)
  elseif stat == "rotInc" then add(profile.amplifies, "rot", amount)
  elseif stat == "haste" then add(profile.supports, "haste", amount)
  elseif stat == "multicast" then add(profile.supports, "multicast", amount)
  elseif stat == "atkInc" then add(profile.amplifies, "damage", amount)
  elseif stat == "dmgReduce" then add(profile.supports, "guard", amount)
  elseif stat == "regen" or stat == "lifesteal" then add(profile.supports, "sustain", amount)
  elseif stat == "statInc" then add(profile.supports, "growth", amount)
  end
end

local function deriveFact(into, fact)
  local op = fact.op
  local p = fact.values or {}
  addTarget(into, fact)
  if FAMILY_SET[op] then
    local active = (p.dps and p.dps > 0) or (p.base and p.base > 0) or (p.add and p.add > 0)
    add(active and into.produces or into.utilities, op)
    if p.spread then add(into.propagates, op) end
    if p.weaken and p.weaken > 0 then
      add(into.debuffs, "weaken")
      add(into.amplifies, "damage", p.weaken)
    end
    if p.slowPct and p.slowPct > 0 then add(into.debuffs, "slow") end
    if p.aggravateMult then add(into.amplifies, op, p.aggravateMult - 1) end
    if p.shieldEat then add(into.counters, "shield") end
    return
  end

  if op == "aura_poison_dps" then add(into.amplifies, "poison", p.inc or 0.5)
  elseif op == "aura_burn_dps" then add(into.amplifies, "burn", p.inc or 0.5)
  elseif op == "aura_rot_growth" then add(into.amplifies, "rot", p.bonus or 1)
  elseif op == "aura_grant_bleed" then
    add(into.grants, "bleed", p.dps or 1)
    add(into.amplifies, "bleed", 0.3)
  elseif op == "shield_aura" then
    add(into.grants, "shield", p.value or 1)
    add(into.supports, "shield", p.value or 1)
  elseif op == "shield_caster" then
    add(into.produces, "shield", p.value or 1)
    add(into.supports, "shield", p.value or 1)
  elseif op == "aura_shield" then
    add(into.amplifies, "shield", (p.valueInc or 0) + (p.cdr or 0) + (p.reflect or 0) + (p.radius and 0.25 or 0))
    add(into.supports, "shield", 1)
  elseif op == "aura_stat" then
    addStat(into, p.stat, p.value or p.inc or 1)
  elseif op == "grant_vuln" then
    add(into.debuffs, "vulnerable", p.value or 0.15)
    add(into.amplifies, "damage", p.value or 0.15)
  elseif op == "grant_affliction_if_absent" then
    add(into.produces, p.family)
  elseif op == "execute" or op == "teamExecute" then
    add(into.supports, "execute")
    add(into.amplifies, "damage", p.bonus or 0.25)
  elseif op == "percent_hp_strike" then
    add(into.supports, "removal")
    add(into.counters, "tank")
  elseif op == "cleave" then
    add(into.supports, "cleave")
    add(into.amplifies, "damage", p.frac or 0.1)
  elseif op == "thorns" then
    add(into.supports, "guard")
    add(into.amplifies, "damage", 0.2)
  elseif op == "frenzy_gain" then
    add(into.supports, "growth")
  elseif op == "summon" then
    add(into.supports, "summon")
    add(into.supports, "faint")
  elseif op == "scavenge_on_ally_death" then
    add(into.supports, "growth")
    add(into.supports, "faint_payoff")
  elseif op == "spread_burn_on_death" then
    add(into.propagates, "burn", p.frac or 0.7)
    if p.alsoPoison then add(into.propagates, "poison", 0.5) end
  elseif op == "spread_rot" then
    add(into.propagates, "rot", p.frac or 0.7)
  elseif op == "convert_to_rot" or op == "convert_dot" then
    add(into.converts, p.from or "bleed")
    add(into.produces, p.to or "rot", 0.5)
  elseif op == "strip_shield" then
    add(into.counters, "shield")
  elseif op == "grant_team" then
    if p.burnNoDecay then add(into.transforms, "burn") end
    if p.bleedNoExpire then add(into.transforms, "bleed") end
    if p.poisonNoCap or p.poisonDurBonus then add(into.transforms, "poison") end
    if p.shockChain then add(into.propagates, "shock") end
    if p.rotEnemies then add(into.produces, "rot") end
    if p.slowEnemies then add(into.debuffs, "slow") end
    if p.plagueAmp then
      add(into.amplifies, "poison", p.plagueAmp)
      add(into.amplifies, "burn", p.plagueAmp)
      add(into.amplifies, "bleed", p.plagueAmp)
      add(into.amplifies, "rot", p.plagueAmp)
    end
    if p.stripEnemyShield then add(into.counters, "shield") end
    if p.markEnemiesVuln then
      add(into.debuffs, "vulnerable", p.markEnemiesVuln)
      add(into.amplifies, "damage", p.markEnemiesVuln)
    end
    if p.teamExecute then add(into.supports, "execute") end
    if p.invulnT then add(into.supports, "guard") end
  elseif op == "repeat_ability" then
    add(into.supports, "mimicry")
    if p.who then add(into.targets, p.who) end
  elseif op == "amplify_auras" then
    add(into.supports, "aura")
  end
end

local function newBucket()
  return {
    produces = {}, amplifies = {}, grants = {}, propagates = {}, transforms = {},
    converts = {}, counters = {}, debuffs = {}, utilities = {}, supports = {},
    targets = {},
  }
end

local function mergeBucket(dst, src)
  for key, set in pairs(src) do
    dst[key] = dst[key] or {}
    for id, amount in pairs(set) do add(dst[key], id, amount) end
  end
end

local function hasAnyFamily(profile)
  for _, f in ipairs(FAMILIES) do
    if has(profile.produces, f) or has(profile.amplifies, f) or has(profile.grants, f)
      or has(profile.propagates, f) or has(profile.transforms, f) then
      return true
    end
  end
  return false
end

local function primaryFamily(profile)
  local best, bestScore = Units.dotFamily and Units.dotFamily[profile.id] or nil, 0
  for _, f in ipairs(FAMILIES) do
    local score = (profile.produces[f] or 0) * 2
      + (profile.amplifies[f] or 0)
      + (profile.grants[f] or 0)
      + (profile.propagates[f] or 0)
      + (profile.transforms[f] or 0)
    if score > bestScore then best, bestScore = f, score end
  end
  return best
end

function Coherence.profileFor(id, level)
  local u = Units[id]
  if not u then return nil end
  level = Resolver.clampLevel(level or 1)
  local profile = newBucket()
  profile.id = id
  profile.level = level
  profile.rank = u.rank or 1
  profile.cost = u.cost or profile.rank
  profile.type = u.type
  profile.facts = Resolver.effectFactsFor(id, level)
  profile.commandFacts = Resolver.effectFactsFor(id, level, { context = "commander" })
  profile.command = newBucket()
  profile.levelDeltas = Resolver.levelDeltaSummary(id)
  profile.authoredLevel = Resolver.hasAuthoredLevel(id)
  profile.clutch = false
  profile.transformative = false

  for _, fact in ipairs(profile.facts) do deriveFact(profile, fact) end
  for _, fact in ipairs(profile.commandFacts) do deriveFact(profile.command, fact) end
  for _, delta in ipairs(profile.levelDeltas) do
    if delta.level <= level then
      if delta.clutch then profile.clutch = true end
      if delta.transformative then profile.transformative = true end
    end
  end

  profile.frontline = u.taunt == true or (u.aggro or 0) >= 40
  if profile.frontline then add(profile.supports, "guard", u.taunt and 0.35 or 0.25) end
  profile.hasOnHit = false
  for _, fact in ipairs(profile.facts) do
    if fact.trigger == "on_hit" then profile.hasOnHit = true end
  end
  profile.family = primaryFamily(profile)
  if profile.frontline or has(profile.supports, "shield") or has(profile.supports, "guard") then
    profile.role = "tank"
  elseif profile.family then
    profile.role = profile.family
  elseif hasAnyFamily(profile) then
    profile.role = "support"
  else
    profile.role = "bruiser"
  end

  profile.summary = {
    produces = listFromSet(profile.produces, FAMILIES),
    amplifies = listFromSet(profile.amplifies, FAMILIES),
    grants = listFromSet(profile.grants, FAMILIES),
    propagates = listFromSet(profile.propagates, FAMILIES),
    transforms = listFromSet(profile.transforms, FAMILIES),
    commandAmplifies = listFromSet(profile.command.amplifies, FAMILIES),
    commandTransforms = listFromSet(profile.command.transforms, FAMILIES),
  }
  return profile
end

function Coherence.profileForRelic(id)
  local relic = type(id) == "table" and id or Relics[id]
  if not relic then return nil end
  local profile = newBucket()
  profile.id = "relic:" .. relic.id
  profile.relicId = relic.id
  profile.role = "relic"
  profile.relicTarget = relic.params and relic.params.target or nil
  local op, p = relic.op, relic.params or {}

  if op == "relic_affliction_inc" then
    add(profile.amplifies, p.family, p.inc or 0.2)
  elseif op == "relic_aura_stat" then
    addStat(profile, p.stat, p.value or 1)
  elseif op == "relic_more_dmg" then
    add(profile.amplifies, "damage", p.mult or 0.1)
  elseif op == "relic_flat_hp" or op == "relic_dmg_reduce" then
    add(profile.supports, "guard", p.value or p.frac or 1)
  elseif op == "relic_haste" then
    add(profile.supports, "haste", p.value or 0.1)
  elseif op == "relic_few_units" then
    add(profile.supports, "growth", (p.dmgInc or 0) + (p.hpInc or 0))
    add(profile.amplifies, "damage", p.dmgInc or 0)
    add(profile.supports, "guard", p.hpInc or 0)
  elseif op == "relic_rainbow" then
    add(profile.supports, "growth", 1)
    add(profile.supports, "type_mix", 1)
  elseif op == "relic_amplify_auras" then
    add(profile.supports, "aura", p.frac or 0.15)
    if p.dotOnly then
      for _, f in ipairs(FAMILIES) do add(profile.amplifies, f, p.frac or 0.15) end
    end
  elseif op == "relic_second_breath" then
    add(profile.supports, "guard", 1)
  elseif op == "relic_add_effect" and p.effect then
    deriveFact(profile, { op = p.effect.op, trigger = p.effect.trigger, values = p.effect.params or {} })
  elseif relic.runOp then
    add(profile.supports, "economy", 1)
  elseif relic.eco then
    add(profile.supports, "economy", 1)
  end

  profile.summary = {
    amplifies = listFromSet(profile.amplifies, FAMILIES),
    produces = listFromSet(profile.produces, FAMILIES),
    propagates = listFromSet(profile.propagates, FAMILIES),
    transforms = listFromSet(profile.transforms, FAMILIES),
    supports = listFromSet(profile.supports),
  }
  return profile
end

local function asProfile(x)
  if type(x) == "table" and x.produces then return x end
  if type(x) == "table" then return Coherence.profileFor(x.id, x.level or 1) end
  return Coherence.profileFor(x, 1)
end

local function edge(out, from, to, kind, family, weight, reason, placement)
  if not (from and to) or from.id == to.id and kind == "family_stack" then return end
  out[#out + 1] = {
    from = from.id,
    to = to.id,
    kind = kind,
    family = family,
    weight = weight,
    reason = reason,
    requiresPlacement = placement == true,
  }
end

function Coherence.edgesForPair(a, b)
  a, b = asProfile(a), asProfile(b)
  if not (a and b) then return {} end
  local out = {}

  for _, f in ipairs(FAMILIES) do
    if has(a.amplifies, f) and has(b.produces, f) then
      edge(out, a, b, "producer_amplifier", f, 1.6,
        a.id .. " amplifies " .. f .. " produced by " .. b.id, has(a.targets, "neighbors"))
    end
    if has(b.amplifies, f) and has(a.produces, f) then
      edge(out, b, a, "producer_amplifier", f, 1.6,
        b.id .. " amplifies " .. f .. " produced by " .. a.id, has(b.targets, "neighbors"))
    end
    if has(a.grants, f) and (b.hasOnHit or hasAnyFamily(b)) then
      edge(out, a, b, "grant_family", f, 1.15,
        a.id .. " grants " .. f .. " to a unit that can apply pressure", has(a.targets, "neighbors"))
    end
    if has(b.grants, f) and (a.hasOnHit or hasAnyFamily(a)) then
      edge(out, b, a, "grant_family", f, 1.15,
        b.id .. " grants " .. f .. " to a unit that can apply pressure", has(b.targets, "neighbors"))
    end
    if has(a.propagates, f) and has(b.produces, f) then
      edge(out, a, b, "propagation_payoff", f, 1.25,
        a.id .. " propagates " .. f .. " supplied by " .. b.id, false)
    end
    if has(b.propagates, f) and has(a.produces, f) then
      edge(out, b, a, "propagation_payoff", f, 1.25,
        b.id .. " propagates " .. f .. " supplied by " .. a.id, false)
    end
    if has(a.transforms, f) and has(b.produces, f) then
      edge(out, a, b, "transform_payoff", f, 1.3,
        a.id .. " transforms the " .. f .. " plan produced by " .. b.id, false)
    end
    if has(b.transforms, f) and has(a.produces, f) then
      edge(out, b, a, "transform_payoff", f, 1.3,
        b.id .. " transforms the " .. f .. " plan produced by " .. a.id, false)
    end
    if has(a.produces, f) and has(b.produces, f) then
      edge(out, a, b, "family_stack", f, 0.55,
        a.id .. " and " .. b.id .. " both commit to " .. f, false)
    end
  end

  if has(a.amplifies, "shield") and (has(b.produces, "shield") or has(b.grants, "shield") or has(b.supports, "shield")) then
    edge(out, a, b, "shield_engine", "shield", 1.5, a.id .. " improves shield output from " .. b.id, has(a.targets, "neighbors"))
  end
  if has(b.amplifies, "shield") and (has(a.produces, "shield") or has(a.grants, "shield") or has(a.supports, "shield")) then
    edge(out, b, a, "shield_engine", "shield", 1.5, b.id .. " improves shield output from " .. a.id, has(b.targets, "neighbors"))
  end
  if has(a.grants, "shield") and b.frontline then
    edge(out, a, b, "frontline_cover", "shield", 0.75, a.id .. " shields frontline " .. b.id, has(a.targets, "neighbors"))
  end
  if has(b.grants, "shield") and a.frontline then
    edge(out, b, a, "frontline_cover", "shield", 0.75, b.id .. " shields frontline " .. a.id, has(b.targets, "neighbors"))
  end
  local function tankish(p)
    return p.frontline or p.role == "tank" or has(p.supports, "guard")
      or has(p.supports, "sustain") or has(p.supports, "shield")
  end
  if has(a.supports, "guard") and tankish(b) then
    edge(out, a, b, "guard_frontline", "guard", 0.75,
      a.id .. " reinforces the frontline role of " .. b.id, has(a.targets, "neighbors"))
  end
  if has(b.supports, "guard") and tankish(a) then
    edge(out, b, a, "guard_frontline", "guard", 0.75,
      b.id .. " reinforces the frontline role of " .. a.id, has(b.targets, "neighbors"))
  end
  if has(a.supports, "sustain") and tankish(b) then
    edge(out, a, b, "sustain_wall", "sustain", 0.65,
      a.id .. " helps a defensive front stay alive", has(a.targets, "neighbors"))
  end
  if has(b.supports, "sustain") and tankish(a) then
    edge(out, b, a, "sustain_wall", "sustain", 0.65,
      b.id .. " helps a defensive front stay alive", has(b.targets, "neighbors"))
  end
  if a.frontline and b.frontline then
    edge(out, a, b, "frontline_wall", "guard", 0.45,
      a.id .. " and " .. b.id .. " form a readable defensive front", false)
  end
  if has(a.supports, "haste") and b.hasOnHit then
    edge(out, a, b, "tempo_support", "haste", 0.65, a.id .. " accelerates on-hit pressure from " .. b.id, has(a.targets, "neighbors"))
  end
  if has(b.supports, "haste") and a.hasOnHit then
    edge(out, b, a, "tempo_support", "haste", 0.65, b.id .. " accelerates on-hit pressure from " .. a.id, has(b.targets, "neighbors"))
  end
  if has(a.amplifies, "damage") and (b.hasOnHit or hasAnyFamily(b)) then
    edge(out, a, b, "damage_marker", "damage", 0.8, a.id .. " makes " .. b.id .. " damage more valuable", false)
  end
  if has(b.amplifies, "damage") and (a.hasOnHit or hasAnyFamily(a)) then
    edge(out, b, a, "damage_marker", "damage", 0.8, b.id .. " makes " .. a.id .. " damage more valuable", false)
  end

  if has(a.supports, "summon") and has(b.supports, "faint_payoff") then
    edge(out, a, b, "faint_engine", "faint", 1.35,
      a.id .. " creates deaths that feed " .. b.id, false)
  end
  if has(b.supports, "summon") and has(a.supports, "faint_payoff") then
    edge(out, b, a, "faint_engine", "faint", 1.35,
      b.id .. " creates deaths that feed " .. a.id, false)
  end
  if has(a.supports, "summon") and has(b.supports, "summon") then
    edge(out, a, b, "summon_line", "summon", 0.6,
      a.id .. " and " .. b.id .. " both commit to a summon board", false)
  end
  if has(a.supports, "mimicry") and b.hasOnHit then
    edge(out, a, b, "mimicry_payoff", "mimicry", 1.15,
      a.id .. " can echo on-hit pressure from " .. b.id, has(a.targets, "ahead") or has(a.targets, "neighbors"))
  end
  if has(b.supports, "mimicry") and a.hasOnHit then
    edge(out, b, a, "mimicry_payoff", "mimicry", 1.15,
      b.id .. " can echo on-hit pressure from " .. a.id, has(b.targets, "ahead") or has(b.targets, "neighbors"))
  end
  local function auraLike(p)
    return has(p.supports, "aura") or next(p.amplifies) ~= nil or next(p.grants) ~= nil
  end
  if has(a.supports, "aura") and auraLike(b) then
    edge(out, a, b, "aura_amplifier", "aura", 0.9,
      a.id .. " amplifies aura-style value from " .. b.id, false)
  end
  if has(b.supports, "aura") and auraLike(a) then
    edge(out, b, a, "aura_amplifier", "aura", 0.9,
      b.id .. " amplifies aura-style value from " .. a.id, false)
  end

  table.sort(out, function(x, y)
    if x.weight ~= y.weight then return x.weight > y.weight end
    local ax = x.from .. x.to .. x.kind .. tostring(x.family)
    local ay = y.from .. y.to .. y.kind .. tostring(y.family)
    return ax < ay
  end)
  return out
end

local function commandEdges(commander, target)
  commander, target = asProfile(commander), asProfile(target)
  if not (commander and target) then return {} end
  local out = {}
  local c = commander.command
  for _, f in ipairs(FAMILIES) do
    if has(c.amplifies, f) and has(target.produces, f) then
      edge(out, commander, target, "command_amplifier", f, 1.25,
        commander.id .. " command amplifies " .. f .. " for " .. target.id, false)
    end
    if has(c.transforms, f) and has(target.produces, f) then
      edge(out, commander, target, "command_transform", f, 1.35,
        commander.id .. " command transforms " .. f .. " for " .. target.id, false)
    end
    if has(c.propagates, f) and has(target.produces, f) then
      edge(out, commander, target, "command_propagation", f, 1.15,
        commander.id .. " command propagates " .. f .. " supplied by " .. target.id, false)
    end
  end
  if has(c.supports, "haste") and target.hasOnHit then
    edge(out, commander, target, "command_tempo", "haste", 0.65,
      commander.id .. " command accelerates " .. target.id, false)
  end
  if has(c.amplifies, "damage") and (target.hasOnHit or hasAnyFamily(target)) then
    edge(out, commander, target, "command_marker", "damage", 0.8,
      commander.id .. " command marks targets for " .. target.id, false)
  end
  return out
end

local function slotOf(entry)
  return entry and entry.slot
end

local function squareNeighbors(a, b)
  if not (a and b) then return nil end
  local ax, ay = (a - 1) % 3, math.floor((a - 1) / 3)
  local bx, by = (b - 1) % 3, math.floor((b - 1) / 3)
  return math.abs(ax - bx) + math.abs(ay - by) == 1
end

local function targetMatches(target, profile, entry)
  if not target or target == "team" then return true end
  if target:sub(1, 5) == "type:" then
    local u = Units[profile.id]
    return u and u.type == target:sub(6)
  end
  if target == "role:front" or target == "role:back" then
    local slot = entry and entry.slot
    if not slot then return false end
    local col = (slot - 1) % 3
    return (target == "role:front" and col == 2) or (target == "role:back" and col == 0)
  end
  return false
end

local function teamEntries(team)
  local out = {}
  for _, entry in ipairs(team or {}) do
    if type(entry) == "string" then out[#out + 1] = { id = entry, level = 1 }
    else out[#out + 1] = { id = entry.id, level = entry.level or 1, slot = entry.slot } end
  end
  return out
end

function Coherence.economyForTeam(team, opts)
  opts = opts or {}
  local variant, variantId = resolveEconomyProfile(opts.variant)
  local baseline = Economy.resolve("baseline")
  local entries = teamEntries(team)
  local gold, baseGold, maxRank, maxLevel, lowRankCopies = 0, 0, 0, 1, 0
  local rankCounts = {}
  for _, entry in ipairs(entries) do
    local u = Units[entry.id]
    if u then
      local rank = u.rank or 1
      local lvl = Resolver.clampLevel(entry.level or 1)
      local copies = LEVEL_COPIES[lvl] or 1
      local c = unitCost(entry.id, variant)
      gold = gold + c * copies
      baseGold = baseGold + unitCost(entry.id, baseline) * copies
      rankCounts[rank] = (rankCounts[rank] or 0) + 1
      if rank > maxRank then maxRank = rank end
      if lvl > maxLevel then maxLevel = lvl end
      if rank <= 2 and lvl >= 3 then lowRankCopies = lowRankCopies + copies end
    end
  end
  local shopPressure = Coherence.shopPressure(variant.id)
  local accessibility = "mid"
  if lowRankCopies > 0 then accessibility = "reroll_low_rank"
  elseif maxRank <= 2 then accessibility = "early"
  elseif maxRank >= 5 then accessibility = "late"
  elseif maxRank >= 4 then accessibility = "advanced" end
  return {
    variant = variant.id,
    requestedVariant = opts.variant,
    resolvedVariant = variantId,
    assemblyGold = gold,
    currentRulesGold = baseGold,
    maxRank = maxRank,
    maxLevel = maxLevel,
    rankCounts = rankCounts,
    lowRankCopies = lowRankCopies,
    accessibility = accessibility,
    shopPressure = shopPressure,
  }
end

function Coherence.shopPressure(variantId)
  local variant = resolveEconomyProfile(variantId)
  local out = {}
  for tier = 1, RunState.MAX_TIER do
    local odds = RunState.ODDS[tier]
    local avg = 0
    for rank = 1, RunState.MAX_TIER do
      local cost = Economy.unitCost(variant, { rank = rank, cost = rank }, rank)
      avg = avg + ((odds[rank] or 0) / 100) * cost
    end
    local gold = Economy.goldForRound(variant, tier)
    out[#out + 1] = {
      profile = variant.id,
      tier = tier,
      avgOfferCost = r3(avg),
      fullShopCost = r3(avg * RunState.SHOP_SIZE),
      gold = gold,
      rerollCost = Economy.rerollCost(variant, tier),
      buyXpCost = Economy.buyXpCost(variant),
      fullShopCostRatio = r3((avg * RunState.SHOP_SIZE) / gold),
    }
  end
  return out
end

local function archetypeCounts(profiles)
  local counts, familyCounts = {}, {}
  for _, p in ipairs(profiles) do
    add(counts, p.role)
    if p.family then add(familyCounts, p.family) end
  end
  return counts, familyCounts
end

local function dominantShare(counts, n)
  local best = 0
  for _, v in pairs(counts or {}) do if v > best then best = v end end
  return n > 0 and best / n or 0
end

local function supportedClutchScore(profiles)
  local familyCounts, amplifiers = {}, {}
  for _, p in ipairs(profiles) do
    if p.family then add(familyCounts, p.family) end
    for _, f in ipairs(FAMILIES) do if has(p.amplifies, f) then add(amplifiers, f) end end
  end
  local score = 0
  for _, p in ipairs(profiles) do
    if p.authoredLevel and p.level >= 2 then score = score + 0.25 end
    if p.clutch then
      local fam = p.family
      if fam and ((familyCounts[fam] or 0) >= 2 or has(amplifiers, fam)) then
        score = score + 0.75
      else
        score = score + 0.4
      end
    end
  end
  return clamp01(score / math.max(1, #profiles * 0.45))
end

local function edgeWeight(edges)
  local sum = 0
  for _, e in ipairs(edges or {}) do sum = sum + (e.weight or 0) end
  return sum
end

function Coherence.scoreTeam(team, opts)
  opts = opts or {}
  local entries = teamEntries(team)
  local profiles, byId = {}, {}
  for _, entry in ipairs(entries) do
    local p = Coherence.profileFor(entry.id, entry.level or 1)
    if p then
      profiles[#profiles + 1] = p
      byId[p.id] = { profile = p, entry = entry }
    end
  end

  local edges = {}
  for i = 1, #profiles do
    for j = i + 1, #profiles do
      local pair = Coherence.edgesForPair(profiles[i], profiles[j])
      for _, e in ipairs(pair) do edges[#edges + 1] = e end
    end
  end

  local positionRequired, positionSatisfied, positionUnknown = 0, 0, 0
  for _, e in ipairs(edges) do
    if e.requiresPlacement then
      positionRequired = positionRequired + 1
      local a = byId[e.from] and byId[e.from].entry
      local b = byId[e.to] and byId[e.to].entry
      local ok = squareNeighbors(slotOf(a), slotOf(b))
      if ok == nil then positionUnknown = positionUnknown + 1
      elseif ok then positionSatisfied = positionSatisfied + 1 end
    end
  end

  local commander = opts.commander and Coherence.profileFor(opts.commander.id or opts.commander, opts.commander.level or 1)
  local cmdEdges = {}
  if commander then
    for _, p in ipairs(profiles) do
      if p.id ~= commander.id then
        local row = commandEdges(commander, p)
        for _, e in ipairs(row) do cmdEdges[#cmdEdges + 1] = e end
      end
    end
  end

  local relicEdges = {}
  for _, rid in ipairs(opts.relics or {}) do
    local rp = Coherence.profileForRelic(rid)
    if rp then
      for _, p in ipairs(profiles) do
        local entry = byId[p.id] and byId[p.id].entry
        if targetMatches(rp.relicTarget, p, entry) then
          local row = Coherence.edgesForPair(rp, p)
          for _, e in ipairs(row) do relicEdges[#relicEdges + 1] = e end
        end
      end
    end
  end

  local n = #profiles
  local counts, familyCounts = archetypeCounts(profiles)
  local rawEdge = edgeWeight(edges)
  local rawCommand = edgeWeight(cmdEdges)
  local rawRelic = edgeWeight(relicEdges)
  local tagScore = clamp01(rawEdge / math.max(1, n * 2.1))
  local commandScore = commander and clamp01(rawCommand / math.max(1, n * 1.0)) or 0
  local relicScore = (#relicEdges > 0) and clamp01(rawRelic / math.max(1, n * 1.0)) or 0
  local positionScore = 1
  if positionRequired > 0 then
    positionScore = (positionSatisfied + positionUnknown * 0.5) / positionRequired
  end
  local readabilityScore = clamp01((dominantShare(counts, n) * 0.45) + (dominantShare(familyCounts, n) * 0.55))
  local levelScore = supportedClutchScore(profiles)
  local coherence = tagScore * 0.42
    + positionScore * 0.14
    + commandScore * 0.14
    + levelScore * 0.14
    + readabilityScore * 0.16
  if relicScore > 0 then coherence = coherence + relicScore * 0.08 end

  table.sort(edges, function(a, b)
    if a.weight ~= b.weight then return a.weight > b.weight end
    return (a.from .. a.to .. a.kind) < (b.from .. b.to .. b.kind)
  end)
  table.sort(cmdEdges, function(a, b)
    if a.weight ~= b.weight then return a.weight > b.weight end
    return (a.from .. a.to .. a.kind) < (b.from .. b.to .. b.kind)
  end)
  table.sort(relicEdges, function(a, b)
    if a.weight ~= b.weight then return a.weight > b.weight end
    return (a.from .. a.to .. a.kind) < (b.from .. b.to .. b.kind)
  end)

  return {
    coherence = r3(clamp01(coherence)),
    rawEdgeWeight = r3(rawEdge),
    subscores = {
      tags = r3(tagScore),
      position = r3(positionScore),
      command = r3(commandScore),
      relic = r3(relicScore),
      level_plan = r3(levelScore),
      readability = r3(readabilityScore),
    },
    counts = counts,
    familyCounts = familyCounts,
    edges = edges,
    commandEdges = cmdEdges,
    relicEdges = relicEdges,
    economy = Coherence.economyForTeam(entries, { variant = opts.economyVariant or DEFAULT_VARIANT }),
  }
end

function Coherence.graph(opts)
  opts = opts or {}
  local level = opts.level or 1
  local profiles, edges = {}, {}
  for _, id in ipairs(Units.order) do
    local p = Coherence.profileFor(id, level)
    profiles[#profiles + 1] = p
  end
  for i = 1, #profiles do
    for j = i + 1, #profiles do
      local pair = Coherence.edgesForPair(profiles[i], profiles[j])
      for _, e in ipairs(pair) do edges[#edges + 1] = e end
    end
  end
  table.sort(edges, function(a, b)
    if a.weight ~= b.weight then return a.weight > b.weight end
    return (a.from .. a.to .. a.kind) < (b.from .. b.to .. b.kind)
  end)
  return { profiles = profiles, edges = edges }
end

function Coherence.topEdges(limit, opts)
  local g = Coherence.graph(opts)
  local out = {}
  for i = 1, math.min(limit or 20, #g.edges) do out[#out + 1] = g.edges[i] end
  return out
end

function Coherence.coverage()
  local profiles = {}
  local authored, clutch, byRole, byFamily = 0, 0, {}, {}
  for _, id in ipairs(Units.order) do
    local p = Coherence.profileFor(id, Resolver.MAX_LEVEL)
    profiles[#profiles + 1] = p
    if p.authoredLevel then authored = authored + 1 end
    if p.clutch then clutch = clutch + 1 end
    add(byRole, p.role)
    if p.family then add(byFamily, p.family) end
  end
  return {
    units = #profiles,
    authoredLevelUnits = authored,
    clutchUnits = clutch,
    byRole = byRole,
    byFamily = byFamily,
    graphEdgesLevel1 = #Coherence.graph({ level = 1 }).edges,
  }
end

return Coherence
