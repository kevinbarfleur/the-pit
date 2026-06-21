-- tests/payoff.lua
-- FRAMEWORK PAYOFF (cf. docs/research/payoff-framework.md) : on PROUVE que les renforcements sont FORTS
-- mais BORNÉS (les caps sont des bornes de conception, pas des placeholders). Couvre :
--   · spread proportionnel à la charge de la source PUIS plafonné (poison CAP 12, MIN 4) + flag viaSpread (profondeur 1)
--   · bouclier périodique : value cappée ×3, cd planché 2 s, réflexion ≤ 0.60, surcharge ≤ 2× ; re-cast récurrent
--   · le cap de la couche de modificateurs (resolve {max})
-- Déterministe (RNG seedé), SIM pure + build headless. Lancement : luajit tests/payoff.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Arena = require("src.combat.arena")
local Build = require("src.scenes.build")
local Compbuild = require("src.lab.compbuild")
local Compositions = require("src.data.compositions")
local Units = require("src.data.units")
local Stats = require("src.effects.stats")
local Palette = require("src.core.palette")

local function U(id, over)
  local u = Units[id]
  local s = { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = u.effects,
    depth = 0, row = 0, shield = 0, x = 0, y = 0, facing = 1 }
  if over then for k, v in pairs(over) do s[k] = v end end
  return s
end

local function freshBoard()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  return b
end

