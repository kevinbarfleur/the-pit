-- tests/stats.lua
-- Tests de la COUCHE DE MODIFICATEURS (src/effects/stats.lua) : module PUR (aucun love).
-- Vérifie la formule, la COMMUTATIVITÉ des `increased` (= déterminisme sans tri), le clamp, l'arrondi,
-- le malus négatif (poison « -25% valeur de bouclier »), et le cas mods=nil -> base (golden inchangé).
--   Lancement : luajit tests/stats.lua
package.path = "./?.lua;" .. package.path

local S = require("src.effects.stats")

local function approx(a, b) return math.abs(a - b) < 1e-9 end

local ok, err = pcall(function()
  -- mods=nil/vide -> base (rétro-compat, golden-safe)
  assert(S.resolve(10) == 10, "nil mods -> base")
  assert(S.resolve(10, {}) == 10, "mods vides -> base")

  -- flat additif
  assert(S.resolve(10, { S.flat(5) }) == 15, "flat")
  assert(S.resolve(10, { S.flat(5), S.flat(-2) }) == 13, "flat cumul")

  -- increased : additifs entre eux
  assert(approx(S.resolve(10, { S.increased(0.5) }), 15), "increased 50%")
  assert(approx(S.resolve(10, { S.increased(0.5), S.increased(0.5) }), 20), "increased additifs -> 10*(1+1)")

  -- more : multiplicatifs
  assert(approx(S.resolve(10, { S.more(0.5) }), 15), "more 50%")
  assert(approx(S.resolve(10, { S.more(0.5), S.more(0.5) }), 22.5), "more multiplicatifs -> 10*1.5*1.5")

  -- combinaison flat -> increased -> more
  assert(approx(S.resolve(10, { S.flat(5), S.increased(1.0), S.more(0.5) }), 45), "(10+5)*2*1.5 = 45")

  -- DÉTERMINISME : l'ordre des mods n'affecte PAS le résultat (increased commutatifs)
  local a = S.resolve(20, { S.increased(0.3), S.flat(4), S.increased(-0.1), S.more(0.2) })
  local b = S.resolve(20, { S.more(0.2), S.increased(-0.1), S.increased(0.3), S.flat(4) })
  assert(approx(a, b), "ordre des mods indifferent -> deterministe")

  -- malus négatif (poison) + arrondi
  assert(approx(S.resolve(15, { S.increased(-0.25) }), 11.25), "malus -25% : 15 -> 11.25")
  assert(S.resolve(15, { S.increased(-0.25) }, { round = "floor" }) == 11, "floor -> 11")
  assert(S.resolve(15, { S.increased(-0.25) }, { round = "nearest" }) == 11, "nearest -> 11")

  -- clamp (anti-explosion : cap des dégâts-pris du choc, plancher des stats)
  assert(S.resolve(10, { S.more(10) }, { max = 30 }) == 30, "clamp max")
  assert(S.resolve(10, { S.increased(-2.0) }, { min = 0 }) == 0, "clamp min (jamais negatif)")

  print("  stats : flat/increased/more + commutativite (deterministe) + clamp + arrondi + malus negatif OK")
end)

if ok then
  print("=> STATS OK : couche de modificateurs deterministe.")
else
  print("=> STATS FAIL :")
  print(err)
  os.exit(1)
end
