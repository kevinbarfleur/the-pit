-- src/run/economy.lua
-- Pure economy tuning profiles for simulations. The live game keeps the
-- baseline unless a RunState is explicitly created with opts.economy.

local Economy = {}

local DEFAULTS = {
  id = "baseline",
  goldPerRound = 10,
  rerollCost = 1,
  buyXpCost = 4,
  slotDeclineGold = 3,
  relicDeclineGold = 3,
  commanderDeclineGold = 4,
}

Economy.profiles = {
  baseline = {
    id = "baseline",
    label = "current: 10g, cost=rank, reroll=1",
  },
  sap_cost = {
    id = "sap_cost",
    label = "SAP-like costs: rank costs 2/3/4/5/6",
    costByRank = { 2, 3, 4, 5, 6 },
  },
  early_curve = {
    id = "early_curve",
    label = "early income curve: 6/6/8/8/8/10...",
    goldByRound = { [1] = 6, [2] = 6, [3] = 8, [4] = 8, [5] = 8 },
  },
  tiered_reroll = {
    id = "tiered_reroll",
    label = "tiered reroll: 1/1/2/2/3 by shop tier",
    rerollCostByTier = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 },
  },
  sap_cost_tiered_reroll = {
    id = "sap_cost_tiered_reroll",
    label = "SAP-like costs plus tiered reroll",
    costByRank = { 2, 3, 4, 5, 6 },
    rerollCostByTier = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 },
  },
}

Economy.order = {
  "baseline",
  "sap_cost",
  "early_curve",
  "tiered_reroll",
  "sap_cost_tiered_reroll",
}

local function cloneValue(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = cloneValue(vv) end
  return out
end

local function merge(base, extra)
  local out = cloneValue(base)
  for k, v in pairs(extra or {}) do out[k] = cloneValue(v) end
  return out
end

function Economy.resolve(profile)
  local src
  if profile == nil then
    src = Economy.profiles.baseline
  elseif type(profile) == "string" then
    src = assert(Economy.profiles[profile], "unknown economy profile: " .. tostring(profile))
  elseif type(profile) == "table" then
    if profile.base then
      src = merge(Economy.profiles[profile.base] or Economy.profiles.baseline, profile)
    else
      src = profile
    end
  else
    error("invalid economy profile: " .. type(profile))
  end
  local out = merge(DEFAULTS, src)
  out.id = out.id or "custom"
  return out
end

function Economy.goldForRound(economy, round)
  local byRound = economy and economy.goldByRound
  return (byRound and byRound[round]) or (economy and economy.goldPerRound) or DEFAULTS.goldPerRound
end

function Economy.rerollCost(economy, shopTier)
  local byTier = economy and economy.rerollCostByTier
  return (byTier and byTier[shopTier]) or (economy and economy.rerollCost) or DEFAULTS.rerollCost
end

function Economy.buyXpCost(economy)
  return (economy and economy.buyXpCost) or DEFAULTS.buyXpCost
end

function Economy.unitCost(economy, unit, defaultCost)
  if unit then
    local byRank = economy and economy.costByRank
    if byRank and unit.rank and byRank[unit.rank] then return byRank[unit.rank] end
    if unit.cost then return unit.cost end
  end
  return defaultCost or 3
end

function Economy.declineGold(economy, kind)
  if kind == "slot" then return (economy and economy.slotDeclineGold) or DEFAULTS.slotDeclineGold end
  if kind == "relic" then return (economy and economy.relicDeclineGold) or DEFAULTS.relicDeclineGold end
  if kind == "commander" then return (economy and economy.commanderDeclineGold) or DEFAULTS.commanderDeclineGold end
  return 0
end

return Economy
