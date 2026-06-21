-- tests/lab.lua
-- BANC D'ESSAI (lab) — garde-fous du socle de simulation :
--   1. INTÉGRITÉ du catalogue de compositions (ids/unités/slots/board-level/refs de scénarios)
--   2. FIDÉLITÉ du pont compbuild (les auras d'adjacence sont bien RÉSOLUES, pas sautées)
--   3. PURETÉ/déterminisme de runMatch (mêmes compos+seed -> verdict identique, compos non mutées)
--   4. SMOKE : chaque scénario featured conclut (verdict booléen) sous le plafond
--   5. MONOTONICITÉ du coût d'investissement (perfect >= variantes amputées ; score borné)
-- Lancement : luajit tests/lab.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")

local ARCH = {}; for _, a in ipairs(Compositions.archetypes) do ARCH[a] = true end
local VARIANTS = { perfect = true, missing_minor = true, missing_clutch = true, wall = true, baseline = true, amp = true }

local ok, err = pcall(function()
  -- 1) INTÉGRITÉ DU CATALOGUE
  local seenId = {}
  for _, c in ipairs(Compositions.list) do
    assert(type(c.id) == "string" and not seenId[c.id], "id unique requis: " .. tostring(c.id))
    seenId[c.id] = true
    assert(ARCH[c.archetype], "archetype inconnu: " .. tostring(c.archetype) .. " (" .. c.id .. ")")
    assert(VARIANTS[c.variant], "variant inconnu: " .. tostring(c.variant) .. " (" .. c.id .. ")")
    assert(Shapes[c.sigil], "sigil inconnu: " .. tostring(c.sigil) .. " (" .. c.id .. ")")
    assert(type(c.boardLevel) == "number" and c.boardLevel >= 3 and c.boardLevel <= 9, "boardLevel 3..9: " .. c.id)
    assert(#c.units >= 1, "compo non vide: " .. c.id)
    assert(c.boardLevel >= #c.units, "boardLevel >= #units: " .. c.id)
    assert(type(c.noteKey) == "string", "noteKey requis: " .. c.id)
    local usedSlot = {}
    for _, u in ipairs(c.units) do
      assert(Units[u.id], "unite inconnue: " .. tostring(u.id) .. " (" .. c.id .. ")")
      assert(type(u.slot) == "number" and u.slot >= 1 and u.slot <= 9, "slot 1..9: " .. c.id)
      assert(u.slot <= c.boardLevel, "slot <= boardLevel (placable): " .. c.id .. " slot " .. u.slot)
      assert(not usedSlot[u.slot], "slot unique dans la compo: " .. c.id .. " slot " .. u.slot)
      usedSlot[u.slot] = true
      local lvl = u.level or 1
      assert(lvl >= 1 and lvl <= 3, "level 1..3: " .. c.id)
    end
  end
  for _, s in ipairs(Compositions.scenarios) do
    assert(Compositions.byId[s.a], "scenario " .. s.id .. " : compo A inconnue " .. tostring(s.a))
    assert(Compositions.byId[s.b], "scenario " .. s.id .. " : compo B inconnue " .. tostring(s.b))
    assert(type(s.seed) == "number", "scenario " .. s.id .. " : seed requis")
  end
  print(string.format("  lab : catalogue OK (%d compos, %d scenarios ; integrite + slots + refs)",
    #Compositions.list, #Compositions.scenarios))

  -- 2) FIDÉLITÉ DU PONT : auras RÉSOLUES. spore_tick@2 est voisin de miasma_acolyte@5 sur diamant
  -- (arête 2-5) -> son poison passe de dps 1 (base) à 2 (aura +1). Un builder naïf ne verrait pas ça.
  local function poisonDpsOf(comp, id)
    for _, s in ipairs(comp) do
      if s.id == id and s.effects then
        for _, e in ipairs(s.effects) do if e.op == "poison" then return e.params.dps end end
      end
    end
    return nil
  end
  local pc = Compositions.byId["poison_diamant_perfect"]
  local resolved = Compbuild.toComp(pc, -1)
  assert(#resolved == #pc.units, "pont: toutes les unites posees (" .. #resolved .. "/" .. #pc.units .. ")")
  local dps = poisonDpsOf(resolved, "spore_tick")
  assert(dps and dps >= 2, "pont: aura miasma resolue -> spore_tick poison dps >= 2 (obtenu " .. tostring(dps) .. ")")
  for _, c in ipairs(Compositions.list) do
    local rc = Compbuild.toComp(c, -1)
    assert(#rc == #c.units, "pont: " .. c.id .. " -> " .. #rc .. "/" .. #c.units .. " unites posees")
  end
  print("  lab : pont fidele OK (auras resolues ; toutes les compos se materialisent)")

  -- 3) PURETÉ/DÉTERMINISME du runner : memes compos+seed -> verdict identique ; compos non mutees.
  local L = Compbuild.toComp(Compositions.byId["bruiser_carre"], -1)
  local R = Compbuild.toComp(Compositions.byId["tank_carre"], 1)
  local r1 = Match.run(L, R, 4242, { assertPure = true })
  local r2 = Match.run(L, R, 4242, { assertPure = true })
  assert(r1.win == r2.win and r1.ticks == r2.ticks and r1.decided == r2.decided,
    "runner deterministe (memes compos+seed)")
  print(string.format("  lab : runner pur/deterministe OK (ticks=%d win=%s decided=%s)",
    r1.ticks, tostring(r1.win), tostring(r1.decided)))

  -- 4) SMOKE : chaque scénario featured conclut (ou jugé) sous le plafond, verdict booléen.
  for _, s in ipairs(Compositions.scenarios) do
    local a = Compbuild.toComp(Compositions.byId[s.a], -1)
    local b = Compbuild.toComp(Compositions.byId[s.b], 1)
    local res = Match.run(a, b, s.seed, {})
    assert(type(res.win) == "boolean", "scenario " .. s.id .. " : verdict booleen")
  end
  print(string.format("  lab : smoke OK (%d scenarios concluent, verdict booleen)", #Compositions.scenarios))

  -- 5) MONOTONICITÉ DU COÛT : perfect >= variantes amputées (le clutch/redondance coûte de l'or) ;
  -- score dans (0,1] ; placementSens dans [0,1]. C'est le socle de l'analyse investissement-aware.
  local function gold(id) return Compcost.of(Compositions.byId[id]).gold end
  assert(gold("poison_diamant_perfect") >= gold("poison_diamant_missing_minor"),
    "cout: perfect >= missing_minor")
  assert(gold("poison_diamant_perfect") > gold("poison_diamant_missing_clutch"),
    "cout: perfect > missing_clutch (festering premium retire)")
  for _, c in ipairs(Compositions.list) do
    local cc = Compcost.of(c)
    assert(cc.score > 0 and cc.score <= 1.0001, "score dans (0,1]: " .. c.id .. " = " .. cc.score)
    assert(cc.placementSens >= 0 and cc.placementSens <= 1, "placementSens dans [0,1]: " .. c.id)
  end
  print("  lab : cout monotone OK (perfect>=minor>clutch en or ; score (0,1] ; placementSens [0,1])")

  -- 6) SMOKE SCÈNE : le Proving Ground se construit, sélectionne, lance un batch SIM (étalé) et se
  -- dessine sans crash sous mock LÖVE (attrape tout appel love.graphics non stubé / clé i18n manquante).
  local Playground = require("src.scenes.playground")
  local Palette = require("src.core.palette")
  local pg = Playground.new(Palette, 320, 180, { goto = function() end })
  local view = { scale = 4, ox = 0, oy = 0 }
  pg:drawBack(view); pg:drawWorld(); pg:drawOverlay(view)
  pg:select(2); pg:mousemoved(10, 40); pg:startSim()
  for _ = 1, 3 do pg:update(1.0) end
  pg:drawOverlay(view)
  assert(pg.sim or pg.result, "scene: la boucle SIM tourne (en cours ou aboutie)")
  print("  lab : scene Proving Ground OK (construit + select + SIM + draw headless)")
end)

if ok then
  print("=> LAB OK : catalogue + pont + runner + smoke + cout.")
else
  print("=> LAB FAIL :")
  print(err)
  os.exit(1)
end
