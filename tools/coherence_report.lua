-- tools/coherence_report.lua
-- Deterministic report for the intent/coherence layer. This is the bridge
-- between semantic facts, level-up plans, economy pressure, and future mass
-- simulation inputs.
package.path = "./?.lua;" .. package.path

local Coherence = require("src.lab.coherence")
local Common = require("tools.scenarios.common")

local function take(list, n)
  local out = {}
  for i = 1, math.min(n, #(list or {})) do out[#out + 1] = list[i] end
  return out
end

local function compactScore(score)
  return {
    coherence = score.coherence,
    rawEdgeWeight = score.rawEdgeWeight,
    subscores = score.subscores,
    familyCounts = score.familyCounts,
    counts = score.counts,
    economy = {
      variant = score.economy.variant,
      assemblyGold = score.economy.assemblyGold,
      currentRulesGold = score.economy.currentRulesGold,
      maxRank = score.economy.maxRank,
      maxLevel = score.economy.maxLevel,
      lowRankCopies = score.economy.lowRankCopies,
      accessibility = score.economy.accessibility,
    },
    edges = take(score.edges, 12),
    commandEdges = take(score.commandEdges, 8),
  }
end

local SAMPLES = {
  {
    id = "poison_reroll",
    label = "Poison reroll shell",
    note = "Low-rank L3 spore becomes a real plan when paired with poison amplifiers and corruptor command.",
    commander = { id = "corruptor", level = 3 },
    units = {
      { id = "spore_tick", level = 3, slot = 2 },
      { id = "miasma_acolyte", level = 3, slot = 5 },
      { id = "witch", level = 1, slot = 4 },
      { id = "corruptor", level = 3, slot = 6 },
    },
  },
  {
    id = "burn_propagation",
    label = "Burn propagation shell",
    note = "Burn appliers plus neighbor burn amplifier plus death propagation.",
    commander = { id = "emberling", level = 1 },
    units = {
      { id = "emberling", level = 1, slot = 2 },
      { id = "soot_acolyte", level = 1, slot = 5 },
      { id = "wildfire_hound", level = 1, slot = 6 },
      { id = "bellows_priest", level = 1, slot = 4 },
    },
  },
  {
    id = "shield_engine",
    label = "Shield engine shell",
    note = "Periodic shield caster plus shield amplifier and frontline cover.",
    commander = { id = "barrier_savant", level = 1 },
    units = {
      { id = "ward_weaver", level = 1, slot = 5 },
      { id = "barrier_savant", level = 1, slot = 2 },
      { id = "shieldbearer", level = 3, slot = 4 },
      { id = "templar", level = 1, slot = 6 },
    },
  },
  {
    id = "random_pile",
    label = "Low-synergy baseline",
    note = "Useful baseline: cheap bodies without a clear tag plan.",
    units = {
      { id = "marauder", level = 1, slot = 3 },
      { id = "skeleton", level = 1, slot = 2 },
      { id = "bandit", level = 1, slot = 1 },
      { id = "demon", level = 1, slot = 4 },
    },
  },
}

local function economyVariants()
  local order = { "current", "sap_like", "curved_income" }
  local out = {}
  for _, id in ipairs(order) do
    out[#out + 1] = {
      id = id,
      pressure = Coherence.shopPressure(id),
    }
  end
  return out
end

local function sampleReports()
  local out = {}
  for _, sample in ipairs(SAMPLES) do
    local score = Coherence.scoreTeam(sample.units, { commander = sample.commander })
    out[#out + 1] = {
      id = sample.id,
      label = sample.label,
      note = sample.note,
      commander = sample.commander,
      units = sample.units,
      score = compactScore(score),
    }
  end
  return out
end

local function recommendations(payload)
  local recs = {}
  local currentT1 = payload.economyVariants[1].pressure[1].fullShopCostRatio
  if currentT1 < 0.7 then
    recs[#recs + 1] = {
      id = "economy_pressure",
      severity = "high",
      text = "Current tier-1 full-shop ratio is below 70%; the economy teaches buy-wide before it teaches choice.",
    }
  end
  if payload.coverage.authoredLevelUnits < payload.coverage.units * 0.25 then
    recs[#recs + 1] = {
      id = "levelup_coverage",
      severity = "high",
      text = "Only a small slice of the roster has authored ability level-ups; keep expanding before large-scale balance conclusions.",
    }
  end
  if payload.coverage.clutchUnits < 6 then
    recs[#recs + 1] = {
      id = "reroll_clutch",
      severity = "medium",
      text = "Low/mid-rank level-3 clutch coverage is still thin for reroll composition testing.",
    }
  end
  return recs
end

local payload = {
  kind = "coherence_report",
  deterministic = true,
  sourceDocs = {
    "docs/research/intensive-simulation-balance-program-HANDOFF.md",
    "docs/audit/2026-06-26-economie-run.md",
  },
  coverage = Coherence.coverage(),
  economyVariants = economyVariants(),
  topEdges = Coherence.topEdges(40, { level = 1 }),
  samples = sampleReports(),
}
payload.recommendations = recommendations(payload)

local path = Common.writeReport("coherence", payload, { updateRef = false })

print("=> ecrit " .. path)
print(string.format("coverage: %d units / %d graph edges / %d authored level units / %d clutch units",
  payload.coverage.units, payload.coverage.graphEdgesLevel1,
  payload.coverage.authoredLevelUnits, payload.coverage.clutchUnits))
for _, sample in ipairs(payload.samples) do
  print(string.format("sample %-18s coherence %.3f  tags %.3f  command %.3f  economy %s %dg",
    sample.id, sample.score.coherence, sample.score.subscores.tags,
    sample.score.subscores.command, sample.score.economy.accessibility,
    sample.score.economy.currentRulesGold))
end
for _, v in ipairs(payload.economyVariants) do
  local p = v.pressure[1]
  print(string.format("economy %-14s tier1 full-shop ratio %.3f (%dg)",
    v.id, p.fullShopCostRatio, p.gold))
end
