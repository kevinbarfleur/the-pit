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

  -- Phase BUILD : placement + assemblage de compo + AURAS d'adjacence (armure ET bouclier, dépendent du graphe).
  local Build = require("src.scenes.build")
  local build = Build.new(Palette, 320, 180, { goto = function() end })
  build.board:setShape("carre"); build:computeLayout(); build.board:unlock(9)
  -- templar (9c) = ARMURE-aura (dmgReduce) ; shieldbearer = porteur de bouclier-aura (couvre l'axe shield_aura).
  build:placeId(5, "templar")       -- Armure-aura au centre -> -dégâts d'attaque à ses voisins (slots 2/4/6/8)
  build:placeId(4, "marauder")      -- voisin de 5 (templar) ET de 7 (shieldbearer) -> reçoit dmgReduce + bouclier
  build:placeId(6, "skeleton")
  build:placeId(7, "shieldbearer")  -- voisin de 4 (marauder) -> bouclier-aura (axe shield_aura conservé)
  local left = build:buildLeftComp()
  assert(#left == 4, "compo gauche = 4 unités")
  local function findById(comp, id) for _, u in ipairs(comp) do if u.id == id then return u end end end
  -- Armure-aura (templar/9c) : un voisin du templier reçoit dmgReduce (-12% dégâts d'attaque), pas de bouclier propre.
  assert((findById(left, "marauder").dmgReduce or 0) > 0, "Armure-aura: un voisin du templier doit avoir du dmgReduce")
  assert(not findById(left, "templar").dmgReduce, "le templier ne se buffe pas lui-même (dmgReduce)")
  -- Bouclier-aura (shieldbearer) : couvre toujours l'axe shield_aura via le graphe (un voisin a du bouclier).
  assert(findById(left, "marauder").shield >= 6, "Bouclier-aura: un voisin du porteur de bouclier doit avoir du shield")
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

  do -- C1 — BRIS-SIÈGE : grant_team {stripEnemyShield} ampute de moitié les boucliers ENNEMIS au spawn.
    -- Le commandant (gauche) pose le drapeau ; l'unité ennemie (droite) doit perdre la moitié de son bouclier.
    local function specShield(id, x, eff, sh)
      local u = Units[id]
      return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = eff, shield = sh or 0, x = x, y = 96, facing = 1 }
    end
    local cmd = specShield("marauder", 0, { { trigger = "combat_start", op = "grant_team", params = { stripEnemyShield = 0.5 } } }, 0)
    local foe = specShield("skeleton", 200, nil, 40)
    local a = Arena.new({ left = { cmd }, right = { foe }, autoReset = false })
    local f = a.units[2]
    assert(f.shield == 20 and f.maxShield == 20, "stripEnemyShield: bouclier ennemi ÷2 (20, obtenu " .. f.shield .. ")")
    -- Côté ami : le commandant n'a pas de bouclier, et son propre camp n'est PAS touché (le flag vise l'ennemi).
    -- Gated : sans flag, les boucliers sont intacts (vérifié par l'invariance golden).
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

  -- ════════ W2 — AXE MORT & ENGEANCE (plan big-update §AXE 3) : summon (1 token, case du parent) + faint-payoff.
  -- Décision user : remplacement 1-pour-1 STRICT. On vérifie : (1) exactement 1 token à la mort, à la POSITION du
  -- parent (depth/row/x/y) ; (2) le token est un combatant valide ; (3) la chaîne est BORNÉE (un token NE
  -- ré-invoque PAS) ; (4) faint-payoff scale DÉTERMINISTE + cappé. ════════
  do
    local Spawn = require("src.data.spawn")
    local function U2(id, eff) local u = Units[id]
      return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = eff, shield = 0, depth = 0, row = 1, x = 130, y = 104, facing = 1 } end

    do -- (1)+(2) SUMMON : 1 token à la case du parent quand il meurt ; token = combatant valide
      local summoner = U2("marauder", { { trigger = "on_death", op = "summon", params = { token = "boneling" } } })
      summoner.depth, summoner.row, summoner.x, summoner.y = 0, 2, 137, 138 -- position non triviale
      local a = Arena.new({ left = { summoner }, right = { U2("witch") }, autoReset = false, seed = 5 })
      local s = a.units[1]
      local n0 = #a.units
      a:damage(s, 9999, { cause = "attack", source = a.units[2] }) -- tue le summoner (source = ennemi)
      assert(not s.alive, "W2: le summoner est mort")
      a:update(1.0, 1) -- broadcast de mort + flushSummons (insertion différée)
      assert(#a.units == n0 + 1, "W2 summon: EXACTEMENT 1 token insere (1-pour-1, pas de multi-spawn)")
      local tok
      for _, u in ipairs(a.units) do if u.isToken then tok = u end end
      assert(tok and tok.id == "boneling", "W2 summon: le token est un boneling (window.SPAWN)")
      assert(tok.team == s.team, "W2 summon: le token nait dans le camp du mort")
      assert(tok.depth == s.depth and tok.row == s.row and tok.x == s.x and tok.y == s.y,
        "W2 summon: le token prend la CASE du parent (depth/row/x/y herites)")
      assert(tok.alive and tok.hp > 0 and tok.maxHp > 0 and tok.dmg > 0 and tok.cd > 0 and tok.dots and tok.dots.poison,
        "W2 summon: le token est un combatant valide (stats mini + dots initialises)")
      assert(tok.hp == math.floor(Spawn.token("boneling").hp * a.hpMult + 0.5), "W2 summon: PV du token = mini-stat x hpMult")
    end

    do -- (3) CHAÎNE BORNÉE : un TOKEN qui meurt ne ré-invoque PAS (terminal, imposance 0) — meme si on lui
      -- colle un summon par erreur (double garde : op queueSummon refuse isToken). Pas d'explosion d'unites.
      local a = Arena.new({ left = { U2("skeleton") }, right = { U2("witch") }, autoReset = false, seed = 5 })
      -- fabrique un token directement et tente de le faire invoquer
      local fakeDeadToken = a:makeToken(a.units[1], "boneling")
      a.units[#a.units + 1] = fakeDeadToken
      fakeDeadToken.effects = { { trigger = "on_death", op = "summon", params = { token = "ratling" } } } -- summon force (jamais en data reelle)
      local n0 = #a.units
      a:queueSummon(fakeDeadToken, "ratling") -- appel direct : doit etre refuse (isToken)
      a:flushSummons()
      assert(#a.units == n0, "W2 borne: queueSummon refuse une engeance (token terminal) -> aucune insertion")
      assert(Spawn.isToken("boneling"), "W2: Spawn.isToken reconnait un token")
      -- les 9 tokens sont SUMMON-ONLY : jamais dans le pool de boutique ni dans l'ordre du roster.
      local inPool = false
      for _, id in ipairs(Units.pool) do if Spawn.isToken(id) then inPool = true end end
      assert(not inPool, "W2: aucun token dans le pool boutique (summon-only)")
    end

    do -- (4) FAINT-PAYOFF : +dmg par allié mort, cappe ; DÉTERMINISTE (valeurs exactes).
      local scav = U2("marauder", { { trigger = "on_ally_death", op = "scavenge_on_ally_death", params = { stat = "dmg", value = 2, cap = 8 } } })
      -- 5 alliés fragiles a sacrifier (1 PV) + le charognard ; un ennemi qui les fauche.
      local allies = { scav }
      for i = 1, 5 do local u = U2("skeleton"); u.hp = 1; u.x = 120 + i; allies[#allies + 1] = u end
      local foe = U2("templar"); foe.dmg = 50; foe.x = 200; foe.facing = -1
      local a = Arena.new({ left = allies, right = { foe }, autoReset = false, seed = 5 })
      local sc = a.units[1]
      local d0 = sc.dmg
      -- tue les alliés un par un (source = ennemi) -> chaque mort declenche on_ally_death sur le charognard.
      local killed = 0
      for _, u in ipairs(a.units) do
        if u.team == "left" and u ~= sc and u.alive then
          a:damage(u, 9999, { cause = "attack", source = foe }); killed = killed + 1
        end
      end
      a:update(1.0, 1) -- broadcast on_ally_death (les 5 morts de la frame)
      -- cap 8 : 5 morts x2 = 10 -> cappe a +8. dmg = base + 8.
      assert(sc.dmg == d0 + 8, "W2 scavenge: +2 dmg/allie-mort, CAPPE a +8 (5 morts -> +10 ecrete)")
      assert(killed == 5, "W2 scavenge: 5 allies fauches dans la frame")
    end
    print("  W2 engeance : summon 1-token-case-parent + token valide + chaine bornee + faint-payoff cappe OK")
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

  -- ════════ C3 — PIÉDESTAL DU COMMANDANT (grant + drag-drop + aura build-résolue + défaite par le board) ════════
  do
    local RunState = require("src.run.state")
    local run = RunState.new(77)
    local host = { goto = function() end, run = run, finishCombat = function() end }
    local eb = Build.new(Palette, 320, 180, host)
    eb.board:unlock(9)

    -- 1) GRANT : le piédestal est verrouillé tant qu'il n'est pas offert+accepté. Avant : drop inerte.
    assert(not eb:commanderUnlocked(), "C3: piédestal verrouillé avant le grant")
    -- avance jusqu'au jalon (COMMANDER_GRANT_ROUND) -> l'offre apparaît.
    while run.round < RunState.COMMANDER_GRANT_ROUND do run:startRound() end
    assert(run.pendingCommanderGrant, "C3: offre de piédestal au jalon")
    eb:update(1.0); eb:drawWorld(); eb:drawOverlay(view) -- rendu de l'offre (prompt piédestal) : ne plante pas
    -- ACCEPTE via un clic sur la zone du piédestal (chemin in-scène, minimal fonctionnel).
    local pr0 = eb.commanderRect
    eb:mousepressed(pr0.x + pr0.w / 2, pr0.y + pr0.h / 2, 1)
    assert(run.commanderUnlocked and not run.pendingCommanderGrant, "C3: clic sur le piédestal ACCEPTE l'offre")
    assert(eb:commanderUnlocked(), "C3: la scène voit le piédestal débloqué")

    -- 2) Place une unité NIVEAU 1 sur le board (cible de l'aura de L'Aïeul = statInc level:1).
    eb:placeId(5, "marauder", 1)
    local hp0 = Units.marauder.hp -- base (level 1) avant aura

    -- 3) Pose un non-chef au piédestal -> REFUS propre (retourne à l'origine, pas de crash). Depuis le rollout
    -- « commandement à tout le roster » (command-auras-rollout-spec §3), PLUS AUCUNE unité réelle n'est sans
    -- `commandBonus` (cf. tests/commanders.lua) -> on injecte un non-chef SYNTHÉTIQUE pour exercer le GATE
    -- `canCommand` (build.lua:238-241, drop au piédestal) sans dépendre du contenu data. L'id se rend via
    -- CreatureGen.cached (newRig fallback) ; on le retire après (ne pollue ni le roster ni les autres tests).
    Units.__noncmd_probe = { id = "__noncmd_probe", type = "bone", family = "mortvivant", rank = 1, hp = 40, dmg = 6, cd = 44, effects = {} } -- volontairement SANS commandBonus
    eb:placeId(1, "__noncmd_probe")
    local pr = eb.commanderRect
    eb:mousepressed(eb.pos[1].x, eb.pos[1].y, 1)               -- ramasse le non-chef (board)
    eb:mousereleased(pr.x + pr.w / 2, pr.y + pr.h / 2, 1)      -- lâche sur le piédestal -> refus
    assert(eb.commanderSlot == nil, "C3: non-chef REFUSÉ au piédestal")
    assert(eb.slotRigs[1] and eb.slotRigs[1].id == "__noncmd_probe", "C3: le non-chef retourne à son origine (board)")
    eb.slotRigs[1] = nil; eb.board.slots[1].unit = nil -- nettoie la case probe (board)
    Units.__noncmd_probe = nil -- retire l'unité synthétique (pas de fuite vers les autres tests)

    -- 4) Pose un CHEF (deep_kraken = L'Aïeul) au piédestal via drag-drop (depuis le banc).
    eb.bench[1] = { id = "deep_kraken", level = 1, char = eb:newRig("deep_kraken") }
    local br = eb.benchSlots[1]
    eb:mousepressed(br.x + br.w / 2, br.y + br.h / 2, 1)       -- ramasse depuis le banc
    eb:mousereleased(pr.x + pr.w / 2, pr.y + pr.h / 2, 1)      -- lâche sur le piédestal
    assert(eb.commanderSlot and eb.commanderSlot.id == "deep_kraken", "C3: le chef est couronné au piédestal")
    assert(eb.bench[1] == nil, "C3: le chef a quitté le banc")

    -- 5) buildComp : l'aura statInc (level:1, +40%) est APPLIQUÉE au marauder (board), et le commandant est dans
    -- le comp avec isCommander, SANS slot board.
    local comp = eb:buildComp(-1)
    local mar, cmd
    for _, u in ipairs(comp) do
      if u.id == "marauder" then mar = u end
      if u.isCommander then cmd = u end
    end
    -- L'aura de L'Aïeul (statInc level:1) est une VALEUR D'ÉQUILIBRAGE (tunée via balancematrix) : on la LIT depuis
    -- la data (pas une constante figée) -> ce test reste vert à chaque re-tuning. cappée STAT_INC_CAP (build.lua) = 1.0.
    local kStatInc = Units.deep_kraken.commandBonus.params.value -- 2026-06-25 : 0.40 -> 0.15 (tuning EARLY/END)
    assert(mar and mar.hp == math.floor(hp0 * (1 + kStatInc) + 0.5),
      "C3: marauder (level 1) reçoit +" .. tostring(kStatInc * 100) .. "% PV de L'Aïeul (hp " .. tostring(mar and mar.hp) .. ")")
    assert(mar.statInc == nil, "C3: statInc absorbé (jamais transmis à l'arène)")
    assert(cmd and cmd.id == "deep_kraken" and cmd.untargetable and cmd.cdMult and cmd.cdMult > 1,
      "C3: le commandant est au comp (isCommander + untargetable + cdMult)")
    assert(cmd.slot == nil, "C3: le commandant n'a pas de slot board (hors graphe)")

    -- 6) COMBAT : le board (marauder seul) est tué, mais le commandant INTOUCHABLE survit -> DÉFAITE côté gauche.
    -- L'ennemi : une unité solide qui tue le marauder. On force une victoire droite par déséquilibre net.
    local right = { { id = "templar", hp = 400, dmg = 30, cd = 30, depth = 0, row = 0, x = 200, y = 96, facing = -1 } }
    local arena = Arena.new({ left = comp, right = right, autoReset = false, seed = 3 })
    local concluded, win = false, nil
    for i = 1, 6000 do
      arena:update(1.0, i)
      if arena.over then concluded = true; win = arena.win; break end
    end
    assert(concluded, "C3: combat conclu (le board meurt + fatigue le garantit)")
    -- arena.win = booléen ("left" = joueur) : false = défaite gauche. Le board (marauder) est mort, donc défaite,
    -- ALORS MÊME QUE le commandant intouchable survit (exclu du décompte de victoire, arena.lua:778).
    assert(win == false, "C3: board mort = DÉFAITE gauche MÊME SI le commandant survit")
    -- le commandant gauche est toujours vivant (intouchable) à la conclusion.
    local liveCmd = false
    for _, u in ipairs(arena.units) do if u.isCommander and u.team == "left" and u.alive then liveCmd = true end end
    assert(liveCmd, "C3: le commandant intouchable a survécu (mais ne gagne rien)")
    print("  e2e C3 : piédestal (grant+drag-drop+refus non-chef) + aura level:1 build-résolue + défaite-par-board OK")
  end

  -- ════════ C3bis — FIX D'INTERACTION : DROP SUR LA CASE PENDANT L'OFFRE = ACCEPTE + PLACE (jamais VENDRE) ════════
  -- RÉGRESSION (retour user) : avant le fix, déposer une unité sur la case du commandant PENDANT l'offre (case
  -- visible mais grant non encore accepté) tombait dans le fallback VENTE -> l'unité était PERDUE et l'or montait.
  -- Le fix : la case est droppable dès qu'elle est AFFICHÉE (commanderCellShown), et un drop d'unité-chef
  -- AUTO-ACCEPTE le grant avant de placer. On prouve : l'unité devient commandant, l'or NE BAISSE PAS (pas de
  -- vente), commanderUnlocked devient vrai. Puis : drop d'une OFFRE de boutique sur la case pending -> achat + accept + place.
  do
    local RunState = require("src.run.state")
    -- (A) DROP D'UNE UNITÉ DU BOARD sur la case pending : accepte + couronne, ZÉRO vente.
    do
      local run = RunState.new(101)
      local host = { goto = function() end, run = run, finishCombat = function() end }
      local eb = Build.new(Palette, 320, 180, host)
      eb.board:unlock(9)
      while run.round < RunState.COMMANDER_GRANT_ROUND do run:startRound() end
      assert(run.pendingCommanderGrant and not run.commanderUnlocked, "C3bis: offre en cours, pas encore acceptée")
      -- la case DOIT déjà être droppable (le coeur du bug) MÊME si commanderUnlocked est encore false.
      assert(eb:commanderCellShown(), "C3bis: la case est affichée/droppable pendant l'offre")
      local pr = eb.commanderRect
      assert(eb:commanderAt(pr.x + pr.w / 2, pr.y + pr.h / 2), "C3bis: commanderAt=true pendant l'offre (pas inerte)")
      -- pose un CHEF (galvanizer porte un commandBonus) sur le board, puis le glisse sur la case pending.
      eb:placeId(1, "galvanizer", 1)
      local goldBefore = run.gold
      eb:mousepressed(eb.pos[1].x, eb.pos[1].y, 1)              -- ramasse le chef (board)
      eb:mousereleased(pr.x + pr.w / 2, pr.y + pr.h / 2, 1)     -- lâche sur la case pending
      -- ASSERTIONS DU FIX : couronné, grant accepté, AUCUNE vente (or strictement inchangé), case board vidée.
      assert(eb.commanderSlot and eb.commanderSlot.id == "galvanizer", "C3bis: le chef est DEVENU commandant (pas vendu)")
      assert(run.commanderUnlocked, "C3bis: déposer une unité a AUTO-ACCEPTÉ le grant")
      assert(not run.pendingCommanderGrant, "C3bis: l'offre est consommée")
      assert(run.gold == goldBefore, "C3bis: l'or est INCHANGÉ (pas de vente accidentelle) : " .. run.gold .. " vs " .. goldBefore)
      assert(eb.slotRigs[1] == nil and eb.board.slots[1].unit == nil, "C3bis: la case board source est libérée")
    end
    -- (B) DROP D'UNE OFFRE DE BOUTIQUE sur la case pending : achat (or débité une fois) + accept + couronne.
    do
      local run = RunState.new(202)
      local host = { goto = function() end, run = run, finishCombat = function() end }
      local eb = Build.new(Palette, 320, 180, host)
      eb.board:unlock(9)
      while run.round < RunState.COMMANDER_GRANT_ROUND do run:startRound() end
      assert(run.pendingCommanderGrant and not run.commanderUnlocked, "C3bis(B): offre en cours")
      -- injecte une offre-chef abordable en slot 1 de boutique.
      run.gold = 99
      run.shop[1] = { id = "deep_kraken", cost = 5, sold = false }
      local pr = eb.commanderRect
      local rc = eb.shopSlots[1]
      local goldBefore = run.gold
      eb:mousepressed(rc.x + rc.w / 2, rc.y + rc.h / 2, 1)      -- prend l'offre (chef)
      eb:mousereleased(pr.x + pr.w / 2, pr.y + pr.h / 2, 1)     -- lâche sur la case pending
      assert(eb.commanderSlot and eb.commanderSlot.id == "deep_kraken", "C3bis(B): l'offre-chef est couronnée")
      assert(run.commanderUnlocked and not run.pendingCommanderGrant, "C3bis(B): grant AUTO-ACCEPTÉ par le drop d'offre")
      assert(run.gold == goldBefore - 5, "C3bis(B): or débité UNE fois (achat), pas vendu : " .. run.gold)
      assert(run.shop[1].sold, "C3bis(B): l'offre est consommée (sold)")
    end
    print("  e2e C3bis : drop sur la case pending = ACCEPTE + PLACE (chef board ET offre boutique), ZÉRO vente OK")
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

  -- E2E W8 : freeze boutique via la pastille de carte (frost_seal). Le RunState garde la regle, mais la scene
  -- doit rendre l'action atteignable sans interferer avec le clic d'achat sur le reste de la carte.
  do
    local RunState = require("src.run.state")
    local run = RunState.new(808)
    local host = { goto = function() end, run = run, finishCombat = function() end }
    local eb = Build.new(Palette, 320, 180, host)
    assert(run:grantRelic("frost_seal"), "freeze UI: frost_seal se grant")
    run.shop[1] = { id = "marauder", cost = 1, sold = false }
    run.shop[2] = { id = "skeleton", cost = 1, sold = false }
    local fr = eb:shopFreezeRect(1)
    eb:mousepressed(fr.x + fr.w / 2, fr.y + fr.h / 2, 1)
    assert(run.shop[1].frozen and run.frozenOffers[1] and run.frozenOffers[1].id == "marauder",
      "freeze UI: clic pastille -> offre gelee")
    local before = run.shop[1].id
    run.gold = 99
    run:reroll()
    assert(run.shop[1].id == before and run.shop[1].frozen, "freeze UI: reroll preserve l'offre gelee")
    eb:mousepressed(fr.x + fr.w / 2, fr.y + fr.h / 2, 1)
    assert(not run.shop[1].frozen and run.frozenOffers[1] == nil, "freeze UI: second clic -> degel")
    print("  e2e W8 : frost_seal -> pastille FRZ + preservation reroll + toggle off OK")
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
