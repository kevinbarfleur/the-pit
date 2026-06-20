-- tests/headless.lua
-- Smoke test SANS écran : mocke l'API LÖVE et exécute la vraie logique du jeu (palette,
-- créatures, rigs, plateau-graphe, phase build, combat, passifs) pour attraper les erreurs
-- runtime qu'un simple check de syntaxe ne voit pas.
--   Lancement : luajit tests/headless.lua   (depuis la racine du projet)
package.path = "./?.lua;" .. package.path

-- ───────────────────────── Mock LÖVE partagé ─────────────────────────
love = require("tests.mock_love")

-- ───────────────────────── Exécution ─────────────────────────
local ok, err = pcall(function()
  local Palette = require("src.core.palette")
  assert(Palette.K, "palette K manquante")
  assert(Palette["K"][1] >= 0, "couleur invalide")

  local Creatures = require("src.data.creatures")
  local Rig = require("src.core.rig")
  local Units = require("src.data.units")
  local view = { scale = 4, ox = 0, oy = 0 }

  -- Build de chaque créature + un tick de chaque état.
  for id, def in pairs(Creatures) do
    local c = Rig.new(def, Palette)
    assert(c.parts, "parts manquantes pour " .. id)
    Rig.update(c, 0, 1)
    Rig.trigger(c, "attack"); Rig.update(c, 10, 1)
    Rig.trigger(c, "hurt"); Rig.update(c, 20, 1)
    Rig.draw(c)
    if c.parts.weapon then assert(select("#", Rig.weaponTip(c)) >= 1, "weaponTip nil pour " .. id) end
  end

  -- Données d'unités : intégrité (stats + passif + visuel correspondant).
  for _, id in ipairs(Units.order) do
    local u = Units[id]
    assert(u and u.hp and u.dmg and u.cd and u.cost and u.effects, "unit incomplète: " .. id)
    assert(Creatures[Units.spriteOf(id)], "visuel manquant pour unit " .. id)
  end

  -- Plateau-graphe : adjacence symétrique, 9 cases, hiérarchie du carré.
  local Board = require("src.board.board")
  local Shapes = require("src.board.shapes")
  local bd = Board.new("carre")
  assert(#bd:neighbors(5) == 4 and #bd:neighbors(1) == 2, "carre: centre=4 / coin=2")
  for _, name in ipairs(Shapes.order) do
    bd:setShape(name)
    assert(#bd.shape.cells == 9, name .. ": 9 cases")
    for i = 1, 9 do
      for _, j in ipairs(bd:neighbors(i)) do
        local back = false
        for _, k in ipairs(bd:neighbors(j)) do if k == i then back = true end end
        assert(back, name .. ": adjacence non symétrique")
      end
    end
  end

  -- Phase BUILD : placement + assemblage de compo + bouclier d'AURA (dépend de l'adjacence).
  local Build = require("src.scenes.build")
  local build = Build.new(Palette, 320, 180, { goto = function() end })
  build.board:setShape("carre"); build:computeLayout(); build.board:unlock(9)
  build:placeId(5, "templar")   -- Rempart au centre -> buffe ses voisins
  build:placeId(4, "marauder")
  build:placeId(6, "skeleton")
  local left = build:buildLeftComp()
  assert(#left == 3, "compo gauche = 3 unités")
  local function findById(comp, id) for _, u in ipairs(comp) do if u.id == id then return u end end end
  assert(findById(left, "marauder").shield >= 14, "Rempart: un voisin du templier doit avoir du bouclier")
  assert(findById(left, "templar").shield == 0, "le templier ne se buffe pas lui-même")
  local enc = build:pickEncounter()
  local right = build:buildRightComp(enc)
  assert(#right >= 1, "compo IA non vide")
  for i = 1, 30 do build:update(1.0); if i % 7 == 0 then build:drawWorld(); build:drawOverlay(view) end end

  -- COMBAT : rejoue la bataille jusqu'à conclusion (un camp éliminé).
  local Arena = require("src.combat.arena")
  local arena = Arena.new({ left = left, right = right, autoReset = false, seed = 7 })
  local ticks = 0
  for i = 1, 4000 do
    arena:update(1.0, i * 1.0) -- SIM pure : plus aucun appel de rendu ici
    ticks = i
    if arena.over then break end
  end
  assert(arena.over, "la bataille devrait se conclure")
  print(string.format("  combat : conclu en %d ticks, resultat = %s", ticks, arena.win and "VICTOIRE" or "DEFAITE"))

  -- DÉTERMINISME : même seed -> bataille strictement identique. C'est la propriété la plus forte ;
  -- elle attrape toute fuite de RNG global ou d'ordre pairs() qui se glisserait dans la sim.
  local function fingerprint(seed)
    local a = Arena.new({ left = left, right = right, autoReset = false, seed = seed })
    local n = 0
    for i = 1, 6000 do a:update(1.0, i * 1.0); n = i; if a.over then break end end
    local parts = { a.win and "W" or "L", tostring(n) }
    for _, u in ipairs(a.units) do parts[#parts + 1] = u.id .. ":" .. tostring(u.hp) end
    return table.concat(parts, ",")
  end
  assert(fingerprint(12345) == fingerprint(12345), "determinisme: meme seed -> combat identique")
  assert(fingerprint(99) == fingerprint(99), "determinisme: stable sur un autre seed")
  print("  determinisme : meme seed -> bataille identique OK")

  -- Tests unitaires déterministes des passifs.
  local function spec(id, x, hp) local u = Units[id]; return { id = id, hp = hp or u.hp, dmg = u.dmg, cd = u.cd, passive = u.passive, shield = 0, x = x, y = 96, facing = 1 } end

  do -- bouclier (absorbe avant les PV) + poison (ignore le bouclier)
    local a = Arena.new({ left = { spec("marauder", 160) }, right = {}, autoReset = false })
    local u = a.units[1]
    u.shield = 10
    local hp0 = u.hp
    a:damage(u, 6);  assert(u.hp == hp0 and u.shield == 4, "bouclier: absorbe avant les PV")
    a:damage(u, 10); assert(u.shield == 0 and u.hp == hp0 - 6, "bouclier: déborde sur les PV")
    u.shield = 50
    local hp1 = u.hp
    table.insert(u.dots.poison, { dps = 4, remaining = 120, acc = 0, source = u }) -- 1 stack
    for i = 1, 60 do a:update(1.0, i) end
    assert(u.hp < hp1 and u.shield == 50, "poison: draine les PV en ignorant le bouclier")
  end

  do -- bonus 1re frappe (marauder) + épines (squelette renvoie des dégâts)
    local a = Arena.new({ left = { spec("marauder", 150) }, right = { spec("skeleton", 170) }, autoReset = false })
    local mar, ske = a.units[1], a.units[2]
    local mhp = mar.hp
    a:hit(mar, ske)
    assert(ske.hp == Units.skeleton.hp - (Units.marauder.dmg + 8), "bonus 1re frappe appliqué")
    assert(mar.hp == mhp - 3, "épines: l'attaquant du squelette subit 3 dégâts")
  end

  do -- vol de vie (démon se soigne d'une fraction des dégâts) — DÉRIVÉ des data (survit aux tunings)
    local a = Arena.new({ left = { spec("demon", 150) }, right = { spec("marauder", 170, 100) }, autoReset = false })
    local dem = a.units[1]; dem.hp = 30
    local frac
    for _, e in ipairs(Units.demon.effects) do if e.op == "lifesteal" then frac = e.params.frac end end
    local before = dem.hp
    a:hit(dem, a.units[2])
    local expected = before + math.floor(Units.demon.dmg * frac + 0.5)
    assert(dem.hp == expected, ("vol de vie: +%d%% des degats infliges"):format(frac * 100))
  end

  -- Familles de STATUTS (le moteur générique arena:tickDots) : poison stacks + weaken, burn décroît +
  -- lèche le bouclier, bleed slow, rot ampute, choc amplifie, regen contre. Tous déterministes.
  do
    local function U2(id, eff) local u = Units[id]
      return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = eff, shield = 0, x = 0, y = 0, facing = 1 } end

    do -- POISON : 2 stacks indépendants + malus de valeur (weaken)
      local a = Arena.new({ left = { U2("witch", { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 180, weaken = 0.1 } } }) },
        right = { U2("marauder") }, autoReset = false })
      local atk, vic = a.units[1], a.units[2]
      a:hit(atk, vic); a:hit(atk, vic)
      assert(#vic.dots.poison == 2, "poison: 2 stacks independants")
      a:update(1.0, 1)
      assert(math.abs(vic.weaken - 0.2) < 1e-9, "poison: weaken = 0.1 x 2 stacks")
    end

    do -- BRÛLURE : décroît (-50%/s) et N'IGNORE PAS le bouclier
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]; u.shield = 100
      u.dots.burn = { dps = 10, remaining = 300, acc = 0, decayEvery = 60, decayAcc = 0, decayPct = 0.5, source = u }
      for i = 1, 60 do a:update(1.0, i) end
      assert(u.shield < 100, "burn: leche le bouclier (n'ignore pas)")
      assert(u.dots.burn.dps == 5, "burn: decroissance 10 -> 5 apres 1s")
    end

    do -- SAIGNEMENT : le slow est retiré à l'expiration
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]
      u.dots.bleed = { dps = 1, remaining = 60, acc = 0, slowPct = 0.25, source = u }; u.atkSlow = 0.25
      for i = 1, 60 do a:update(1.0, i) end
      assert(u.dots.bleed == nil and u.atkSlow == 0, "bleed: slow retire a l'expiration")
    end

    do -- POURRITURE : ampute les PV max
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]; local mh0 = u.maxHp
      u.dots.rot = { dps = 10, remaining = 300, acc = 0, capDps = 10, maxHpFrac = 0.5, source = u }
      for i = 1, 120 do a:update(1.0, i) end
      assert(u.maxHp < mh0, "rot: ampute les PV max")
    end

    do -- CHOC : amplification déterministe des dégâts-pris
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]
      u.dots.shock = { stacks = 5, remaining = 300, perStack = 0.10, cap = 8 }
      a:update(1.0, 1)
      assert(math.abs(u.shockAmp - 0.5) < 1e-9, "choc: shockAmp = 5 x 0.10")
      local hp0 = u.hp
      a:damage(u, 10, {})
      assert(u.hp == hp0 - 15, "choc: +50% degats-pris (10 -> 15)")
    end

    do -- REGEN : contre-DoT, soigne au fil du temps
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]; u.hp = 20; u.regen = 6
      for i = 1, 60 do a:update(1.0, i) end
      assert(u.hp > 20, "regen: soigne au fil du temps")
    end
    print("  statuts : poison-stacks+weaken / burn-decroit / bleed-slow / rot-ampute / choc-amplifie / regen OK")
  end

  -- Ciblage DÉTERMINISTE : les 4 couches (front/back par depth, tie-break haut->bas, aggro, taunt).
  do
    local function U(id, depth, row, aggro, taunt)
      local u = Units[id]
      return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, depth = depth, row = row,
        aggro = aggro, taunt = taunt, shield = 0, x = 0, y = 0, facing = 1 }
    end
    -- Front (depth 0) prioritaire ; aggro egale -> row min (haut->bas). L'arriere (depth 1) jamais cible.
    local a = Arena.new({ left = { U("marauder", 0, 0, 0, false) }, right = {
      U("skeleton", 0, 0, 0, false), U("bandit", 0, 1, 0, false), U("witch", 1, 0, 0, false) },
      autoReset = false })
    local atk = a.units[1]
    assert(a:chooseTarget(atk).id == "skeleton", "front + tie-break haut->bas")
    a.units[2].alive = false; a.units[3].alive = false -- on vide la colonne avant
    assert(a:chooseTarget(atk).id == "witch", "front vide -> on avance d'une colonne (depth+1)")
    -- Aggro : une unite a aggro haute se fait focus avant l'ordre de row.
    local b = Arena.new({ left = { U("marauder", 0, 0, 0, false) }, right = {
      U("skeleton", 0, 0, 0, false), U("bandit", 0, 1, 5, false) }, autoReset = false })
    assert(b:chooseTarget(b.units[1]).id == "bandit", "aggro la plus haute prime sur l'ordre de row")
    -- Taunt : override DUR, force la cible malgre une aggro plus haute ailleurs.
    local c = Arena.new({ left = { U("marauder", 0, 0, 0, false) }, right = {
      U("skeleton", 0, 0, 9, false), U("bandit", 0, 1, 0, true) }, autoReset = false })
    assert(c:chooseTarget(c.units[1]).id == "bandit", "taunt force la cible malgre une aggro adverse plus haute")
    print("  ciblage : front/back deterministe + tie-break + aggro + taunt OK")
  end

  -- Scène combat complète (drawWorld/drawOverlay sans planter).
  local Combat = require("src.scenes.combat")
  local cs = Combat.new(Palette, 320, 180, { goto = function() end }, { left = left, right = right, enemyKey = enc.key })
  for i = 1, 60 do cs:update(1.0); if i % 7 == 0 then cs:drawWorld(); cs:drawOverlay(view) end end
  print("  build+combat : compo, aura bouclier, passifs (bouclier/poison/bonus/epines/vol de vie) OK")

  -- Routing fin-de-combat : combat conclu + clic -> host.finishCombat(win) reçoit l'issue.
  do
    local finished, called = nil, false
    local host = { goto = function() end, finishCombat = function(win) finished = win; called = true end }
    local rc = Combat.new(Palette, 320, 180, host, { left = left, right = right, seed = 7 })
    for _ = 1, 8000 do rc:update(1.0); if rc.arena.over then break end end
    assert(rc.arena.over, "le combat de routing devrait se conclure")
    rc:mousepressed(0, 0, 1)
    assert(called and finished ~= nil, "fin de combat: host.finishCombat appele avec l'issue")
    print("  routing : combat conclu -> host.finishCombat(win) OK")
  end

  -- E2E (entrées SOURIS SYNTHÉTIQUES) en MODE RUN : on rejoue le vrai flux BOUTIQUE (achat = drag
  -- offre->case), slot verrouillé, reroll, niveau, vente, puis COMBAT. Teste hit-testing/drag ET éco.
  do
    local RunState = require("src.run.state")
    local gotoName
    local run = RunState.new(13)
    local host = { goto = function(name) gotoName = name end, run = run,
      finishCombat = function() end }
    local eb = Build.new(Palette, 320, 180, host)
    local function buyToSlot(offerIdx, slot)
      local rc = eb.shopSlots[offerIdx]
      eb:mousepressed(rc.x + rc.w / 2, rc.y + rc.h / 2, 1) -- prend l'offre
      eb:mousemoved(eb.pos[slot].x, eb.pos[slot].y)        -- glisse sur la case
      eb:mousereleased(eb.pos[slot].x, eb.pos[slot].y, 1)  -- lâche -> achat + pose
    end
    -- run démarre à 3 slots débloqués (1,2,3). Achats sur cases 1 et 2.
    local g0 = run.gold
    buyToSlot(1, 1); buyToSlot(2, 2)
    assert(eb:placedCount() == 2, "e2e boutique: 2 unites achetees+posees")
    assert(run.gold < g0, "e2e boutique: or debite par les achats")
    -- Rendu MODE RUN (boutique/HUD/prix/boutons/infobulle) : ne doit pas planter sous la mock.
    eb.mx, eb.my = eb.shopSlots[3].x + 2, eb.shopSlots[3].y + 2 -- survol d'une offre
    eb:update(1.0); eb:drawWorld(); eb:drawOverlay(view)
    eb.mx, eb.my = eb.pos[2].x, eb.pos[2].y                     -- survol d'une case occupee
    eb:drawWorld(); eb:drawOverlay(view)
    -- Slot VERROUILLÉ (9 au niveau 1) : achat refusé même avec de l'or.
    run.gold = 50
    local g1 = run.gold
    buyToSlot(3, 9)
    assert(run.gold == g1 and not eb.slotRigs[9], "e2e boutique: pas d'achat sur slot verrouille")
    -- REROLL : débite l'or.
    eb:mousepressed(eb.rerollBtn.x + 1, eb.rerollBtn.y + 1, 1)
    assert(run.gold == g1 - RunState.REROLL_COST, "e2e reroll: or debite")
    -- NIVEAU : débloque le slot suivant.
    run.gold = 50
    local slots0 = run.slots
    eb:mousepressed(eb.levelBtn.x + 1, eb.levelBtn.y + 1, 1)
    assert(run.slots == slots0 + 1 and eb.board.slots[slots0 + 1].unlocked, "e2e niveau: +1 slot debloque")
    -- VENTE : drag d'une unité posée hors-plateau -> remboursement + retrait.
    local g2 = run.gold
    eb:mousepressed(eb.pos[1].x, eb.pos[1].y, 1) -- ramasse l'unite du slot 1
    eb:mousereleased(2, 2, 1)                    -- lache hors plateau
    assert(run.gold > g2 and eb:placedCount() == 1, "e2e vente: remboursement + unite retiree")
    -- COMBAT -> transition.
    eb:mousepressed(eb.button.x + 1, eb.button.y + 1, 1)
    assert(gotoName == "combat", "e2e: COMBAT -> transition vers la scene combat")
    print("  e2e : boutique (achat/slot-verrou) + reroll + niveau + vente + COMBAT OK")
  end
end)

if ok then
  print("=> HEADLESS OK : aucune erreur runtime.")
else
  print("=> HEADLESS FAIL :")
  print(err)
  os.exit(1)
end
