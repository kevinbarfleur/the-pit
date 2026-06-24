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
    -- RE-TIER PAR COMPLEXITÉ (PRD progression-economy, Lot 0) : chaque unité porte un `rank` 1..5
    -- (source de vérité des cotes de boutique) ET `cost = rank`. Test DUR sur tout le roster.
    assert(type(u.rank) == "number" and u.rank == math.floor(u.rank) and u.rank >= 1 and u.rank <= 5,
      "rank manquant/hors 1..5 pour unit " .. id)
    assert(type(u.cost) == "number" and u.cost == u.rank, "cost doit valoir rank (= " .. tostring(u.rank) .. ") pour unit " .. id)
    -- visuel : soit un rig DESSINÉ main (vanille), soit un `type` -> génération procédurale (CreatureGen)
    assert(Creatures[id] or u.type, "visuel: ni rig main ni type (generation) pour unit " .. id)
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
    local mhp, shp = mar.hp, ske.hp -- PV de DÉPART réels (robuste au bouton global Arena.HP_MULT)
    a:hit(mar, ske)
    assert(ske.hp == shp - (Units.marauder.dmg + 8), "bonus 1re frappe appliqué")
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

    do -- CHOC : condensateur -> décharge (stacks × volt) au coup d'un attaquant, puis se consume
      local a = Arena.new({ left = { U2("marauder") }, right = { U2("bandit") }, autoReset = false })
      local target, hitter = a.units[1], a.units[2]
      target.dots.shock = { stacks = 5, remaining = 300, cap = 8, volt = 3, source = hitter }
      local hp0 = target.hp
      a:hit(hitter, target) -- dégâts du coup + décharge 5×3=15, puis consume
      assert(target.dots.shock == nil, "choc: condensateur consume apres decharge")
      assert(hp0 - target.hp >= 15, "choc: la decharge (5x3=15) s'ajoute au coup")
    end

    do -- REGEN : contre-DoT, soigne au fil du temps
      local a = Arena.new({ left = { U2("marauder") }, right = {}, autoReset = false })
      local u = a.units[1]; u.hp = 20; u.regen = 6
      for i = 1, 60 do a:update(1.0, i) end
      assert(u.hp > 20, "regen: soigne au fil du temps")
    end
    print("  statuts : poison-stacks+weaken / burn-decroit / bleed-slow / rot-ampute / choc-decharge / regen OK")
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

  -- Routing fin-de-combat : combat conclu -> écran de fin (drawOverlay pose les rects de boutons) -> clic
  -- sur le bouton CONTINUE appelle host.finishCombat(win). Le clic-n'importe-où a été retiré (boutons only).
  do
    local finished, called = nil, false
    local opened = false
    local host = { goto = function() end, finishCombat = function(win) finished = win; called = true end,
      openChronicle = function() opened = true end }
    local rc = Combat.new(Palette, 320, 180, host, { left = left, right = right, seed = 7 })
    for _ = 1, 8000 do rc:update(1.0); if rc.arena.over then break end end
    assert(rc.arena.over, "le combat de routing devrait se conclure")
    for _ = 1, 30 do rc:update(1.0) end -- laisse overAge dépasser le seuil (20) -> les boutons s'affichent
    rc:drawOverlay(view)                 -- pose self._btnChron / self._btnCont (rects en espace design)
    assert(rc._btnCont and rc._btnChron, "l'ecran de fin doit poser les rects des 2 boutons")
    -- clic HORS des boutons : ne termine RIEN (plus de clic-n'importe-où).
    rc:mousepressed(2, 2, 1)
    assert(not called, "un clic hors bouton ne termine plus le combat")
    -- clic au centre de CHRONICLE -> host.openChronicle ; clic au centre de CONTINUE -> finishCombat.
    -- Les rects sont en DESIGN ; la souris arrive en VIRTUEL (÷4) comme dans le vrai jeu (main.lua:toVirtual)
    -- -> on clique les coords VIRTUELLES du centre de chaque bouton (sinon on testerait le mauvais espace).
    rc:mousepressed((rc._btnChron.x + rc._btnChron.w / 2) / 4, (rc._btnChron.y + rc._btnChron.h / 2) / 4, 1)
    for _ = 1, 12 do rc:update(1.0) end -- ⭐ mûrit l'action différée (Feel) : le press est visible AVANT l'ouverture
    assert(opened, "clic CHRONICLE -> host.openChronicle (apres differe)")
    rc:mousepressed((rc._btnCont.x + rc._btnCont.w / 2) / 4, (rc._btnCont.y + rc._btnCont.h / 2) / 4, 1)
    for _ = 1, 60 do rc:update(1.0) end -- mûrit le CTA « cligne et pars » (~0,8s) avant d'asserter la transition CONTINUE
    assert(called and finished ~= nil, "clic CONTINUE -> host.finishCombat appele avec l'issue (apres differe)")
    print("  routing : ecran de fin (CHRONICLE/CONTINUE) -> openChronicle / finishCombat OK")
  end

  -- CADENCE DU MARCHAND (Lot 4) : un écran de relique tous les 3 COMBATS (victoire OU défaite), pas toutes
  -- les 3 victoires. On rejoue le routage exact de main.lua:host.finishCombat sur un VRAI RunState (le seul
  -- bout non testé du host ; les scènes sont stubbées) -> on observe la transition demandée à chaque combat.
  do
    local RunState = require("src.run.state")
    -- Mini-host = copie fidèle du routage de main.lua : marchand tous les 3 combats (sinon round suivant) +
    -- récompense de level-up MID-ROUND (Lot 5 §5.2) + ordre de refus (Task 0). Les scènes sont stubbées.
    local function makeHost(seed)
      local h = { route = nil, payload = nil, run = RunState.new(seed), midRound = nil }
      function h.goto(name, payload) h.route = name; h.payload = payload end
      function h.finishCombat(win)
        h.run:resolve(win)
        if h.run:isOver() then h.goto("runover"); return end
        local combats = h.run.wins + h.run.losses
        if combats % 3 == 0 then
          local choices = h.run:rollRelicChoices(3)
          if #choices > 0 then h.goto("relicpick", { choices = choices }); return end
        end
        h.run:startRound(); h.goto("build")
      end
      -- Lot 5 : offre de level-up MID-ROUND (pas de startRound -> board/boutique/or préservés). Pool vide -> no-op.
      function h.offerLevelUpRelic()
        local choices = h.run:rollRelicChoices(3)
        if #choices > 0 then h.midRound = true; h.goto("relicpick", { choices = choices, midRound = true }) end
      end
      function h.finishRelicPick(id)
        h.run:grantRelic(id)
        local mid = h.midRound; h.midRound = nil
        if not mid then h.run:startRound() end
        h.goto("build")
      end
      -- Refus : MID-ROUND -> declineRelic sans startRound (le +or persiste) ; POST-COMBAT -> startRound D'ABORD
      -- puis declineRelic (Task 0 : le +or se pose PAR-DESSUS le budget SAP frais, sinon écrasé par le reset).
      function h.finishRelicPickDecline()
        local mid = h.midRound; h.midRound = nil
        if not mid then h.run:startRound() end
        h.run:declineRelic(); h.goto("build")
      end
      return h
    end

    -- (a) DÉFAITES uniquement : le marchand passe quand même au 3e combat (combat 3 = défaite).
    do
      local h = makeHost(13)
      h.finishCombat(false); assert(h.route == "build", "combat 1 (defaite) : pas de relique")
      h.finishCombat(false); assert(h.route == "build", "combat 2 (defaite) : pas de relique")
      h.finishCombat(false); assert(h.route == "relicpick", "combat 3 (defaite) : MARCHAND (cadence par combat, pas par victoire)")
      assert(h.payload and #h.payload.choices == 3, "marchand : offre 1-parmi-3")
    end

    -- (b) MIX victoire/défaite : c'est bien le 3e COMBAT (W,L,W) qui déclenche, pas la 3e victoire.
    do
      local h = makeHost(21)
      h.finishCombat(true);  assert(h.route == "build", "combat 1 (victoire) : pas de relique")
      h.finishCombat(false); assert(h.route == "build", "combat 2 (defaite) : pas de relique")
      h.finishCombat(true);  assert(h.route == "relicpick", "combat 3 (victoire) : MARCHAND au 3e combat (W/L mele)")
    end

    -- (c) REFUS POST-COMBAT (Task 0) : le routage enchaîne round suivant -> build SANS relique. Le +or du
    -- refus doit PERSISTER : startRound re-tire le budget SAP frais PUIS declineRelic pose +DECLINE par-dessus
    -- -> le joueur entre en build avec GOLD_PER_ROUND + streak + DECLINE_RELIC_GOLD (l'ancien ordre l'écrasait).
    do
      local h = makeHost(34)
      h.finishCombat(false); h.finishCombat(false); h.finishCombat(false) -- 3 défaites -> marchand (lossStreak 3)
      assert(h.route == "relicpick", "combat 3 : marchand present")
      local n0, round0 = #h.run.relics, h.run.round
      local streak = 2 -- 3 défaites consécutives -> lossStreak 3 -> bonus de série +2 (cf. streakBonus, cap 3)
      h.finishRelicPickDecline()
      assert(#h.run.relics == n0, "refus : aucune relique acquise")
      assert(h.run.round == round0 + 1 and h.route == "build", "refus : round suivant -> retour build")
      assert(h.run.gold == RunState.GOLD_PER_ROUND + streak + RunState.DECLINE_RELIC_GOLD,
        "refus post-combat (Task 0) : budget SAP frais + streak + DECLINE_RELIC_GOLD (le +or persiste)")
    end
    print("  cadence relique : marchand tous les 3 combats (win/lose) + refus post-combat persiste (Task 0) OK")
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
    -- run démarre à 3 cases OUVERTES = cluster central (placement libre, plus la rangée du haut linéaire).
    local openSlots, lockedSlot = {}, nil
    for i = 1, 9 do
      if eb.board:isOpen(i) then openSlots[#openSlots + 1] = i elseif not lockedSlot then lockedSlot = i end
    end
    assert(#openSlots == RunState.START_SLOTS, "e2e: 3 cases ouvertes au depart (cluster central)")
    local g0 = run.gold
    buyToSlot(1, openSlots[1]); buyToSlot(2, openSlots[2])
    assert(eb:placedCount() == 2, "e2e boutique: 2 unites achetees+posees")
    assert(run.gold < g0, "e2e boutique: or debite par les achats")
    -- Rendu MODE RUN (boutique/HUD/prix/boutons/infobulle) : ne doit pas planter sous la mock.
    eb.mx, eb.my = eb.shopSlots[3].x + 2, eb.shopSlots[3].y + 2     -- survol d'une offre
    eb:update(1.0); eb:drawWorld(); eb:drawOverlay(view)
    eb.mx, eb.my = eb.pos[openSlots[2]].x, eb.pos[openSlots[2]].y   -- survol d'une case occupee
    eb:drawWorld(); eb:drawOverlay(view)
    -- Case VERROUILLÉE : achat refusé même avec de l'or (les slots ne s'achètent plus -> grants timés).
    run.gold = 50
    local g1 = run.gold
    buyToSlot(3, lockedSlot)
    assert(run.gold == g1 and not eb.slotRigs[lockedSlot], "e2e boutique: pas d'achat sur case verrouillee")
    -- REROLL : débite l'or.
    eb:mousepressed(eb.rerollBtn.x + 1, eb.rerollBtn.y + 1, 1)
    assert(run.gold == g1 - RunState.REROLL_COST, "e2e reroll: or debite")
    -- BUY XP (achat d'XP de boutique) : clic au CENTRE du bouton -> or débité de BUY_XP_COST et XP/tier
    -- avancés de BUY_XP_AMOUNT (peut franchir un palier via cascade). On calcule l'état attendu AVANT le clic
    -- (mêmes maths que addShopXp) -> assertion exacte que l'on traverse un niveau ou non.
    run.gold = 99
    local goldR = run.gold
    assert(run.shopTier < run.MAX_TIER and run:canBuyXp(), "e2e buyxp: boutique sous le tier max + achat possible")
    -- Simule la cascade pour l'attendu (tier/XP) sans toucher l'état réel.
    local expT, expXp = run.shopTier, run.shopXp + RunState.BUY_XP_AMOUNT
    while expT < run.MAX_TIER and expXp >= RunState.XP_TO_LEVEL[expT] do
      expXp = expXp - RunState.XP_TO_LEVEL[expT]; expT = expT + 1
    end
    if expT >= run.MAX_TIER then expXp = 0 end
    local rb = eb.raiseBtn
    eb:mousepressed(rb.x + rb.w / 2, rb.y + rb.h / 2, 1)
    assert(run.gold == goldR - RunState.BUY_XP_COST, "e2e buyxp: or debite du cout fixe (BUY_XP_COST)")
    assert(run.shopTier == expT and run.shopXp == expXp, "e2e buyxp: XP/tier avancent de BUY_XP_AMOUNT (cascade incluse)")
    -- GRANT D'EMPLACEMENT (event timé) : round 2 -> une offre attend. ACCEPTER = clic sur une case verrouillée.
    run:startRound()
    assert(run.pendingSlotGrant, "e2e grant: une offre de slot au round 2")
    eb:update(1.0); eb:drawWorld(); eb:drawOverlay(view) -- rendu avec prompt + bouton REFUSER : ne plante pas
    local slots0, placeAt = run.slots
    for i = 1, 9 do if not eb.board:isOpen(i) then placeAt = i; break end end
    eb:mousepressed(eb.pos[placeAt].x, eb.pos[placeAt].y, 1)
    assert(run.slots == slots0 + 1 and eb.board:isOpen(placeAt) and not run.pendingSlotGrant,
      "e2e grant: accepter ouvre la case CHOISIE (+1 slot)")
    -- REFUSER : round 3 -> nouvelle offre -> bouton REFUSER -> +or, capacité inchangée.
    run:startRound()
    assert(run.pendingSlotGrant, "e2e grant: offre au round 3")
    local g3, sl3 = run.gold, run.slots
    eb:mousepressed(eb.declineBtn.x + 1, eb.declineBtn.y + 1, 1)
    assert(run.gold == g3 + RunState.SLOT_DECLINE_GOLD and run.slots == sl3 and not run.pendingSlotGrant,
      "e2e grant: refuser donne de l'or, capacite inchangee")
    -- VENTE : drag d'une unité posée hors-plateau -> remboursement + retrait.
    local g2 = run.gold
    eb:mousepressed(eb.pos[openSlots[1]].x, eb.pos[openSlots[1]].y, 1) -- ramasse une unite posee
    eb:mousereleased(2, 2, 1)                                          -- lache hors plateau
    assert(run.gold > g2 and eb:placedCount() == 1, "e2e vente: remboursement + unite retiree")
    -- COMBAT -> transition.
    eb:mousepressed(eb.button.x + 1, eb.button.y + 1, 1)
    for _ = 1, 60 do eb:update(1.0) end -- ⭐ mûrit l'action différée (Feel) : CTA « cligne et pars » ~0,8s (yeux se referment) avant la transition
    assert(gotoName == "combat", "e2e: COMBAT -> transition vers la scene combat (apres differe)")
    print("  e2e : boutique (achat/case-verrou) + reroll + grant(accept/refuse) + vente + COMBAT OK")
  end

  -- E2E ACHAT AU CLIC + ÉTATS DÉSACTIVÉS (retour user 2026-06) : un CLIC (presse+relâche au même point) sur une
  -- offre l'achète et la place TOUTE SEULE ; la carte est GRISÉE/inerte si pas d'or OU (board+banc pleins ET pas
  -- de trio à compléter) ; plein + trio -> l'achat FUSIONNE direct (level-up auto). On pilote la VRAIE scène.
  do
    local RunState = require("src.run.state")
    local run = RunState.new(4242)
    local host = { goto = function() end, run = run, finishCombat = function() end, offerLevelUpRelic = function() end }
    local eb = Build.new(Palette, 320, 180, host)
    eb.board:unlock(9)
    local function clickOffer(i) -- presse+relâche au MÊME point = clic (pas un drag) -> autoBuy
      local rc = eb.shopSlots[i]
      eb:mousepressed(rc.x + rc.w / 2, rc.y + rc.h / 2, 1)
      eb:mousereleased(rc.x + rc.w / 2, rc.y + rc.h / 2, 1)
    end
    -- (a) or + place -> JOUABLE : le clic achète + place tout seul, l'or est débité.
    run.gold = 99
    run.shop[1] = { id = "marauder", cost = 2, sold = false }
    local pcA, gA = eb:placedCount(), run.gold
    assert(eb:offerPlayable(run.shop[1]), "clic(a): offre jouable (or + place libre)")
    clickOffer(1)
    assert(eb:placedCount() == pcA + 1 and run.gold == gA - 2, "clic(a): achat au clic place tout seul + debite l'or")
    -- (b) PAS D'OR -> non jouable -> clic INERTE (rien acheté, rien posé).
    run.gold = 0
    run.shop[2] = { id = "skeleton", cost = 2, sold = false }
    local pcB = eb:placedCount()
    assert(not eb:offerPlayable(run.shop[2]), "disable(b): pas d'or -> non jouable")
    clickOffer(2)
    assert(run.gold == 0 and eb:placedCount() == pcB, "disable(b): clic sans or n'achete/pose rien")
    -- (c) PLEIN sans trio -> non jouable. On remplit board(9)+banc(4) de skeletons ; l'offre est un id ABSENT.
    run.gold = 99
    for i = 1, 9 do eb:placeId(i, "skeleton") end
    for i = 1, 4 do eb.bench[i] = { id = "skeleton", level = 1, char = eb:newRig("skeleton") } end
    run.shop[3] = { id = "marauder", cost = 2, sold = false }
    assert(not eb:offerPlayable(run.shop[3]), "disable(c): plein + aucun trio (id absent) -> non jouable")
    local gC = run.gold
    clickOffer(3)
    assert(run.gold == gC, "disable(c): clic inerte (plein, l'achat ne creerait rien)")
    -- (d) PLEIN + TRIO -> JOUABLE : on met 2 marauders niveau 1, acheter le 3e complète le trio -> fusion
    -- (la copie achetée est le catalyseur, jamais posée) -> un marauder niveau 2 apparaît, l'or est débité.
    eb.slotRigs[1] = { id = "marauder", level = 1, char = eb:newRig("marauder") }; eb.board.slots[1].unit = "marauder"
    eb.slotRigs[2] = { id = "marauder", level = 1, char = eb:newRig("marauder") }; eb.board.slots[2].unit = "marauder"
    run.shop[3] = { id = "marauder", cost = 2, sold = false }
    assert(eb:offerPlayable(run.shop[3]), "enable(d): plein MAIS trio à compléter -> jouable (level-up à l'achat)")
    local gD = run.gold
    clickOffer(3)
    local hasL2 = false
    for i = 1, 9 do local sr = eb.slotRigs[i]; if sr and sr.id == "marauder" and (sr.level or 1) >= 2 then hasL2 = true end end
    assert(run.gold == gD - 2 and hasL2, "enable(d): l'achat plein+trio fusionne -> marauder niveau 2 + or debite")
    print("  e2e clic : achat+place auto / grise sans or / grise plein-sans-trio / fusion plein+trio OK")
  end

  -- E2E LOT 5 (§5.2) : récompense de relique au LEVEL-UP (fusion 3->niveau), bornée 1/round, MID-ROUND (pas
  -- de startRound -> board/boutique/or préservés). On REJOUE le routage exact de main.lua (host.offerLevelUpRelic
  -- + finishRelicPick* branchés mid-round) sur un VRAI RunState + la VRAIE scène build sous la mock.
  do
    local RunState = require("src.run.state")
    local function shopIds(r) local t = {} for i, o in ipairs(r.shop) do t[i] = o.id end return table.concat(t, ",") end
    -- Host = copie fidèle de main.lua pour le chemin level-up + le branchement mid-round.
    local function makeBuildHost(seed)
      local h = { route = nil, payload = nil, run = RunState.new(seed), midRound = nil }
      function h.goto(name, payload) h.route = name; h.payload = payload end
      function h.finishCombat() end
      function h.offerLevelUpRelic()
        local choices = h.run:rollRelicChoices(3)
        if #choices > 0 then h.midRound = true; h.goto("relicpick", { choices = choices, midRound = true }) end
      end
      function h.finishRelicPick(id)
        h.run:grantRelic(id)
        local mid = h.midRound; h.midRound = nil
        if not mid then h.run:startRound() end
        h.goto("build")
      end
      function h.finishRelicPickDecline()
        local mid = h.midRound; h.midRound = nil
        if not mid then h.run:startRound() end
        h.run:declineRelic(); h.goto("build")
      end
      return h
    end

    local host = makeBuildHost(13)
    local run = host.run
    local eb = Build.new(Palette, 320, 180, host)
    -- Force une boutique 100% marauder (rank 1, cost 1) + de l'or ample : 3 achats posables -> 1 fusion.
    for i = 1, RunState.SHOP_SIZE do run.shop[i] = { id = "marauder", cost = 1, sold = false } end
    run.gold = 99
    local function buyToSlot(offerIdx, slot)
      local rc = eb.shopSlots[offerIdx]
      eb:mousepressed(rc.x + rc.w / 2, rc.y + rc.h / 2, 1)
      eb:mousemoved(eb.pos[slot].x, eb.pos[slot].y)
      eb:mousereleased(eb.pos[slot].x, eb.pos[slot].y, 1)
    end
    local openSlots = {}
    for i = 1, 9 do if eb.board:isOpen(i) then openSlots[#openSlots + 1] = i end end
    assert(#openSlots == RunState.START_SLOTS, "e2e lot5: 3 cases ouvertes au depart")
    assert(run.relicFromLevelThisRound == false and host.route == nil, "e2e lot5: aucune offre avant fusion")

    -- (a) 2 achats -> pas encore de fusion ni d'offre ; le 3e achat fusionne -> ARME l'offre une fois.
    buyToSlot(1, openSlots[1]); buyToSlot(2, openSlots[2])
    assert(eb:placedCount() == 2 and run.relicFromLevelThisRound == false and host.route == nil,
      "e2e lot5: 2 copies posees, pas encore de fusion ni d'offre")
    buyToSlot(3, openSlots[3]) -- 3e marauder -> fusion en niveau 2 -> offre de level-up
    assert(eb:placedCount() == 1, "e2e lot5: 3 copies fusionnent en 1 unite (niveau 2)")
    local merged
    for i = 1, 9 do if eb.slotRigs[i] then merged = eb.slotRigs[i] end end
    assert(merged and merged.level == 2, "e2e lot5: l'unite fusionnee est de niveau 2")
    assert(run.relicFromLevelThisRound == true, "e2e lot5: la fusion arme la recompense (drapeau pose)")
    assert(host.route == "relicpick" and host.payload and host.payload.midRound == true
      and #host.payload.choices == 3, "e2e lot5: la fusion ouvre l'offre 1-parmi-3 MID-ROUND")

    -- (b1) 1/ROUND : une SECONDE fusion le MÊME round ne RE-arme PAS l'offre (drapeau de run garde). On
    -- prépare 3 nouvelles copies (placeId direct), on remet la route a nil, puis checkMerges : fusion OK,
    -- mais AUCUNE nouvelle offre (pendingLevelRelic reste nil ; le caller ne re-route pas).
    do
      eb.board:ensureOpen(9) -- de la place pour 3 copies de plus (capacite test ; n'affecte pas le run)
      local free = {}
      for i = 1, 9 do if eb.board:isOpen(i) and not eb.slotRigs[i] then free[#free + 1] = i end end
      assert(#free >= 3, "e2e lot5: assez de cases libres pour une 2e fusion")
      for k = 1, 3 do eb:placeId(free[k], "skeleton") end
      host.route = nil; host.payload = nil
      local did = eb:checkMerges()
      assert(did == true, "e2e lot5: la 2e fusion a bien eu lieu")
      assert(eb.pendingLevelRelic ~= true, "e2e lot5 (1/round): la 2e fusion N'arme PAS l'offre (drapeau de run)")
      assert(host.route == nil, "e2e lot5 (1/round): aucune 2e offre de relique dans le meme round")
    end

    -- (b2) MID-ROUND finishRelicPick(Decline) : retour build SANS avancer le round (board/boutique préservés ;
    -- pour le refus, le +or PERSISTE dans le round courant car PAS de startRound).
    do
      host.midRound = true -- l'offre (a) etait mid-round ; on rejoue le retour de choix
      local round0 = run.round
      local shop0 = shopIds(run)
      local placed0 = eb:placedCount()
      local g0 = run.gold
      host.finishRelicPickDecline()
      assert(run.round == round0, "e2e lot5: refus mid-round N'avance PAS le round")
      assert(shopIds(run) == shop0, "e2e lot5: refus mid-round preserve la boutique")
      assert(eb:placedCount() == placed0, "e2e lot5: refus mid-round preserve le plateau")
      assert(run.gold == g0 + RunState.DECLINE_RELIC_GOLD,
        "e2e lot5: refus mid-round -> +DECLINE_RELIC_GOLD persiste dans le round (pas de reset SAP)")
      assert(host.route == "build", "e2e lot5: refus mid-round -> retour build")
      -- BIND mid-round : meme round, octroi de la relique (drapeau reste pose : 1/round deja consomme).
      host.midRound = true
      local round1 = run.round
      local ch = run:rollRelicChoices(1)
      if #ch > 0 then
        local n0 = #run.relics
        host.finishRelicPick(ch[1])
        assert(run.round == round1 and #run.relics == n0 + 1 and host.route == "build",
          "e2e lot5: BIND mid-round octroie la relique sans avancer le round")
      end
    end

    -- (c) RESET au round suivant : startRound rearme la recompense -> une fusion next round RE-offre.
    do
      run:startRound()
      assert(run.relicFromLevelThisRound == false, "e2e lot5: startRound rearme la recompense (next round)")
      -- de la place + 3 copies fraiches -> checkMerges arme a nouveau (drapeau libre).
      eb.board:ensureOpen(9)
      local free = {}
      for i = 1, 9 do if eb.board:isOpen(i) and not eb.slotRigs[i] then free[#free + 1] = i end end
      for k = 1, 3 do eb:placeId(free[k], "bandit") end
      eb.pendingLevelRelic = nil
      local did = eb:checkMerges()
      assert(did == true and run.relicFromLevelThisRound == true and eb.pendingLevelRelic == true,
        "e2e lot5: une fusion au round suivant RE-arme l'offre (1/round par round)")
    end
    print("  e2e lot5 : level-up -> relique 1/round, mid-round (pas de startRound), reset par round OK")
  end
end)

if ok then
  print("=> HEADLESS OK : aucune erreur runtime.")
else
  print("=> HEADLESS FAIL :")
  print(err)
  os.exit(1)
end
