-- tools/scenariosim.lua
-- SWEEP de simulations sur le CATALOGUE (banc d'essai, complément de runsim) :
--   1. SCENARIOS : chaque matchup featured du dictionnaire × M seeds -> win% stable de A (gauche).
--      Couvre les axes clutch / niveau-de-board / combo-croisé / miroir d'un coup.
--   2. SIGILS : chaque famille DoT (compo parfaite) rejouée sur les 5 SIGILS vs un adversaire commun
--      -> « le sigil compte-t-il ? » (teste le pilier « 1 forme = 1 archétype qui l'aime »).
-- Déterministe : même M -> même rapport. Lancement : luajit tools/scenariosim.lua [M]
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")

local M = tonumber(arg and arg[1]) or 60
local BASE = 5000000
local HPM = tonumber(os.getenv("PIT_HP_MULT")) -- bouton global de PV : sweep `PIT_HP_MULT=N` (sinon constante Arena.HP_MULT)
local SIGILS = { "carre", "croix", "anneau", "diamant", "ligne" }

local function winRate(L, R, seedBase)
  local w, dec = 0, 0
  for i = 1, M do
    local r = Match.run(L, R, seedBase + i, { hpMult = HPM })
    if r.win then w = w + 1 end
    if r.decided then dec = dec + 1 end
  end
  return w / M, dec / M
end

local function cloneWithSigil(comp, sigil)
  local c = {}; for k, v in pairs(comp) do c[k] = v end
  c.sigil = sigil
  return c
end

local function num(v) if v == math.floor(v) then return string.format("%d", v) else return string.format("%.3f", v) end end

-- ─────────────────── 1) SWEEP SCENARIOS ───────────────────
print(string.format("== SWEEP SCENARIOS : win%% de A (gauche) sur %d seeds/scenario ==", M))
print(string.format("%-22s %7s %8s %9s  %s", "scenario", "winA", "decided", "dInvest", "A vs B"))
local scRows = {}
for si, sc in ipairs(Compositions.scenarios) do
  local cA, cB = Compositions.byId[sc.a], Compositions.byId[sc.b]
  local L = Compbuild.toComp(cA, -1)
  local R = Compbuild.toComp(cB, 1)
  local wr, dec = winRate(L, R, BASE + si * 1000)
  local dInv = Compcost.of(cA).score - Compcost.of(cB).score
  scRows[#scRows + 1] = { id = sc.id, wr = wr, dec = dec, dInv = dInv, a = sc.a, b = sc.b }
  print(string.format("%-22s %6.0f%% %7.0f%% %+9.2f  %s vs %s", sc.id, wr * 100, dec * 100, dInv, sc.a, sc.b))
end

-- ─────────────────── 2) SWEEP SIGILS (chaque famille DoT vs tank) ───────────────────
local FAMILIES = {
  poison = "poison_diamant_perfect", burn = "burn_ligne_perfect",
  rot = "rot_carre_perfect", bleed = "bleed_anneau_perfect",
}
local FAM_ORDER = { "poison", "burn", "bleed", "rot" }
local tankR = Compbuild.toComp(Compositions.byId["tank_carre"], 1)
print(string.format("\n== SWEEP SIGILS : chaque famille (compo parfaite) sur les 5 sigils vs tank_carre (%d seeds) ==", M))
io.write(string.format("%-9s", "famille"))
for _, sg in ipairs(SIGILS) do io.write(string.format("%9s", sg)) end
io.write("   (sigil natif *)\n")
local sigRows = {}
for _, fam in ipairs(FAM_ORDER) do
  local base = Compositions.byId[FAMILIES[fam]]
  io.write(string.format("%-9s", fam))
  sigRows[fam] = {}
  for _, sg in ipairs(SIGILS) do
    local L = Compbuild.toComp(cloneWithSigil(base, sg), -1)
    local wr = winRate(L, tankR, BASE + 900000)
    sigRows[fam][sg] = wr
    io.write(string.format("%8.0f%%", wr * 100) .. (base.sigil == sg and "*" or " "))
  end
  io.write("\n")
end

-- ─────────────────── runs/scenariosim.json ───────────────────
local parts = { string.format('"m":%d', M) }
local sj = {}
for _, r in ipairs(scRows) do
  sj[#sj + 1] = string.format('"%s":{"winA":%s,"decided":%s,"dinvest":%s}', r.id, num(r.wr), num(r.dec), num(r.dInv))
end
parts[#parts + 1] = '"scenarios":{' .. table.concat(sj, ",") .. "}"
local gj = {}
for _, fam in ipairs(FAM_ORDER) do
  local cells = {}
  for _, sg in ipairs(SIGILS) do cells[#cells + 1] = string.format('"%s":%s', sg, num(sigRows[fam][sg])) end
  gj[#gj + 1] = string.format('"%s":{%s}', fam, table.concat(cells, ","))
end
parts[#parts + 1] = '"sigil_sweep":{' .. table.concat(gj, ",") .. "}"
os.execute("mkdir -p runs")
local f = io.open("runs/scenariosim.json", "w")
if f then f:write("{" .. table.concat(parts, ",") .. "}\n"); f:close(); print("\n=> ecrit runs/scenariosim.json") end
