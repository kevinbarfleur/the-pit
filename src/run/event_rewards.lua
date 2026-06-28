-- src/run/event_rewards.lua
-- Application live des recompenses d'events de run.
--
-- RunState sait materialiser les rewards lisibles (relic/unit/gold/xp/tier),
-- mais les unites et mutations appartiennent aux occurrences du Build
-- (banc/plateau/fusions/snapshots). Ce module garde ce pont au meme endroit
-- pour eviter de dupliquer la logique dans main.lua et dans la scene.

local Units = require("src.data.units")
local Mutations = require("src.run.mutations")

local EventRewards = {}

local function unitLevel(reward)
  return math.max(1, math.min(2, (reward and reward.level) or 1))
end

function EventRewards.canGrantUnit(build, id, level)
  if not (build and Units[id]) then return false end
  level = math.max(1, math.min(2, level or 1))
  for i = 1, build:benchCapacity() do
    if not build.bench[i] then return true end
  end
  for i = 1, 9 do
    if build.board.slots[i].unlocked and not build.slotRigs[i] then return true end
  end
  -- Full-board merge-on-grant is intentionally deferred: presenting a reward
  -- that cannot be placed would break the "explicit outcome" event contract.
  return false
end

function EventRewards.bestMutationTarget(build, spec)
  if not build then return nil end
  spec = spec or {}
  local minRank = math.max(1, math.min(5, spec.rank or spec.rankMin or 1))
  local maxRank = math.max(minRank, math.min(5, spec.rank or spec.rankMax or 5))
  local best, bestScore
  local function consider(where, slot, sr)
    if not sr or (sr.mutations and #sr.mutations > 0) then return end
    local u = Units[sr.id]
    local rank = u and (u.rank or 1) or 1
    if rank < minRank or rank > maxRank then return end
    local level = sr.level or 1
    local score = ((where == "board") and 1000 or 0) + level * 120 + rank * 12 + (u and (u.dmg or 0) or 0)
    if not bestScore or score > bestScore or (score == bestScore and slot < best.slot) then
      bestScore = score
      best = { copyId = sr.copyId, where = where, slot = slot, id = sr.id, level = level }
    end
  end
  for i = 1, 9 do consider("board", i, build.slotRigs[i]) end
  for i = 1, build:benchCapacity() do consider("bench", i, build.bench[i]) end
  return best
end

function EventRewards.rollOptions(build, opts)
  opts = opts or {}
  local out = {}
  out.unitFilter = function(id, rewardSpec)
    if opts.unitFilter and not opts.unitFilter(id, rewardSpec) then return false end
    return EventRewards.canGrantUnit(build, id, unitLevel(rewardSpec))
  end
  if opts.mutations then
    out.mutationTarget = function(rewardSpec)
      return EventRewards.bestMutationTarget(build, rewardSpec)
    end
  end
  return out
end

function EventRewards.grantUnit(build, reward)
  if not (build and reward and Units[reward.id]) then return false, "bad_unit" end
  local occ = build:makeOcc(reward.id, unitLevel(reward), { mutations = reward.mutations })
  if not build:stowUnit(occ) then return false, "no_space" end
  build:checkMerges()
  return true
end

function EventRewards.grantMutation(build, reward)
  if not (build and reward and Mutations.byId[reward.id or reward.mutation]) then return false, "bad_mutation" end
  local mutationId = reward.id or reward.mutation
  local target = reward.target or {}
  local sr
  if target.where == "board" and target.slot then sr = build.slotRigs[target.slot]
  elseif target.where == "bench" and target.slot then sr = build.bench[target.slot] end
  if not sr or (target.copyId and sr.copyId ~= target.copyId) or (sr.mutations and #sr.mutations > 0) then
    return false, "bad_mutation_target"
  end
  sr.mutations = Mutations.clone({ mutationId })
  return true
end

function EventRewards.apply(run, build, reward, opts)
  reward = reward or {}
  if reward.kind == "unit" then return EventRewards.grantUnit(build, reward) end
  if reward.kind == "mutation" then return EventRewards.grantMutation(build, reward) end
  if reward.kind == "gold" and opts and opts.deferGold and run then
    run._pendingGold = (run._pendingGold or 0) + math.max(0, reward.amount or 0)
    return true
  end
  if run and run.applyRunEventReward then return run:applyRunEventReward(reward) end
  return false, "bad_run"
end

return EventRewards
