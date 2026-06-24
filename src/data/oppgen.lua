-- src/data/oppgen.lua
-- GÉNÉRATEUR d'adversaire PROCÉDURAL, scalé au STADE du joueur + DÉTERMINISTE (seedé).
-- Remplace le pickEncounter f(round) (6 équipes figées qui répètent pit_sovereign après ~r12) par une
-- équipe COHÉRENTE avec le round / le tier de boutique / la capacité (slots) du joueur :
--   · TAILLE   ≈ la capacité du joueur (slots), bornée par une courbe de round (early plus petit) ;
--   · RANGS    tirés via les COTES du tier (le joueur affronte le même pool qu'il voit en boutique) ;
--   · NIVEAUX  qui montent TARD (miroir des merges du joueur fin de Puits) ;
--   · PLACEMENT tank/taunt/bouclier DEVANT (col 2), carries DERRIÈRE (col 0-1).
-- SIM-PUR : zéro love.* (le RNG seedé est INJECTÉ), array + ipairs uniquement. Sortie = format encounter
-- { key, generated=true, units = {{id, col, row, level}} } -> consommé par Build:buildRightComp comme un encounter.

local Units = require("src.data.units")

local OppGen = {}

-- Pool d'ids par rang (1..5), construit une fois depuis Units.pool.
local POOL_BY_RANK
local function poolByRank()
  if POOL_BY_RANK then return POOL_BY_RANK end
  POOL_BY_RANK = { {}, {}, {}, {}, {} }
  for _, id in ipairs(Units.pool or Units.order) do
    local u = Units[id]
    local r = (u and u.rank) or 1
    if r >= 1 and r <= 5 then POOL_BY_RANK[r][#POOL_BY_RANK[r] + 1] = id end
  end
  return POOL_BY_RANK
end

-- "frontness" : score de placement AVANT. Tank/taunt/bouclier/grosse vie -> front ; gros DPS -> recule.
local function frontness(id)
  local u = Units[id] or {}
  local s = (u.hp or 0)
  if u.taunt then s = s + 1000 end
  for _, e in ipairs(u.effects or {}) do
    if e.op == "shield_aura" or e.op == "shield_caster" or e.op == "aura_shield" then s = s + 200 end
    if e.op == "thorns" then s = s + 80 end
  end
  return s - (u.dmg or 0) * 2
end

-- Tire un rang (1..5) via une ligne d'odds {r1..r5}. Repli rang 1 si pas d'odds.
local function rollRank(odds, rng)
  if not odds then return 1 end
  local total = 0
  for r = 1, 5 do total = total + (odds[r] or 0) end
  if total <= 0 then return 1 end
  local x = rng:random() * total
  local acc = 0
  for r = 1, 5 do
    acc = acc + (odds[r] or 0)
    if x <= acc then return r end
  end
  return 1
end

-- Génère un adversaire scalé. opts = { round, tier, slots, rng (seedé OBLIGATOIRE), odds (table run.ODDS) }.
function OppGen.generate(opts)
  opts = opts or {}
  local rng = opts.rng
  local round = math.max(1, opts.round or 1)
  local slots = math.max(2, math.min(9, opts.slots or 3))
  local byRank = poolByRank()

  -- TIER EFFECTIF = max(tier joueur, plancher de round) -> escalade même si le joueur ne monte pas en tier.
  local roundTier = math.max(1, math.min(5, 1 + math.floor(round / 3)))
  local tier = math.max(1, math.min(5, math.max(opts.tier or 1, roundTier)))
  local odds = opts.odds and opts.odds[tier]

  -- TAILLE : ~ la capacité du joueur (slots), bornée par une courbe de round (l'early reste petit).
  local size = math.min(slots, math.max(2, 1 + math.floor((round + 2) / 2)))

  -- SÉLECTION : par unité, un rang via les odds, puis un id aléatoire du rang (repli rangs voisins si vide).
  local picks = {}
  for _ = 1, size do
    local r = rollRank(odds, rng)
    local bucket = byRank[r]
    local down = r
    while (not bucket or #bucket == 0) and down > 1 do down = down - 1; bucket = byRank[down] end
    local up = r
    while (not bucket or #bucket == 0) and up < 5 do up = up + 1; bucket = byRank[up] end
    if bucket and #bucket > 0 then picks[#picks + 1] = bucket[rng:random(1, #bucket)] end
  end
  if #picks == 0 then picks[1] = (Units.pool and Units.pool[1]) or "marauder" end

  -- NIVEAUX : escalade tardive (miroir des merges du joueur).
  local levels = {}
  for i = 1, #picks do
    local lvl = 1
    if round >= 9 and rng:random() < (round - 8) * 0.05 then lvl = 3
    elseif round >= 5 and rng:random() < (round - 4) * 0.07 then lvl = 2 end
    levels[i] = lvl
  end

  -- PLACEMENT : tri par frontness desc (tanks devant) ; remplit (col 2 -> 1 -> 0), centre (row 1) d'abord.
  local idx = {}
  for i = 1, #picks do idx[i] = i end
  table.sort(idx, function(a, b)
    local fa, fb = frontness(picks[a]), frontness(picks[b])
    if fa ~= fb then return fa > fb end
    return a < b
  end)
  local cells = {}
  for _, col in ipairs({ 2, 1, 0 }) do
    for _, row in ipairs({ 1, 0, 2 }) do cells[#cells + 1] = { col = col, row = row } end
  end
  local units = {}
  for n, i in ipairs(idx) do
    local cell = cells[n]
    if not cell then break end
    units[#units + 1] = { id = picks[i], col = cell.col, row = cell.row, level = levels[i] }
  end

  return { key = "pit_spawn", generated = true, units = units }
end

return OppGen