local ok, err = pcall(function()
  -- ════════ 1. SPREAD proportionnel à l'investissement PUIS plafonné ════════

  -- (a) grosse charge sur la cible -> la contagion est CAPPÉE à 12 (anti-snowball).
  do
    local a = Arena.new({ left = { U("plague_bearer") },
      right = { U("marauder", { row = 0 }), U("marauder", { row = 1 }) }, autoReset = false, seed = 1 })
    local pb, t0, t1 = a.units[1], a.units[2], a.units[3]
    t0.dots.poison = { -- pré-charge : 3 stacks forts = load 30
      { dps = 10, remaining = 180, acc = 0, weaken = 0, source = pb },
      { dps = 10, remaining = 180, acc = 0, weaken = 0, source = pb },
      { dps = 10, remaining = 180, acc = 0, weaken = 0, source = pb },
    }
    local got
    a.bus:on("spread", function(e) if e.to == t1 then got = e end end)
    a:hit(pb, t0)
    assert(got, "contagion: le voisin reçoit un spread")
    assert(got.magnitude == 12 and got.capped, "spread CAPPÉ à 12 sur grosse charge (obtenu " .. tostring(got.magnitude) .. ")")
    local last = t1.dots.poison[#t1.dots.poison]
    assert(last and last.viaSpread, "le stack de contagion porte viaSpread (profondeur 1)")
  end

  -- (b) cible vierge -> la contagion tombe au plancher MIN 4 (et pas cappée).
  do
    local a = Arena.new({ left = { U("plague_bearer") },
      right = { U("marauder", { row = 0 }), U("marauder", { row = 1 }) }, autoReset = false, seed = 2 })
    local pb, t0, t1 = a.units[1], a.units[2], a.units[3]
    local got
    a.bus:on("spread", function(e) if e.to == t1 then got = e end end)
    a:hit(pb, t0)
    assert(got and got.magnitude == 4 and not got.capped,
      "spread MIN 4 sur faible charge (obtenu " .. tostring(got and got.magnitude) .. ")")
  end

  -- (c) proportionnalité : charge moyenne -> magnitude STRICTEMENT entre MIN et CAP.
  do
    local a = Arena.new({ left = { U("plague_bearer") },
      right = { U("marauder", { row = 0 }), U("marauder", { row = 1 }) }, autoReset = false, seed = 3 })
    local pb, t0, t1 = a.units[1], a.units[2], a.units[3]
    t0.dots.poison = { { dps = 9, remaining = 180, acc = 0, weaken = 0, source = pb } } -- load ~9+2
    local got; a.bus:on("spread", function(e) if e.to == t1 then got = e end end)
    a:hit(pb, t0)
    assert(got and got.magnitude > 4 and got.magnitude < 12, "spread proportionnel (4 < mag < 12) ; obtenu " .. tostring(got.magnitude))
  end

  print("  payoff : spread proportionnel à la charge, cappé (12) + plancher (4) + viaSpread OK")

  -- ════════ 2. BOUCLIERS PÉRIODIQUES : caps de résolution build ════════
  do
    local b = freshBoard()
    b:placeId(5, "ward_weaver"); b:placeId(2, "barrier_savant"); b:placeId(6, "surge_warden")
    local comp = b:buildComp(-1)
    local sc; for _, s in ipairs(comp) do if s.id == "ward_weaver" then sc = s.shieldCaster end end
    assert(sc, "ward_weaver a un shieldCaster résolu")
    assert(sc.value == 40, "value = 20×(1+0.5+0.5) = 40, sous le cap ×3 (60) ; obtenu " .. tostring(sc.value))
    assert(sc.value <= 20 * 3, "value <= cap ×3")
    assert(sc.cd == 180 and sc.cd >= 120, "cd = 240×(1−0.25) = 180, >= plancher 2 s (120)")
    assert(sc.overcharge == true, "surge_warden active la surcharge")
  end

  -- réflexion + largeur (mirror_ward) : reflect <= 0.60, rayon 2 ajoute des cibles.
  do
    local b = freshBoard()
    b:placeId(5, "ward_weaver"); b:placeId(4, "mirror_ward")
    -- cibles de base du centre (carré) = 2,4,6,8 occupées ? ici 4 occupé -> au moins 1. radius 2 en ajoute.
    b:placeId(2, "skeleton"); b:placeId(1, "skeleton") -- 1 = voisin-de-voisin (rayon 2 via 2 et 4)
    local comp = b:buildComp(-1)
    local sc; for _, s in ipairs(comp) do if s.id == "ward_weaver" then sc = s.shieldCaster end end
    assert(sc.reflect <= 0.6 and sc.reflect > 0, "réflexion posée et <= 0.60 ; obtenu " .. tostring(sc.reflect))
    local has1 = false; for _, s in ipairs(sc.targetSlots) do if s == 1 then has1 = true end end
    assert(has1, "rayon 2 : le slot 1 (voisin-de-voisin) devient une cible")
  end

  print("  payoff : bouclier périodique — value ×3 / cd plancher 2 s / réflexion <= 0.60 / rayon 2 OK")

  -- ════════ 3. SURCHARGE bornée à 2× + RE-CAST récurrent (combat réel) ════════
  do
    local L = Compbuild.toComp(Compositions.byId["ward_fortress_carre"], -1)
    local R = Compbuild.toComp(Compositions.byId["bruiser_carre"], 1)
    local a = Arena.new({ left = L, right = R, autoReset = false, seed = 1031 })
    local casts, maxShield = 0, 0
    a.bus:on("shield_cast", function() casts = casts + 1 end)
    local t = 0
    while t < 3000 do
      a:update(1.0, t); t = t + 1
      for _, u in ipairs(a.units) do if (u.shield or 0) > maxShield then maxShield = u.shield end end
      if a.over then break end
    end
    assert(casts >= 2, "bouclier RE-CASTÉ périodiquement (>= 2 casts) ; obtenu " .. casts)
    assert(maxShield <= 80, "surcharge plafonnée à 2× value (80) ; obtenu " .. maxShield)
  end

  print("  payoff : surcharge <= 2× value + re-cast périodique en combat OK")

  -- ════════ 4. CAP de la couche de modificateurs (resolve {max}) ════════
  assert(Stats.resolve(20, { Stats.increased(5) }, { max = 60, round = "nearest" }) == 60, "resolve plafonne à max (×3)")
  assert(Stats.resolve(6, { Stats.increased(0.5) }, { max = 18, round = "nearest" }) == 9, "resolve +50% sous cap = 9")
  print("  payoff : cap de resolve (×3) OK")
end)

if ok then
  print("=> PAYOFF OK : renforcements forts mais bornés (spread + boucliers + caps).")
else
  print("=> PAYOFF FAIL :")
  print(err)
  os.exit(1)
end
