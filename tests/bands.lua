-- tests/bands.lua
-- HARNAIS D'ÉQUILIBRAGE DE MASSE — garde-fous des BANDES (src/lab/bands) + de l'injection relique/commandant
-- (src/lab/compbuild opts), socle de tools/balancematrix. On vérifie l'INTÉGRITÉ (sans relancer la matrice
-- entière, trop longue pour check.sh) :
--   1. ids d'unités valides + slot <= boardLevel (sinon buildComp ignore SILENCIEUSEMENT l'unité) ;
--   2. declared == placed (chaque compo de bande construit bien TOUTES ses unités) ;
--   3. courbe de coût croissante early < mid < end (l'axe d'investissement est bien ordonné) ;
--   4. champ de chaque bande entièrement résolvable (catalogue OU bandes) ;
--   5. injection relique + commandant via Compbuild.toComp(opts) = FIDÈLE (cap multicast tient) ;
--   6. les 6 commandants attendus sont bien dérivés du roster (commandBonus).
-- Déterministe, headless. Lancement : luajit tests/bands.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Bands = require("src.lab.bands")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Compositions = require("src.data.compositions")
local Units = require("src.data.units")
local Relics = require("src.data.relics")
local Match = require("src.combat.match")

local ok, err = pcall(function()
  -- 1+2) intégrité des compos de bande : ids valides, slots bornés, declared == placed.
  local costByBand = {}
  for _, bandKey in ipairs(Bands.order) do
    assert(Bands.list[bandKey], "bande presente: " .. bandKey)
    costByBand[bandKey] = {}
    for _, c in ipairs(Bands.list[bandKey]) do
      assert(c.sigil == "carre", "sigils geles -> carre uniquement: " .. c.id)
      assert(c.boardLevel >= 3 and c.boardLevel <= 9, "boardLevel 3..9: " .. c.id)
      local seen = {}
      for _, u in ipairs(c.units) do
        assert(Units[u.id], "unite inconnue: " .. tostring(u.id) .. " (" .. c.id .. ")")
        assert(u.slot >= 1 and u.slot <= c.boardLevel, "slot <= boardLevel: " .. c.id .. " " .. u.id .. " slot=" .. u.slot)
        assert(not seen[u.slot], "slot unique: " .. c.id .. " slot=" .. u.slot)
        seen[u.slot] = true
      end
      -- declared == placed : aucune unité silencieusement perdue (slot non débloqué).
      local comp = Compbuild.toComp(c, -1)
      local placed = 0
      for _, s in ipairs(comp) do if not s.isCommander then placed = placed + 1 end end
      assert(placed == #c.units, "declared==placed: " .. c.id .. " (" .. placed .. "/" .. #c.units .. ")")
      costByBand[bandKey][#costByBand[bandKey] + 1] = Compcost.of(c).score
    end
  end

  -- 3) courbe de coût croissante : min(end) > max(early), et mid entre les deux (l'investissement est ordonné).
  local function minmax(t) local lo, hi = math.huge, -math.huge; for _, v in ipairs(t) do lo = math.min(lo, v); hi = math.max(hi, v) end return lo, hi end
  local eLo, eHi = minmax(costByBand.early)
  local mLo, mHi = minmax(costByBand.mid)
  local _, endHi = minmax(costByBand.end_)
  local endLo = minmax(costByBand.end_)
  assert(mLo >= eLo, "mid >= early (cout): " .. mLo .. " >= " .. eLo)
  assert(endLo > eHi, "end > early (cout strict): " .. endLo .. " > " .. eHi)
  assert(endHi >= mHi, "end >= mid (cout): " .. endHi .. " >= " .. mHi)

  -- 4) champ de chaque bande : chaque id résout (catalogue OU bande) et se construit côté droit.
  for _, bandKey in ipairs(Bands.order) do
    assert(Bands.field[bandKey] and #Bands.field[bandKey] >= 1, "champ non vide: " .. bandKey)
    for _, id in ipairs(Bands.field[bandKey]) do
      local c = Bands.byId[id] or Compositions.byId[id]
      assert(c, "champ resoluble: " .. bandKey .. " -> " .. id)
      assert(#Compbuild.toComp(c, 1) >= 1, "champ constructible: " .. id)
    end
  end

  -- 5) injection relique + commandant FIDÈLE : sur la vitrine multicast, hookjaw front porte 1 (natif),
  --    +echo_crown -> 2, +maggot_king (cmd) -> 2, +les deux -> 3 (cap MULTICAST_MAX tient).
  local function frontMulticast(comp)
    local f
    for _, s in ipairs(comp) do
      if not s.isCommander and (s.multicast or 0) > 0 then
        if not f or (s.depth or 0) < (f.depth or 0) then f = s end
      end
    end
    return f and f.multicast or 0
  end
  local vit = Bands.byId["end_shock_multicast"]
  assert(frontMulticast(Compbuild.toComp(vit, -1)) == 1, "baseline multicast front = 1")
  assert(frontMulticast(Compbuild.toComp(vit, -1, { relics = { "echo_crown" } })) == 2, "+echo_crown -> 2")
  assert(frontMulticast(Compbuild.toComp(vit, -1, { commander = "maggot_king" })) == 2, "+maggot_king -> 2")
  assert(frontMulticast(Compbuild.toComp(vit, -1, { relics = { "echo_crown" }, commander = "maggot_king" })) == 3,
    "echo_crown + maggot_king -> cap 3 (MULTICAST_MAX)")
  -- commandant présent comme spec intouchable dans le comp.
  local hasCmd = false
  for _, s in ipairs(Compbuild.toComp(vit, -1, { commander = "bellows_priest" })) do
    if s.isCommander then assert(s.untargetable, "commandant intouchable"); hasCmd = true end
  end
  assert(hasCmd, "commandant injecte present dans le comp")

  -- 6) les 6 commandants : exactement les unités à commandBonus (le harnais les balaye toutes).
  local cmds = {}
  for _, id in ipairs(Units.order) do if Units[id].commandBonus then cmds[#cmds + 1] = id end end
  assert(#cmds == 6, "6 commandants attendus (commandBonus), obtenu " .. #cmds)

  -- 7) reliques INERTES en combat = celles sans champ `op` (eco/run-only) : Relics.apply ne mute pas la compo
  --    -> Δ stats nul (le harnais les marque inertes, Δ~0 attendu).
  local inert = 0
  for _, rid in ipairs(Relics.order) do if not Relics[rid].op then inert = inert + 1 end end
  assert(inert >= 1 and inert < #Relics.order, "des reliques eco/run inertes existent mais pas toutes: " .. inert)

  -- 8) déterminisme : même config + seed -> même verdict (socle du rapport reproductible).
  local L = Compbuild.toComp(Bands.byId["mid_poison"], -1, { relics = { "kings_bowl" } })
  local R = Compbuild.toComp(Bands.byId["mid_tank"], 1)
  local r1 = Match.run(L, R, 777, { tickCap = 8000 })
  local r2 = Match.run(L, R, 777, { tickCap = 8000 })
  assert(r1.win == r2.win and r1.ticks == r2.ticks, "meme config+seed -> meme verdict")
end)

if not ok then
  io.stderr:write("BANDS FAIL: " .. tostring(err) .. "\n")
  os.exit(1)
end
print("=> BANDS OK : integrite bandes + courbe de cout + champ + injection relique/commandant + 6 commandants.")
