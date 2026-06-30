-- tools/levelup_report.lua
-- Deterministic audit for authored monster level-up coverage and reroll-clutch gaps.
package.path = "./?.lua;" .. package.path

local Common = require("tools.scenarios.common")
local Resolver = require("src.core.unit_resolver")
local Units = require("src.data.units")

local function cloneList(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  return out
end

local function effectOps(unit)
  local out = {}
  for _, e in ipairs(unit.effects or {}) do
    if e.op then out[#out + 1] = e.op end
  end
  return out
end

local function commandOp(unit)
  return unit.commandBonus and unit.commandBonus.op or nil
end

local function levelFlags(id)
  local summary = Resolver.levelDeltaSummary(id)
  local out = { authored = #summary > 0, clutch = false, transformative = false, levels = {} }
  for _, row in ipairs(summary) do
    out.levels[#out.levels + 1] = row.level
    if row.clutch then out.clutch = true end
    if row.transformative then out.transformative = true end
  end
  return out
end

local function addRankBucket(byRank, rank)
  rank = tostring(rank or "?")
  local b = byRank[rank]
  if not b then
    b = { total = 0, authored = 0, missing = 0, clutch = 0, transformative = 0 }
    byRank[rank] = b
  end
  return b
end

local function candidatePriority(unit, flags)
  local rank = unit.rank or 99
  if flags.authored then return nil end
  local hasEffect = #(unit.effects or {}) > 0
  local hasCommand = unit.commandBonus ~= nil
  local score = 0
  if rank <= 1 then score = score + 50
  elseif rank == 2 then score = score + 40
  elseif rank == 3 then score = score + 25
  end
  if hasEffect then score = score + 20 end
  if hasCommand then score = score + 10 end
  if unit.cost and unit.cost <= 2 then score = score + 8 end
  if score <= 0 then return nil end
  return score
end

local rows, authored, missing, candidates = {}, {}, {}, {}
local byRank = {}
local coverage = {
  units = 0,
  authored = 0,
  missing = 0,
  clutch = 0,
  transformative = 0,
  low_mid_units = 0,
  low_mid_authored = 0,
  low_mid_clutch = 0,
}

for _, id in ipairs(Units.order) do
  local unit = Units[id]
  local flags = levelFlags(id)
  local rank = unit.rank or 1
  local b = addRankBucket(byRank, rank)
  local row = {
    id = id,
    rank = rank,
    cost = unit.cost,
    type = unit.type,
    family = unit.family,
    effects = effectOps(unit),
    command = commandOp(unit),
    authored = flags.authored,
    clutch = flags.clutch,
    transformative = flags.transformative,
    levels = cloneList(flags.levels),
  }

  coverage.units = coverage.units + 1
  b.total = b.total + 1
  if rank <= 3 then coverage.low_mid_units = coverage.low_mid_units + 1 end
  if flags.authored then
    coverage.authored = coverage.authored + 1
    b.authored = b.authored + 1
    authored[#authored + 1] = row
    if rank <= 3 then coverage.low_mid_authored = coverage.low_mid_authored + 1 end
  else
    coverage.missing = coverage.missing + 1
    b.missing = b.missing + 1
    missing[#missing + 1] = row
  end
  if flags.clutch then
    coverage.clutch = coverage.clutch + 1
    b.clutch = b.clutch + 1
    if rank <= 3 then coverage.low_mid_clutch = coverage.low_mid_clutch + 1 end
  end
  if flags.transformative then
    coverage.transformative = coverage.transformative + 1
    b.transformative = b.transformative + 1
  end
  local priority = candidatePriority(unit, flags)
  if priority then
    row.priority = priority
    candidates[#candidates + 1] = row
  end
  rows[#rows + 1] = row
end

table.sort(candidates, function(a, b)
  if a.priority ~= b.priority then return a.priority > b.priority end
  if a.rank ~= b.rank then return a.rank < b.rank end
  return a.id < b.id
end)

local function take(list, n)
  local out = {}
  for i = 1, math.min(n, #(list or {})) do out[#out + 1] = list[i] end
  return out
end

local payload = {
  kind = "levelup_report",
  deterministic = true,
  coverage = coverage,
  by_rank = byRank,
  authored = authored,
  missing_count = #missing,
  priority_candidates = take(candidates, 30),
  rows = rows,
  recommendations = {},
}

if coverage.authored < coverage.units then
  payload.recommendations[#payload.recommendations + 1] = {
    id = "expand_levelup_coverage",
    severity = "high",
    text = "Most monsters still lack authored ability level-ups; expand level 2/3 deltas before final balance conclusions.",
  }
end
if coverage.low_mid_clutch < math.max(8, math.floor(coverage.low_mid_units * 0.15)) then
  payload.recommendations[#payload.recommendations + 1] = {
    id = "low_mid_clutch",
    severity = "medium",
    text = "Low/mid-rank level-3 clutch coverage is below the reroll-composition target band.",
  }
end

local path = Common.writeReport("levelups", payload, { updateRef = false })

print("=> ecrit " .. path)
print(string.format("levelups: %d/%d authored, %d clutch, %d transformative",
  coverage.authored, coverage.units, coverage.clutch, coverage.transformative))
print(string.format("low/mid: %d/%d authored, %d clutch",
  coverage.low_mid_authored, coverage.low_mid_units, coverage.low_mid_clutch))
for rank = 1, 5 do
  local b = byRank[tostring(rank)] or { authored = 0, total = 0, clutch = 0 }
  print(string.format("rank %s: %d/%d authored, %d clutch",
    rank, b.authored, b.total, b.clutch))
end
print("priority candidates:")
for _, row in ipairs(take(candidates, 12)) do
  print(string.format("  %-18s r%d score=%d effects=%s command=%s",
    row.id, row.rank, row.priority, table.concat(row.effects, ","),
    row.command or "-"))
end
