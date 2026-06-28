-- src/run/mutations.lua
-- MUTATIONS : modifiers persistants d'une COPIE d'unite.
--
-- Contrat:
--   * une mutation est portee par l'instance { id, level, copyId, mutations[] },
--     pas par l'id global de l'unite;
--   * elle est serialisable/snapshot-safe (ids stables, pas de function);
--   * elle modifie le spec de combat bake, jamais la data Units;
--   * les fusions gardent au plus une mutation selon un ordre deterministe.

local Mutations = {}

Mutations.order = {
  "echo_touched",
  "blood_fed",
  "quickened",
  "iron_buried",
}

Mutations.byId = {
  echo_touched = {
    id = "echo_touched",
    label = "Echo-Touched",
    desc = "+1 Multicast.",
    priority = 100,
    multicast = 1,
  },
  blood_fed = {
    id = "blood_fed",
    label = "Blood-Fed",
    desc = "+20% damage.",
    priority = 70,
    dmgInc = 0.20,
  },
  quickened = {
    id = "quickened",
    label = "Quickened",
    desc = "+15% Haste.",
    priority = 60,
    haste = 0.15,
  },
  iron_buried = {
    id = "iron_buried",
    label = "Iron-Buried",
    desc = "+25% HP and 10% damage reduction.",
    priority = 50,
    hpInc = 0.25,
    dmgReduce = 0.10,
  },
}

local orderIndex = {}
for i, id in ipairs(Mutations.order) do orderIndex[id] = i end

local function isKnown(id)
  return id and Mutations.byId[id] ~= nil
end

function Mutations.normalize(list)
  if type(list) == "string" then list = { list } end
  if type(list) ~= "table" then return nil end
  local out, seen = {}, {}
  for _, id in ipairs(list) do
    if isKnown(id) and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  table.sort(out, function(a, b)
    return (orderIndex[a] or 9999) < (orderIndex[b] or 9999)
  end)
  return (#out > 0) and out or nil
end

function Mutations.clone(list)
  local norm = Mutations.normalize(list)
  if not norm then return nil end
  local out = {}
  for i, id in ipairs(norm) do out[i] = id end
  return out
end

function Mutations.encode(list)
  local norm = Mutations.normalize(list)
  return norm and table.concat(norm, "+") or nil
end

function Mutations.decode(str)
  if type(str) ~= "string" or str == "" then return nil end
  local out = {}
  for id in str:gmatch("[^+]+") do out[#out + 1] = id end
  return Mutations.normalize(out)
end

function Mutations.merge(lists)
  local bestId, bestPriority, bestIndex
  for _, list in ipairs(lists or {}) do
    local norm = Mutations.normalize(list)
    for _, id in ipairs(norm or {}) do
      local def = Mutations.byId[id]
      local pri = def and (def.priority or 0) or 0
      local idx = orderIndex[id] or 9999
      if not bestId or pri > bestPriority or (pri == bestPriority and idx < bestIndex) then
        bestId, bestPriority, bestIndex = id, pri, idx
      end
    end
  end
  return bestId and { bestId } or nil
end

function Mutations.applyToSpec(spec, list)
  local norm = Mutations.normalize(list)
  if not (spec and norm) then return spec end
  spec.mutations = Mutations.clone(norm)
  for _, id in ipairs(norm) do
    local def = Mutations.byId[id]
    if def then
      if def.hpInc then spec.hp = math.floor((spec.hp or 0) * (1 + def.hpInc) + 0.5) end
      if def.dmgInc then spec.dmg = math.floor((spec.dmg or 0) * (1 + def.dmgInc) + 0.5) end
      if def.multicast then spec.multicast = (spec.multicast or 1) + def.multicast end
      if def.haste then spec.haste = (spec.haste or 0) + def.haste end
      if def.dmgReduce then spec.dmgReduce = (spec.dmgReduce or 0) + def.dmgReduce end
    end
  end
  return spec
end

return Mutations
