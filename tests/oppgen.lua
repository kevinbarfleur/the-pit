-- tests/oppgen.lua
-- GÉNÉRATEUR D'ADVERSAIRE procédural (A4, src/data/oppgen.lua) : DÉTERMINISME (seedé) + VALIDITÉ
-- (ids/cases/niveaux valides, cases UNIQUES) + SCALING (taille croît avec le round, bornée [2,9] et par
-- les slots ; un tier élevé fait apparaître des rangs supérieurs). Module SIM-pur -> headless avec le mock.
--   Lancement : luajit tests/oppgen.lua   (depuis la racine du projet)
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local OppGen = require("src.data.oppgen")
local Units = require("src.data.units")

local function rng(seed) return love.math.newRandomGenerator(seed) end
local ODDS = {
  [1] = { 100, 0, 0, 0, 0 }, [2] = { 70, 30, 0, 0, 0 }, [3] = { 44, 34, 20, 2, 0 },
  [4] = { 25, 30, 30, 13, 2 }, [5] = { 15, 20, 30, 25, 10 },
}

local ok, err = pcall(function()
  -- ── DÉTERMINISME : même seed -> adversaire identique (rejouabilité / snapshots). ──
  local a = OppGen.generate({ round = 7, tier = 3, slots = 7, rng = rng(123), odds = ODDS })
  local b = OppGen.generate({ round = 7, tier = 3, slots = 7, rng = rng(123), odds = ODDS })
  assert(#a.units == #b.units, "déterminisme : même taille")
  for i = 1, #a.units do
    local x, y = a.units[i], b.units[i]
    assert(x.id == y.id and x.col == y.col and x.row == y.row and x.level == y.level, "déterminisme : unité " .. i)
  end
  print("  déterminisme : OK (" .. #a.units .. " unités stables)")

  -- ── VALIDITÉ : ids réels, cases 0..2, niveaux 1..3, cases UNIQUES, au moins 1 unité. ──
  assert(#a.units >= 1, "au moins une unité")
  local seen = {}
  for _, u in ipairs(a.units) do
    assert(Units[u.id], "id valide : " .. tostring(u.id))
    assert(u.col >= 0 and u.col <= 2 and u.row >= 0 and u.row <= 2, "case dans 0..2")
    assert(u.level >= 1 and u.level <= 3, "niveau borné 1..3")
    local k = u.col .. "\0" .. u.row
    assert(not seen[k], "case unique (pas deux unités sur la même case)")
    seen[k] = true
  end
  print("  validité : OK (ids/cases/niveaux ; cases uniques)")

  -- ── SCALING : taille croît avec le round, bornée [2,9], et bornée par les slots. ──
  local small = OppGen.generate({ round = 1, tier = 1, slots = 9, rng = rng(1), odds = ODDS })
  local big = OppGen.generate({ round = 14, tier = 5, slots = 9, rng = rng(1), odds = ODDS })
  assert(#small.units >= 2, "taille mini 2")
  assert(#big.units <= 9, "taille maxi 9")
  assert(#small.units < #big.units, "la taille croît avec le round")
  local capped = OppGen.generate({ round = 14, tier = 5, slots = 3, rng = rng(1), odds = ODDS })
  assert(#capped.units <= 3, "taille bornée par les slots")
  print("  scaling : OK (round " .. #small.units .. "->" .. #big.units .. " ; cap slots=" .. #capped.units .. ")")

  -- ── TIER : un tier élevé fait APPARAÎTRE des rangs supérieurs (sur un échantillon de seeds). ──
  local hiRanks = false
  for s = 1, 40 do
    local g = OppGen.generate({ round = 10, tier = 5, slots = 9, rng = rng(s), odds = ODDS })
    for _, u in ipairs(g.units) do
      if (Units[u.id].rank or 1) >= 3 then hiRanks = true; break end
    end
    if hiRanks then break end
  end
  assert(hiRanks, "tier élevé -> des rangs >= 3 apparaissent")
  print("  tier : OK (rangs supérieurs présents au tier 5)")
end)

if not ok then
  print("OPPGEN FAIL : " .. tostring(err))
  os.exit(1)
end
print("=> OPPGEN OK : déterminisme + validité + scaling + tier.")
