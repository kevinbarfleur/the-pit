-- tests/snapshot.lua
-- SNAPSHOTS ASYNC (pilier #3). Vérifie : (1) le ROUND-TRIP capture->encode->decode (déterministe, sûr) ;
-- (2) toComp reconstruit une compo jouable (stats scalées par niveau, mirroir par côté) ; (3) le STORE
-- sert par (version, tier) en filtrant ; (4) le COLD-START retombe sur l'équipe IA (adversaire garanti).
--   Lancement : luajit tests/snapshot.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Snapshot = require("src.net.snapshot")
local Store = require("src.net.snapstore")

local ok, err = pcall(function()
  -- 1) ROUND-TRIP : capture -> encode (déterministe) -> decode = mêmes données.
  local units = {
    { id = "bandit", level = 1, col = 2, row = 0, mutations = { "echo_touched" } },
    { id = "witch", level = 2, col = 1, row = 1 },
  }
  local snap = Snapshot.capture(units, "croix", 4242, { version = "0.7", tier = 3 })
  local enc = Snapshot.encode(snap)
  assert(Snapshot.encode(snap) == enc, "encode deterministe")
  local dec = Snapshot.decode(enc)
  assert(dec.version == "0.7" and dec.tier == 3 and dec.seed == 4242 and dec.shape == "croix", "champs decodes")
  assert(#dec.units == 2 and dec.units[1].id == "bandit" and dec.units[1].mutations[1] == "echo_touched"
    and dec.units[2].id == "witch" and dec.units[2].level == 2,
    "unites decodees (id/level/positions)")

  -- 2) toComp : compo jouable, stats scalées par niveau (witch niv2 : hp 36 -> 65), mirroir par side.
  local comp = Snapshot.toComp(dec, 1)
  assert(#comp == 2, "2 unites reconstruites")
  local witch, bandit
  for _, u in ipairs(comp) do
    if u.id == "witch" then witch = u end
    if u.id == "bandit" then bandit = u end
  end
  assert(witch and witch.level == 2 and witch.hp == math.floor(36 * 1.8 + 0.5), "witch niv2 : hp scale")
  assert(bandit and bandit.mutations and bandit.mutations[1] == "echo_touched" and bandit.multicast == 2,
    "bandit muté : mutation snapshot bakee dans le spec")
  assert(comp[1].facing == -1, "side=1 -> regarde a gauche (mirroir)")

  -- 3) STORE : filtre version + tier (sert v0.7 de tier <= 5 ; pas le tier 9 ni la v0.6).
  Store.wipe()
  Store.save(Snapshot.capture(units, "carre", 1, { version = "0.7", tier = 1 }))
  Store.save(Snapshot.capture(units, "carre", 2, { version = "0.7", tier = 9 }))
  Store.save(Snapshot.capture(units, "carre", 3, { version = "0.6", tier = 1 }))
  local served = Store.serve("0.7", 5, love.math.newRandomGenerator(1))
  assert(served and served.tier == 1 and served.seed == 1, "sert le bon snapshot (v0.7, tier<=5)")
  assert(Store.serve("0.7", 0, love.math.newRandomGenerator(1)) == nil, "aucun candidat tier<=0 -> nil")

  -- 4) COLD-START : version inexistante -> repli equipe IA (la compo Encounter fournie par l'appelant).
  local aiComp = { { id = "skeleton" } }
  local comp2, meta = Store.serveComp("9.9", 1, 1, nil, aiComp)
  assert(comp2 == aiComp and meta.source == "ai_seed", "cold-start : adversaire IA garanti")
  -- match dispo -> source snapshot
  local _, meta2 = Store.serveComp("0.7", 5, 1, love.math.newRandomGenerator(1), aiComp)
  assert(meta2.source == "snapshot", "match -> on sert un snapshot")

  Store.wipe()
  print("  snapshot : round-trip sur / toComp scale+mirroir / serve filtre version+tier / cold-start IA OK")
end)

if ok then
  print("=> SNAPSHOT OK : snapshots async (pilier #3).")
else
  print("=> SNAPSHOT FAIL :")
  print(err)
  os.exit(1)
end
