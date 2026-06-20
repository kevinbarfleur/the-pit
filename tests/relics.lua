-- tests/relics.lua
-- RELIQUES CRYPTIQUES + GRIMOIRE (pilier #2). Vérifie : (1) le 1-PARMI-3 (les 3 candidats contiennent
-- TOUJOURS le vrai + 2 leurres, mélange SEEDÉ -> rejouable : même seed -> même ordre) ; (2) l'effet RÉEL
-- transforme la compo au build ; (3) l'IDENTIFICATION par observation -> renvoyée au host -> Grimoire ;
-- (4) la MÉTA-PROGRESSION (relique déjà connue = identifiée d'emblée). Lancement : luajit tests/relics.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local RunState = require("src.run.state")
local Relics = require("src.data.relics")
local Grimoire = require("src.core.grimoire")

local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local ok, err = pcall(function()
  Grimoire.wipe()

  -- 1) 1-PARMI-3 : candidats = vrai + 2 leurres, mélangés SEEDÉ (déterministe / rejouable).
  local a = RunState.new(123)
  assert(a:grantRelic("bloodstone"), "octroi de bloodstone")
  local r = a.relics[1]
  assert(#r.candidates == 3, "3 candidats")
  assert(has(r.candidates, Relics.bloodstone.realKey), "le VRAI effet est parmi les candidats")
  assert(has(r.candidates, Relics.bloodstone.decoys[1]) and has(r.candidates, Relics.bloodstone.decoys[2]),
    "les 2 leurres sont parmi les candidats")
  assert(not r.identified, "cryptique au depart (non identifiee)")
  local a2 = RunState.new(123); a2:grantRelic("bloodstone")
  for i = 1, 3 do
    assert(a.relics[1].candidates[i] == a2.relics[1].candidates[i], "melange SEEDE deterministe (rejouable)")
  end

  -- 2) EFFET RÉEL : bloodstone = +20% dmg, transforme la compo au build (10->12, 13->16).
  local comp = { { id = "bandit", hp = 46, dmg = 10, cd = 36 }, { id = "witch", hp = 36, dmg = 13, cd = 72 } }
  a:applyRelics(comp)
  assert(comp[1].dmg == 12 and comp[2].dmg == 16, "bloodstone: +20% dmg")

  -- 3) IDENTIFICATION par observation (seuil 2) -> renvoyée au host -> Grimoire.
  assert(#a:observeRelics() == 0, "1re observation : pas encore identifiee")
  local learned = a:observeRelics()
  assert(has(learned, "bloodstone"), "2e observation : identifiee -> renvoyee au host")
  assert(a.relics[1].identified, "marquee identifiee dans le run")
  Grimoire.learn("bloodstone")
  assert(Grimoire.isKnown("bloodstone"), "le Grimoire connait bloodstone")

  -- 4) MÉTA-PROGRESSION : un nouveau run avec une relique DÉJÀ connue démarre IDENTIFIÉE.
  local b = RunState.new(999)
  b:grantRelic("bloodstone", Grimoire.isKnown("bloodstone"))
  assert(b.relics[1].identified, "deja au Grimoire -> identifiee d'emblee (connaissance = meta-progression)")

  -- 5) effet ADD : venom_sigil ajoute un effet thorns (materialise, sans muter la base).
  local c = RunState.new(7); c:grantRelic("venom_sigil")
  local comp2 = { { id = "bandit", hp = 46, dmg = 7, cd = 36 } }
  c:applyRelics(comp2)
  local thorns = false
  for _, e in ipairs(comp2[1].effects or {}) do if e.op == "thorns" then thorns = true end end
  assert(thorns, "venom_sigil: ajoute un effet thorns a la compo")

  Grimoire.wipe()
  print("  reliques : 1-parmi-3 seede / effet reel / identification->Grimoire / meta-progression / add-effect OK")
end)

if ok then
  print("=> RELIQUES OK : cryptiques + Grimoire (pilier #2).")
else
  print("=> RELIQUES FAIL :")
  print(err)
  os.exit(1)
end
