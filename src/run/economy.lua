-- src/run/economy.lua
-- Pure economy tuning profiles for simulations and live runs. The legacy
-- baseline stays addressable by id; nil resolves to the current live profile.

local Economy = {}

Economy.liveProfileId = "sap_cost_pair_completion_tiered_reroll"

local DEFAULTS = {
  id = "baseline",
  goldPerRound = 10,
  rerollCost = 1,
  buyXpCost = 4,
  buyXpAmount = 4,
  passiveShopXpPerRound = 1,
  xpToLevel = { [1] = 2, [2] = 5, [3] = 8, [4] = 12 },
  slotDeclineGold = 3,
  relicDeclineGold = 3,
  commanderDeclineGold = 4,
}

Economy.profiles = {
  baseline = {
    id = "baseline",
    label = "legacy baseline: 10g, cost=rank, reroll=1",
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
  slow_shop_xp = {
    id = "slow_shop_xp",
    label = "slower shop XP: passive tier 3 around round 10",
    xpToLevel = { [1] = 3, [2] = 6, [3] = 9, [4] = 12 },
  },
  tiered_reroll = {
    id = "tiered_reroll",
    label = "tiered reroll: 1/1/2/2/3 by shop tier",
    rerollCostByTier = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 },
  },
  pair_completion_light = {
    id = "pair_completion_light",
    label = "baseline plus pair-completion shop support",
    pairCompletionSupport = { maxPerRound = 1, minRound = 2 },
  },
  pair_completion_tiered_reroll = {
    id = "pair_completion_tiered_reroll",
    label = "baseline plus pair-completion support and tiered reroll",
    pairCompletionSupport = { maxPerRound = 1, minRound = 2 },
    rerollCostByTier = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 },
  },
  pair_completion_delayed = {
    id = "pair_completion_delayed",
    label = "baseline plus delayed pair-completion pity",
    pairCompletionSupport = { maxPerRound = 1, minRound = 2, minMissedWindows = 2 },
  },
  pair_completion_dense = {
    id = "pair_completion_dense",
    label = "baseline plus denser pair-completion shop support",
    pairCompletionSupport = { maxPerRound = 2, minRound = 2 },
  },
  pair_completion_dense_delayed = {
    id = "pair_completion_dense_delayed",
    label = "baseline plus denser delayed pair-completion pity",
    pairCompletionSupport = { maxPerRound = 2, minRound = 2, minMissedWindows = 2 },
  },
  sap_cost_pair_completion = {
    id = "sap_cost_pair_completion",
    label = "SAP-like costs plus pair-completion shop support",
    costByRank = { 2, 3, 4, 5, 6 },
    pairCompletionSupport = { maxPerRound = 1, minRound = 2 },
  },
  sap_cost_pair_completion_tiered_reroll = {
    id = "sap_cost_pair_completion_tiered_reroll",
    label = "SAP-like costs plus pair-completion support and tiered reroll",
    costByRank = { 2, 3, 4, 5, 6 },
    pairCompletionSupport = { maxPerRound = 1, minRound = 2 },
    rerollCostByTier = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 },
  },
  sap_cost_pair_completion_delayed = {
    id = "sap_cost_pair_completion_delayed",
    label = "SAP-like costs plus delayed pair-completion pity",
    costByRank = { 2, 3, 4, 5, 6 },
    pairCompletionSupport = { maxPerRound = 1, minRound = 2, minMissedWindows = 2 },
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
  "slow_shop_xp",
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

function Economy.defaultProfileId()
  local id = os.getenv("PIT_LIVE_ECONOMY")
  if id and id ~= "" and Economy.profiles[id] then return id end
  return Economy.liveProfileId
end

function Economy.resolve(profile)
  local src
  if profile == nil then
    src = Economy.profiles[Economy.defaultProfileId()] or Economy.profiles.baseline
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
  if economy and economy.buyXpCost ~= nil then return economy.buyXpCost end
  return DEFAULTS.buyXpCost
end

function Economy.buyXpAmount(economy)
  if economy and economy.buyXpAmount ~= nil then return economy.buyXpAmount end
  return DEFAULTS.buyXpAmount
end

function Economy.passiveShopXpForRound(economy, round)
  local byRound = economy and economy.passiveShopXpByRound
  if byRound and byRound[round] ~= nil then return byRound[round] end
  if economy and economy.passiveShopXpPerRound ~= nil then return economy.passiveShopXpPerRound end
  return DEFAULTS.passiveShopXpPerRound
end

function Economy.shopXpToLevel(economy, tier)
  local xpToLevel = economy and economy.xpToLevel
  if xpToLevel and xpToLevel[tier] ~= nil then return xpToLevel[tier] end
  return DEFAULTS.xpToLevel[tier]
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
