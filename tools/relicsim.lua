-- tools/relicsim.lua
-- CALIBRAGE DES RELIQUES (répétable, déterministe). Pour chaque relique : son matchup-MAISON, base (sans) vs
-- +relique (avec), delta, flag. Deux types de matchup :
--   · "mirror"  : l'archétype de la relique CONTRE LUI-MÊME (combat équitable) -> mesure la PUISSANCE
--                 UNIVERSELLE de la relique. Une relique qui pousse un miroir à ~100% est trop forte (GATE).
--   · "counter" : l'archétype CONTRE SA CIBLE désignée (ex. anti-soin vs sustain_carre) -> mesure si la relique
--                 remplit son RÔLE (forte ici = INTENTION, pas un bug).
-- Principe (cf. docs/research/relics-design.md) : une relique INCLINE un matchup, ne le GATE pas. On dial un
-- levier à la fois puis on relance. famines_math (conditionnel ≤3 unités) + plague_communion (besoin d'une
-- compo multi-afflictions) sont hors-sim -> couverts par tests/relics.lua. Lancement : luajit tools/relicsim.lua [M]
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Match = require("src.combat.match")
local Relics = require("src.data.relics")

local M = tonumber(arg and arg[1]) or 200
local SEED = 12000000

-- { relique, compo attaquante, compo défenseuse }. ADVERSAIRES RÉELS (pas de miroir : il surestime tout à ~100%).
-- L'attaquant est en POSITION D'OUTSIDER ou de counter -> on lit si la relique INCLINE le matchup (lui donne sa
-- chance) sans le GATER (~100% = plus de contre-jeu). base ≠ 50% -> signal exploitable.
local CASES = {
  -- stats / cadence / défensives : le bruiser (témoin sans DoT) face à son counter dur (le tank).
  { "bloodstone", "bruiser_carre", "tank_carre" },
  { "carapace", "bruiser_carre", "tank_carre" },
  { "aegis", "bruiser_carre", "tank_carre" },
  { "whetstone", "bruiser_carre", "tank_carre" },
  { "thornguard", "bruiser_carre", "tank_carre" },
  { "sacred_shield", "bruiser_carre", "tank_carre" },
  { "second_breath", "bruiser_carre", "tank_carre" },
  { "feeding_frenzy", "bruiser_carre", "tank_carre" },
  -- amplis d'affliction : l'archétype face au tank (là où il était faible).
  { "kings_bowl", "poison_diamant_perfect", "tank_carre" },
  { "ember_heart", "burn_ligne_perfect", "tank_carre" },
  { "weeping_nail", "bleed_anneau_perfect", "tank_carre" },
  { "grave_cap", "rot_carre_perfect", "tank_carre" },
  { "forked_tongue", "shock_storm_carre", "tank_carre" },
  -- anti-soin : l'archétype face à la compo SUSTAIN (rôle voulu : percer/dépasser le soin).
  { "hollow_choir", "bleed_anneau_perfect", "sustain_carre" },
  { "everburn", "burn_ligne_perfect", "sustain_carre" },
  { "open_wounds", "bleed_anneau_perfect", "sustain_carre" },
}

local function comp(id, side) return Compbuild.toComp(Compositions.byId[id], side) end
local function withRelic(id, side, relic)
  local c = Compbuild.toComp(Compositions.byId[id], side); Relics.apply(c, Relics[relic]); return c
end
local function winrate(L, R, base)
  local w = 0
  for i = 1, M do if Match.run(L, R, base + i, {}).win then w = w + 1 end end
  return w / M
end
local function shortName(id) return (id:gsub("_carre", ""):gsub("_perfect", ""):gsub("_diamant", ""):gsub("_ligne", ""):gsub("_anneau", ""):gsub("_storm", "")) end

print(string.format("== RELICSIM : impact par relique dans son matchup-maison (%d matchs/cellule) ==", M))
print(string.format("%-16s %-20s %5s %8s %7s  %s", "relique", "matchup", "base", "+relic", "delta", "flag"))
local rows, gates = {}, 0
local si = 0
for _, cse in ipairs(CASES) do
  local relic, atk, def = cse[1], cse[2], cse[3]
  si = si + 1
  local seedBase = SEED + si * 1000
  local base = winrate(comp(atk, -1), comp(def, 1), seedBase)
  local amp = winrate(withRelic(atk, -1, relic), comp(def, 1), seedBase)
  local delta = amp - base
  local flag = ""
  if amp >= 0.92 and base < 0.90 then flag = "GATE (la relique cree un ~certain)"; gates = gates + 1
  elseif delta >= 0.45 then flag = "tres fort (+45pts)"
  elseif math.abs(delta) < 0.03 then flag = "inerte" end
  print(string.format("%-16s %-20s %4.0f%% %7.0f%% %+6.0f  %s",
    relic, shortName(atk) .. " v " .. shortName(def), base * 100, amp * 100, delta * 100, flag))
  rows[#rows + 1] = { relic = relic, base = base, amp = amp, delta = delta }
end
print(string.format("\n%d relique(s) flaggée(s) GATE (trop fortes en miroir -> dial le levier).", gates))

-- runs/relicreport.json (diff-able).
local function num(v) return string.format("%.3f", v) end
local parts = {}
for _, r in ipairs(rows) do
  parts[#parts + 1] = string.format('"%s":{"base":%s,"amp":%s,"delta":%s}',
    r.relic, num(r.base), num(r.amp), num(r.delta))
end
os.execute("mkdir -p runs")
local f = io.open("runs/relicreport.json", "w")
if f then f:write(string.format('{"m":%d,"relics":{%s}}\n', M, table.concat(parts, ","))); f:close(); print("=> runs/relicreport.json") end
