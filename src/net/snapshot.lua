-- src/net/snapshot.lua
-- SNAPSHOT async (pilier #3, takeaway architectural #1). On n'affronte JAMAIS un joueur en DIRECT :
-- on fige un build (unités + positions + sigil + seed + version/tier) en données SÉRIALISABLES, on les
-- stocke, et on en SERT à d'autres joueurs. Aucun netcode temps réel, jouable hors-ligne. cf. CLAUDE.md §2.
--
-- Ce module est PUR (require Units/Place, aucun love) -> testable headless, déterministe. La PERSISTANCE
-- (IO) vit dans src/net/snapstore.lua. toComp() reconstruit une compo jouable par l'arène (positions
-- re-dérivées par côté via Place ; stats scalées par niveau comme buildComp -> duplicatas respectés).
--
-- Modèle : { version, tier, seed, shape, units = { { id, level, col, row }, ... } }

local Units = require("src.data.units")
local UnitResolver = require("src.core.unit_resolver")
local Place = require("src.combat.place")
local Mutations = require("src.run.mutations")

local Snapshot = {}
local SEP_FIELD, SEP_UNIT, SEP_ATTR = "\t", ";", ","

-- Capture : build LOGIQUE (liste {id, level, col, row, mutations?}) + sigil + seed + tier/version -> snapshot figé.
function Snapshot.capture(units, shape, seed, opts)
  opts = opts or {}
  local u = {}
  for i, x in ipairs(units) do
    u[i] = { id = x.id, level = x.level or 1, col = x.col, row = x.row,
      mutations = Mutations.clone(x.mutations) }
  end
  return { version = tostring(opts.version or "0"), tier = opts.tier or 0,
    seed = seed or 0, shape = shape or "carre", units = u }
end

-- Encodage SÛR (jamais de load() d'une string non fiable -> snapshots d'autrui = données externes) :
-- format ligne compact, déterministe (ordre des unités préservé). version<T>tier<T>seed<T>shape<T>units.
function Snapshot.encode(s)
  local parts = {}
  for _, x in ipairs(s.units) do
    local mut = Mutations.encode(x.mutations)
    if mut then
      parts[#parts + 1] = table.concat({ x.id, x.level, x.col, x.row, mut }, SEP_ATTR)
    else
      parts[#parts + 1] = table.concat({ x.id, x.level, x.col, x.row }, SEP_ATTR)
    end
  end
  return table.concat({ s.version, s.tier, s.seed, s.shape, table.concat(parts, SEP_UNIT) }, SEP_FIELD)
end

function Snapshot.decode(str)
  if type(str) ~= "string" then return nil end
  local v, tier, seed, shape, ustr = str:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
  if not v then return nil end
  local units = {}
  for chunk in (ustr or ""):gmatch("[^;]+") do
    local id, lvl, col, row, mut = chunk:match("^([%w_]+),(%-?%d+),(%-?%d+),(%-?%d+),?([%w_+]*)$")
    if id then
      units[#units + 1] = { id = id, level = tonumber(lvl), col = tonumber(col), row = tonumber(row),
        mutations = Mutations.decode(mut) }
    end
  end
  return { version = v, tier = tonumber(tier) or 0, seed = tonumber(seed) or 0, shape = shape, units = units }
end

-- Reconstruit une compo jouable (specs d'arène) pour un CÔTÉ. Positions re-dérivées par Place (mirroir
-- gauche/droite) ; stats scalées par niveau. Ignore les ids inconnus (snapshot d'une version étrangère).
function Snapshot.toComp(s, side)
  side = side or 1
  local facing = (side < 0) and 1 or -1
  local placed = {}
  for _, x in ipairs(s.units) do
    if Units[x.id] then
      placed[#placed + 1] = { id = x.id, level = x.level or 1, col = x.col, row = x.row,
        mutations = Mutations.clone(x.mutations) }
    end
  end
  if #placed == 0 then return {} end
  local b = Place.bounds(placed)
  local comp = {}
  for _, p in ipairs(placed) do
    local stats = UnitResolver.statsFor(p.id, p.level)
    local px, py = Place.pos(p.col, p.row, side, b)
    local effects = (p.level or 1) > 1 and UnitResolver.hasAuthoredLevel(p.id) and UnitResolver.effectsFor(p.id, p.level) or nil
    local spec = { id = p.id, level = p.level,
      hp = stats.hp, dmg = stats.dmg, cd = stats.cd,
      depth = b.maxC - p.col, row = p.row, effects = effects, x = px, y = py, facing = facing }
    comp[#comp + 1] = Mutations.applyToSpec(spec, p.mutations)
  end
  return comp
end

return Snapshot
