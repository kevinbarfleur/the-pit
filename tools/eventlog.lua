-- tools/eventlog.lua
-- Logger d'événements de combat : s'abonne au bus d'une arène et accumule UN enregistrement plat
-- par événement (attack / damage / death). Sérialisable en JSONL (1 ligne/événement) pour analyse
-- d'équilibrage hors-ligne, et fournit une EMPREINTE stable pour les golden-logs / le déterminisme.
-- N'est PAS chargé par le jeu live (coût zéro). cf. docs/research/engine-architecture.md §8.

local EventLog = {}
EventLog.__index = EventLog

-- Attache un logger à une arène (s'abonne à son bus). `meta` = champs constants ajoutés (ex. seed).
function EventLog.attach(arena, meta)
  local self = setmetatable({ records = {}, arena = arena, meta = meta or {} }, EventLog)
  local bus = arena.bus
  bus:on("attack", function(u)
    self:push("attack", { src = u.id, src_slot = u.slot, team = u.team })
  end)
  bus:on("damage", function(r)
    self:push("damage", {
      src = r.source and r.source.id, src_slot = r.source and r.source.slot,
      tgt = r.target.id, tgt_slot = r.target.slot, tgt_team = r.target.team,
      cause = r.cause, raw = r.raw, absorbed = r.absorbed, hp = r.hp,
      overkill = r.overkill, hp_after = r.hpAfter,
    })
  end)
  bus:on("death", function(u)
    self:push("death", { tgt = u.id, tgt_slot = u.slot, team = u.team })
  end)
  return self
end

function EventLog:push(ev, fields)
  fields.tick = self.arena.t
  fields.ev = ev
  for k, v in pairs(self.meta) do if fields[k] == nil then fields[k] = v end end
  self.records[#self.records + 1] = fields
end

-- ── Sérialisation JSON minimale (records plats : string/number/bool, jamais de table imbriquée) ──
local function jsonValue(v)
  local t = type(v)
  if t == "string" then return '"' .. v:gsub('[\\"]', '\\%0') .. '"' end
  if t == "number" then
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.4g", v)
  end
  if t == "boolean" then return v and "true" or "false" end
  return "null"
end

-- Clés triées -> ordre STABLE, donc JSONL diff-able et empreinte reproductible.
local function jsonObject(rec)
  local keys = {}
  for k in pairs(rec) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = '"' .. k .. '":' .. jsonValue(rec[k])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function EventLog:toJSONL()
  local lines = {}
  for i = 1, #self.records do lines[i] = jsonObject(self.records[i]) end
  return table.concat(lines, "\n")
end

-- Empreinte stable de la séquence (golden-log / déterminisme). djb2, sans dépendance.
function EventLog.hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

function EventLog:fingerprint()
  return EventLog.hash(self:toJSONL())
end

return EventLog
