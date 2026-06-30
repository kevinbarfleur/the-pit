-- tests/auras.lua
-- AURAS d'adjacence (vague 2) : build-résolues via le GRAPHE du sigil (buildComp + board:neighbors),
-- comme shield_aura. On vérifie que poser une unité-aura À CÔTÉ d'une unité compatible BAKE bien le
-- bonus sur les EFFETS du voisin AVANT tout combat — et qu'une unité ISOLÉE garde ses effets de base
-- (effects = nil -> fallback -> golden inchangé). Déterministe (pur build, aucun RNG).
--   Lancement : luajit tests/auras.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")
local Units = require("src.data.units")

-- Injecte temporairement un effet `aura_stat` sur une unité du roster (le roster n'en porte aucun en
-- phase moteur -> on les fabrique synthétiquement, HORS scénario golden). Renvoie un restaurateur.
local function withAura(id, params)
  local u = Units[id]
  local saved = u.effects
  u.effects = { { trigger = "combat_start", op = "aura_stat", params = params } }
  return function() u.effects = saved end
end
local function compById(comp, id) for _, s in ipairs(comp) do if s.id == id then return s end end end

-- dps de la 1re brûlure trouvée dans les effets MATÉRIALISÉS d'une unité de la compo (nil si base).
local function burnDpsOf(comp, id)
  for _, s in ipairs(comp) do
    if s.id == id and s.effects then
      for _, e in ipairs(s.effects) do if e.op == "burn" then return e.params.dps end end
    end
  end
  return nil
end

local function fresh()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  return b
end

local ok, err = pcall(function()
  -- 1) AURA ACTIVE (framework payoff) : soot_acolyte au centre, emberling sur un VRAI voisin -> burnInc
  -- (increased +0.50) baké sur l'UNITÉ (pas sur ses effets), lu à la POSE via Stats.resolve (cappé ×3).
  local Stats = require("src.effects.stats")
  local b = fresh()
  local center = 5
  local nb = b.board:neighbors(center)[1]
  assert(nb, "le centre a au moins un voisin dans le graphe")
  b:placeId(center, "soot_acolyte")
  b:placeId(nb, "emberling")
  local comp = b:buildComp(-1)
  local inc
  for _, s in ipairs(comp) do if s.id == "emberling" then inc = s.burnInc end end
  assert(inc and math.abs(inc - 0.5) < 1e-6, "aura: emberling recoit burnInc = 0.50 (obtenu " .. tostring(inc) .. ")")
  assert(Stats.resolve(6, { Stats.increased(inc) }, { max = 18, round = "nearest" }) == 9,
    "aura: pose renforcee 6 -> 9 dps (increased +50%, cappee x3)")

  -- 2) GRANT : clot_mender donne un bleed au voisin qui n'en avait pas (marauder = vanille).
  local b2 = fresh()
  local nb2 = b2.board:neighbors(center)[1]
  b2:placeId(center, "clot_mender")
  b2:placeId(nb2, "marauder")
  local comp2 = b2:buildComp(-1)
  local granted = false
  for _, s in ipairs(comp2) do
    if s.id == "marauder" and s.effects then
      for _, e in ipairs(s.effects) do if e.op == "bleed" then granted = true end end
    end
  end
  assert(granted, "aura grant: le voisin du clot_mender gagne un effet bleed")

  -- 3) ISOLÉ : sans aura adjacente, effects = nil (base, golden-safe ; aucune copie matérialisée).
  local b3 = fresh()
  b3:placeId(1, "emberling")
  local comp3 = b3:buildComp(-1)
  local iso
  for _, s in ipairs(comp3) do if s.id == "emberling" then iso = s end end
  assert(iso and iso.effects == nil and iso.burnInc == nil, "isolé: effects = nil ET burnInc = nil (base, golden inchangé)")

  -- ════════ K1 — `aura_stat` générique : résolution de RÔLES sur le CARRÉ (spec §6.2.1) ════════
  -- Plateau carré : slot 5 = centre (4 voisins). Layout cells : x=col, y=row (cf. shapes.carre).
  -- depth = maxC - col. On place 9 unités (1 caster aura_stat + 8 cibles) et on vérifie l'UNICITÉ + la
  -- STABILITÉ du rôle visé, tie-break IDENTIQUE à chooseTarget (row asc, slot asc).

  -- 4) role:front = min(depth) = colonne avant (plus grand x). Cells carré : col 2 = slots 3,6,9 (depth 0).
  -- Tie-break row asc -> slot 3 (row 0). L'aura empower (atkInc) doit atterrir UNIQUEMENT sur le slot 3.
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "role:front", value = 0.20 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
    local comp = b:buildComp(-1)
    local hits = {}
    for _, s in ipairs(comp) do if s.atkInc and s.atkInc > 0 then hits[#hits + 1] = s.slot end end
    assert(#hits == 1, "role:front cible UNE seule unité (obtenu " .. #hits .. ")")
    assert(hits[1] == 3, "role:front carré = slot 3 (col 2, row 0) tie-break row/slot asc (obtenu " .. hits[1] .. ")")
    restore()
  end

  -- 5) role:back = max(depth) = colonne arrière (col 0 -> depth 2) = slots 1,4,7 ; tie-break -> slot 1 (row 0).
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "role:back", value = 0.20 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
    local comp = b:buildComp(-1)
    local hits = {}
    for _, s in ipairs(comp) do if s.atkInc and s.atkInc > 0 then hits[#hits + 1] = s.slot end end
    assert(#hits == 1 and hits[1] == 1, "role:back carré = slot 1 unique (obtenu " ..
      (hits[1] or "rien") .. ", n=" .. #hits .. ")")
    restore()
  end

  -- 6) role:center = nœud à 4 voisins du GRAPHE (slot 5 au carré). +1 multicast doit y atterrir SEUL,
  -- et multicast = ENTIER (non scalé par le niveau).
  do
    local restore = withAura("soot_acolyte", { stat = "multicast", target = "role:center", value = 1 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 1 and "soot_acolyte" or "marauder") end -- caster en coin -> centre = 5
    local comp = b:buildComp(-1)
    local hits = {}
    for _, s in ipairs(comp) do if s.multicast then hits[#hits + 1] = { slot = s.slot, mc = s.multicast } end end
    assert(#hits == 1, "role:center cible UNE unité (obtenu " .. #hits .. ")")
    assert(hits[1].slot == 5 and hits[1].mc == 1, "role:center carré = slot 5, multicast entier 1")
    restore()
  end

  -- 7) DÉTERMINISME / STABILITÉ : deux builds identiques -> même rôle résolu (slot), à l'identique.
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "role:front", value = 0.20 })
    local function frontSlot()
      local b = fresh()
      for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
      for _, s in ipairs(b:buildComp(-1)) do if s.atkInc and s.atkInc > 0 then return s.slot end end
    end
    assert(frontSlot() == frontSlot(), "role:front stable (déterministe) sur deux résolutions")
    restore()
  end

  -- 8) target=team : l'aura touche TOUTES les unités placées (ici regen via K1 -> regenAura).
  do
    local restore = withAura("soot_acolyte", { stat = "regen", target = "team", value = 1 })
    local b = fresh()
    for s = 1, 4 do b:placeId(s, s == 1 and "soot_acolyte" or "marauder") end
    local comp = b:buildComp(-1)
    local n = 0
    for _, s in ipairs(comp) do if s.regenAura and s.regenAura > 0 then n = n + 1 end end
    assert(n == 4, "target=team touche les 4 unités (obtenu " .. n .. ")")
    restore()
  end

  -- 9) target=tier:1 : seules les unités rank-1 reçoivent l'aura (marauder rank 1 ; templar rank 3 exclu).
  do
    local restore = withAura("soot_acolyte", { stat = "dmgReduce", target = "tier:1", value = 0.10 })
    local b = fresh()
    b:placeId(1, "soot_acolyte"); b:placeId(2, "marauder"); b:placeId(5, "templar")
    local comp = b:buildComp(-1)
    local mar, tem = compById(comp, "marauder"), compById(comp, "templar")
    assert(mar.dmgReduce and mar.dmgReduce > 0, "tier:1 touche marauder (rank 1)")
    -- templar (rank 3) : dmgReduce ne doit pas être posé par cette aura (peut rester nil = inerte)
    assert((tem.dmgReduce or 0) == 0, "tier:1 n'atteint PAS templar (rank 3)")
    restore()
  end

  -- ════════ TROU #1 — amplis d'ÉCOLE en aura_stat (rollout § command-auras V4) ════════
  -- poisonInc/burnInc/bleedInc/rotInc sont désormais dans STAT_FIELDS et ROUTÉS vers leurs buffers dédiés
  -- (lus par la pose de DoT, cappés DOT_CAP_MULT=3), PAS dans statBuf. Un commandant « mono-école » (aura_stat
  -- poisonInc team) pose donc bien `poisonInc` sur le board (et JAMAIS un champ générique parasite).

  -- 13) aura_stat poisonInc team 0.18 : chaque unité reçoit poisonInc (additif), et l'ampli est lu à la pose
  -- (resolve cappé ×3). On vérifie team-wide + que ça N'a PAS atterri dans un statBuf (haste/atkInc/… restent nil).
  do
    local restore = withAura("soot_acolyte", { stat = "poisonInc", target = "team", value = 0.18 })
    local b = fresh()
    for s = 1, 4 do b:placeId(s, s == 1 and "soot_acolyte" or "witch") end -- witch porte un poison de base
    local comp = b:buildComp(-1)
    local n = 0
    for _, s in ipairs(comp) do
      if s.poisonInc and math.abs(s.poisonInc - 0.18) < 1e-9 then n = n + 1 end
      -- l'ampli d'école ne doit PAS fuir vers les champs génériques (il a son propre buffer).
      assert((s.atkInc or 0) == 0 and (s.haste or 0) == 0, "TROU#1: poisonInc ne pollue pas statBuf (atkInc/haste nil)")
    end
    assert(n == 4, "TROU#1: aura_stat poisonInc team pose poisonInc sur les 4 unités (obtenu " .. n .. ")")
    -- effet RÉEL : la pose d'un poison de 2 dps sous +0.18 increased -> 2*(1.18)=2.36 -> floor 2 (arrondi nearest = 2).
    assert(Stats.resolve(10, { Stats.increased(0.18) }, { round = "nearest" }) == 12,
      "TROU#1: pose renforcée 10 -> 12 dps (increased +18%)")
    restore()
  end

  -- 14) bleedInc / rotInc en aura_stat role:front : la cible role:front (slot 3 au carré, cf. test #4) reçoit
  -- l'ampli sur SON buffer dédié, unique. Prouve que les deux NOUVEAUX buffers (bleedInc/rotInc) sont câblés.
  do
    local rb = withAura("soot_acolyte", { stat = "bleedInc", target = "role:front", value = 0.20 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "gash_fiend") end -- gash_fiend saigne sans aura propre
    local comp = b:buildComp(-1)
    local hits = {}
    for _, s in ipairs(comp) do if s.bleedInc and s.bleedInc > 0 then hits[#hits + 1] = s.slot end end
    assert(#hits == 1 and hits[1] == 3, "TROU#1: bleedInc role:front = slot 3 unique (n=" .. #hits .. ")")
    rb()
    local rr = withAura("soot_acolyte", { stat = "rotInc", target = "team", value = 0.18 })
    local b2 = fresh()
    for s = 1, 3 do b2:placeId(s, s == 1 and "soot_acolyte" or "rot_hound") end
    local comp2 = b2:buildComp(-1)
    local m = 0
    for _, s in ipairs(comp2) do if s.rotInc and math.abs(s.rotInc - 0.18) < 1e-9 then m = m + 1 end end
    assert(m == 3, "TROU#1: rotInc team pose sur les 3 unités (obtenu " .. m .. ")")
    rr()
  end

  -- 15) ADDITIVITÉ avec l'adjacence : un soot_acolyte (aura burn d'adjacence +0.50 sur le voisin) ET un
  -- aura_stat burnInc team +0.20 sur la MÊME unité -> les deux SOMMENT sur burnInc (0.70). Prouve que le routage
  -- réutilise le buffer existant (cumul aura-adjacence + ampli-école), pas un buffer séparé.
  do
    local restore = withAura("decay_tender", { stat = "burnInc", target = "team", value = 0.20 })
    local b = fresh()
    local center = 5
    local nb = b.board:neighbors(center)[1]
    b:placeId(center, "soot_acolyte") -- aura_burn_dps +0.50 sur ses voisins (adjacence)
    b:placeId(nb, "decay_tender")     -- porte l'aura_stat burnInc team +0.20 (synthétique) ET est voisin du soot
    local comp = b:buildComp(-1)
    local nbInc
    for _, s in ipairs(comp) do if s.slot == nb then nbInc = s.burnInc end end
    -- decay_tender (slot nb) reçoit : +0.50 (adjacence soot) + 0.20 (sa propre aura team, qui se ré-applique au board y compris à elle) = 0.70.
    assert(nbInc and math.abs(nbInc - 0.70) < 1e-9,
      "TROU#1: burnInc adjacence(0.50)+aura_stat team(0.20) SOMMENT sur le buffer (obtenu " .. tostring(nbInc) .. ")")
    restore()
  end

  -- ════════ C0 — COMMANDANT `statInc` (baké au build, consommé dans hp/dmg ; plan §1.5) ════════
  -- `aura_stat {stat=statInc}` n'est PLUS un champ inerte transmis à l'arène : il est ABSORBÉ dans hp/dmg
  -- au bake du comp (increased additif, cappé STAT_INC_CAP). On vérifie la portée (level:1 / tier:1) +
  -- le cap, et que `statInc` ne fuit plus vers le comp (golden-safe : aucune unité golden n'en porte).

  -- 10) level:1 : seules les unités NIVEAU 1 voient hp/dmg ×(1+value) ; une unité niveau 2 est INCHANGÉE.
  do
    local restore = withAura("soot_acolyte", { stat = "statInc", target = "level:1", value = 0.40 })
    local b = fresh()
    b:placeId(1, "soot_acolyte")     -- caster (niveau 1)
    b:placeId(2, "marauder", 1)      -- cible level 1 -> buffée
    b:placeId(5, "marauder", 2)      -- même id mais NIVEAU 2 -> hors portée
    local comp = b:buildComp(-1)
    local lvl1, lvl2
    for _, s in ipairs(comp) do
      if s.id == "marauder" and s.level == 1 then lvl1 = s end
      if s.id == "marauder" and s.level == 2 then lvl2 = s end
    end
    local u = Units.marauder
    -- LEVEL_MULT (build.lua) : {1.0, 1.8, 3.0}. Niveau 1 = base ; niveau 2 = ×1.8.
    local exp1Hp  = math.floor(u.hp  * 1.0 * 1.40 + 0.5)
    local exp1Dmg = math.floor(u.dmg * 1.0 * 1.40 + 0.5)
    local exp2Hp  = math.floor(u.hp  * 1.8 + 0.5)
    assert(lvl1 and lvl1.hp == exp1Hp and lvl1.dmg == exp1Dmg,
      "level:1 statInc : marauder lvl1 a hp/dmg ×1.40 (hp " .. tostring(lvl1 and lvl1.hp) .. " att " .. exp1Hp .. ")")
    assert(lvl2 and lvl2.hp == exp2Hp, "level:1 statInc : marauder lvl2 INCHANGÉ (hp " .. tostring(lvl2 and lvl2.hp) .. " att " .. exp2Hp .. ")")
    -- `statInc` ne transite plus vers le comp (absorbé) -> nil partout.
    assert(lvl1.statInc == nil and lvl2.statInc == nil, "statInc n'est plus un champ du comp (absorbé dans hp/dmg)")
    restore()
  end

  -- 11) tier:1 (Roi des Rats) : seules les unités rank-1 sont buffées ; un rank 3 (templar) est intact.
  do
    local restore = withAura("soot_acolyte", { stat = "statInc", target = "tier:1", value = 0.50 })
    local b = fresh()
    b:placeId(1, "soot_acolyte")
    b:placeId(2, "marauder")  -- rank 1 -> buffé
    b:placeId(5, "templar")   -- rank 3 -> intact
    local comp = b:buildComp(-1)
    local mar, tem = compById(comp, "marauder"), compById(comp, "templar")
    local um, ut = Units.marauder, Units.templar
    assert(mar.hp == math.floor(um.hp * 1.50 + 0.5) and mar.dmg == math.floor(um.dmg * 1.50 + 0.5),
      "tier:1 statInc : marauder (rank 1) ×1.50")
    assert(tem.hp == math.floor(ut.hp + 0.5), "tier:1 statInc : templar (rank 3) INCHANGÉ")
    restore()
  end

  -- 12) CAP : statInc > STAT_INC_CAP (1.0) est tronqué -> ×2.0 max, pas davantage.
  do
    local restore = withAura("soot_acolyte", { stat = "statInc", target = "level:1", value = 3.0 })
    local b = fresh()
    b:placeId(1, "soot_acolyte")
    b:placeId(2, "marauder")
    local comp = b:buildComp(-1)
    local mar = compById(comp, "marauder")
    local um = Units.marauder
    assert(mar.hp == math.floor(um.hp * 2.0 + 0.5), "statInc cappé à +100% (×2.0), pas ×4.0 (hp " .. mar.hp .. ")")
    restore()
  end

  -- ════════ C2 — SMOKE des 6 commandBonus (data, plan §2.2) ════════
  -- Chaque hôte de commandant porte un descripteur `commandBonus` BIEN FORMÉ (même grammaire qu'`effects`).
  -- On vérifie la forme + le mapping exact (portée → stat → valeur) ; la RÉSOLUTION live est testée en C3.
  do
    local expected = {
      bellows_priest = { op = "aura_stat", target = "role:center", stat = "haste",    value = 0.12 },
      demon          = { op = "aura_stat", target = "team",       stat = "lifesteal", value = 0.05 },
      deep_kraken    = { op = "aura_stat", target = "level:1",    stat = "statInc",   value = 0.15 }, -- tuning 2026-06-25 : 0.40 -> 0.15
      galvanizer     = { op = "aura_stat", target = "tier:1",     stat = "statInc",   value = 0.14 }, -- tuning 2026-06-25 : 0.50 -> 0.14
      maggot_king    = { op = "aura_stat", target = "role:front", stat = "multicast", value = 1 },
      siege_breaker  = { op = "grant_team", stripEnemyShield = 0.5 },
    }
    local n = 0
    for id, ex in pairs(expected) do
      local cb = Units[id].commandBonus
      assert(cb, "commandBonus présent sur " .. id)
      assert(cb.trigger == "combat_start", id .. " : trigger combat_start")
      assert(cb.op == ex.op, id .. " : op " .. ex.op)
      if ex.op == "aura_stat" then
        assert(cb.target == ex.target, id .. " : portée " .. ex.target)
        assert(cb.params.stat == ex.stat, id .. " : stat " .. ex.stat)
        assert(math.abs(cb.params.value - ex.value) < 1e-9, id .. " : valeur " .. ex.value)
      else -- grant_team : Bris-Siège
        assert(math.abs((cb.params.stripEnemyShield or 0) - ex.stripEnemyShield) < 1e-9, id .. " : stripEnemyShield 0.5")
      end
      n = n + 1
    end
    assert(n == 6, "6 commandants définis (obtenu " .. n .. ")")
  end

  -- ════════ W1 — AXE TYPE-IDENTITÉ (plan big-update §AXE 2) : target `type:X` + rainbow ════════
  -- Le moteur était à un `if` près : aura_stat sait cibler tier:/level:, on AJOUTE type:X (les 5 types
  -- flesh/bone/arcane/abyss/order existent comme champ data). + l'op rainbow aura_per_unique_type.

  -- 16) target=type:flesh : SEULES les unités de type "flesh" reçoivent l'aura (déterministe, ipairs).
  -- marauder/bandit = flesh (buffées) ; templar = order, skeleton = bone, witch = arcane (exclues).
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "type:flesh", value = 0.10 })
    local b = fresh()
    b:placeId(1, "soot_acolyte")
    b:placeId(2, "marauder")  -- flesh -> buffée
    b:placeId(3, "bandit")    -- flesh -> buffée
    b:placeId(5, "templar")   -- order -> exclue
    b:placeId(6, "skeleton")  -- bone  -> exclue
    b:placeId(8, "witch")     -- arcane -> exclue
    local comp = b:buildComp(-1)
    local hits, flesh = {}, {}
    for _, s in ipairs(comp) do
      if s.atkInc and s.atkInc > 0 then hits[#hits + 1] = s.id end
      if Units[s.id].type == "flesh" then flesh[s.id] = true end
    end
    table.sort(hits)
    assert(#hits == 2 and hits[1] == "bandit" and hits[2] == "marauder",
      "type:flesh touche EXACTEMENT marauder+bandit (obtenu " .. table.concat(hits, ",") .. ")")
    -- garde-fou : aucune unité non-flesh touchée
    for _, s in ipairs(comp) do
      if not flesh[s.id] then assert((s.atkInc or 0) == 0, "type:flesh n'atteint PAS " .. s.id .. " (" .. Units[s.id].type .. ")") end
    end
    restore()
  end

  -- 17) DÉTERMINISME : deux builds identiques -> même ensemble de cibles type:X, à l'identique.
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "type:flesh", value = 0.10 })
    local function fleshHits()
      local b = fresh()
      b:placeId(1, "soot_acolyte"); b:placeId(2, "marauder"); b:placeId(3, "bandit"); b:placeId(5, "templar")
      local set = {}
      for _, s in ipairs(b:buildComp(-1)) do if s.atkInc and s.atkInc > 0 then set[#set + 1] = s.slot end end
      table.sort(set); return table.concat(set, ",")
    end
    assert(fleshHits() == fleshHits(), "type:X stable (déterministe) sur deux résolutions")
    restore()
  end

  -- 18) type:abyss avec un ampli d'ÉCOLE (poisonInc) : croise l'axe 1. demon = abyss -> reçoit poisonInc dans
  -- son buffer dédié (pas dans statBuf). witch = arcane -> intacte.
  do
    local restore = withAura("soot_acolyte", { stat = "poisonInc", target = "type:abyss", value = 0.15 })
    local b = fresh()
    b:placeId(1, "soot_acolyte"); b:placeId(2, "demon"); b:placeId(5, "witch")
    local comp = b:buildComp(-1)
    local dem, wit = compById(comp, "demon"), compById(comp, "witch")
    assert(dem.poisonInc and math.abs(dem.poisonInc - 0.15) < 1e-9, "type:abyss pose poisonInc 0.15 sur demon (abyss)")
    assert((wit.poisonInc or 0) == 0, "type:abyss n'atteint PAS witch (arcane)")
    restore()
  end

  -- 19) RAINBOW (aura_per_unique_type) : le PORTEUR gagne +dmg/+hp par TYPE DISTINCT du board (SELF-aura).
  -- Board : prism_horror (abyss) + marauder (flesh) + skeleton (bone) + witch (arcane) = 4 types distincts.
  -- dmgPerType=2, hpPerType=4 -> +8 dmg / +16 hp sur le porteur (et UNIQUEMENT lui).
  do
    local function withEffect(id, eff) local u = Units[id]; local s = u.effects; u.effects = eff; return function() u.effects = s end end
    local restore = withEffect("soot_acolyte",
      { { trigger = "combat_start", op = "aura_per_unique_type", params = { dmgPerType = 2, hpPerType = 4 } } })
    local b = fresh()
    b:placeId(1, "soot_acolyte") -- porteur (type abyss)
    b:placeId(2, "marauder")     -- flesh
    b:placeId(3, "skeleton")     -- bone
    b:placeId(5, "witch")        -- arcane
    -- types distincts = {abyss(soot+? ), flesh, bone, arcane}. soot_acolyte=arcane -> {arcane, flesh, bone} = 3.
    -- on calcule le count attendu à partir des types réels (robuste au type du caster).
    local seen, count = {}, 0
    for _, pid in ipairs({ "soot_acolyte", "marauder", "skeleton", "witch" }) do
      local ty = Units[pid].type; if not seen[ty] then seen[ty] = true; count = count + 1 end
    end
    local comp = b:buildComp(-1)
    local u = Units.soot_acolyte
    local carrier
    for _, s in ipairs(comp) do if s.id == "soot_acolyte" then carrier = s end end
    assert(carrier.dmg == u.dmg + 2 * count, "rainbow: porteur +2/type dmg (" .. carrier.dmg .. " att " .. (u.dmg + 2 * count) .. ", count=" .. count .. ")")
    assert(carrier.hp == u.hp + 4 * count, "rainbow: porteur +4/type hp (" .. carrier.hp .. " att " .. (u.hp + 4 * count) .. ")")
    -- garde-fou : les AUTRES unités ne reçoivent rien (self-aura).
    for _, s in ipairs(comp) do
      if s.id ~= "soot_acolyte" then
        assert(s.dmg == Units[s.id].dmg and s.hp == Units[s.id].hp, "rainbow: " .. s.id .. " inchangé (self-aura)")
      end
    end
    restore()
  end

  -- 20) RAINBOW borné + déterministe : un board MONO-type (1 seul type) -> count=1 -> bonus minimal ; et deux
  -- builds identiques donnent le même résultat. Prouve le scaling par count (1 type vs N).
  do
    local function withEffect(id, eff) local u = Units[id]; local s = u.effects; u.effects = eff; return function() u.effects = s end end
    local restore = withEffect("prism_horror",
      { { trigger = "combat_start", op = "aura_per_unique_type", params = { dmgPerType = 2, hpPerType = 4 } } })
    -- mono-abyss : prism_horror(abyss) + demon(abyss) -> 1 type distinct -> +2 dmg / +4 hp.
    local function carrierStats()
      local b = fresh(); b:placeId(1, "prism_horror"); b:placeId(2, "demon")
      for _, s in ipairs(b:buildComp(-1)) do if s.id == "prism_horror" then return s.dmg, s.hp end end
    end
    local d1, h1 = carrierStats()
    local d2, h2 = carrierStats()
    local u = Units.prism_horror
    assert(d1 == u.dmg + 2 and h1 == u.hp + 4, "rainbow mono-type: count=1 -> +2 dmg / +4 hp (d=" .. d1 .. ")")
    assert(d1 == d2 and h1 == h2, "rainbow déterministe (deux builds identiques)")
    restore()
  end

  -- ════════ W3 — AXE MIMÉTISME / AMPLIFICATION (plan big-update §AXE 4) : repeat_ability + amplify_auras ════════
  -- Tous deux BUILD-RÉSOLUS (comme aura_stat) : on les teste via buildComp (la sortie matérialisée), déterministe,
  -- zéro RNG. repeat_ability COPIE les on_hit du voisin dans les effects du mimic (PROFONDEUR 1, viaCopy). amplify_auras
  -- MULTIPLIE les sorties d'aura déjà bakées (caps préservés à la lecture combat).

  local function withEffects(id, eff) local u = Units[id]; local s = u.effects; u.effects = eff; return function() u.effects = s end end
  local function hasOnHitOp(spec, op)
    if not spec.effects then return false end
    for _, e in ipairs(spec.effects) do if e.trigger == "on_hit" and e.op == op then return true end end
    return false
  end
  local function countOnHitOp(spec, op)
    local n = 0
    if spec.effects then for _, e in ipairs(spec.effects) do if e.trigger == "on_hit" and e.op == op then n = n + 1 end end end
    return n
  end

  -- 21) repeat_ability who="ahead" : le mimic copie les on_hit de l'allié DEVANT lui (même row, col+1 vers le
  -- front). Sur le carré : slots 4(col0)/5(col1)/6(col2) sont la ROW 1. Un mimic en slot 4 (arrière) avec witch
  -- (poison on_hit) en slot 5 (devant) -> le mimic gagne un `poison` viaCopy dans ses effects, au niveau du mimic.
  do
    local restore = withEffects("soot_acolyte", { { trigger = "combat_start", op = "repeat_ability", params = { who = "ahead" } } })
    local b = fresh()
    b:placeId(4, "soot_acolyte") -- le MIMIC (arrière, col 0)
    b:placeId(5, "witch")        -- le carry DEVANT (col 1), poison on_hit
    local comp = b:buildComp(-1)
    local mimic = compById(comp, "soot_acolyte")
    assert(mimic and hasOnHitOp(mimic, "poison"), "repeat_ability ahead: le mimic copie le poison on_hit de la witch devant")
    -- la copie porte viaCopy (PROFONDEUR 1 : un 2e mimic ne la recopierait pas).
    local copied
    for _, e in ipairs(mimic.effects) do if e.op == "poison" then copied = e end end
    assert(copied and copied.viaCopy == true, "repeat_ability: la copie porte viaCopy=true (anti repeat-of-repeat)")
    -- la witch (la source) est INCHANGÉE (pas de double-pose sur elle ; effects=nil/base).
    local wit = compById(comp, "witch")
    assert(wit.effects == nil or countOnHitOp(wit, "poison") == 1, "repeat_ability: la source witch garde 1 seul poison (pas de mutation)")
    restore()
  end

  -- 22) repeat_ability ISOLÉ (rien devant) : aucun voisin "ahead" -> aucune copie -> effects = nil (base, golden-safe).
  do
    local restore = withEffects("soot_acolyte", { { trigger = "combat_start", op = "repeat_ability", params = { who = "ahead" } } })
    local b = fresh()
    b:placeId(6, "soot_acolyte") -- col 2 = FRONT : il n'y a personne DEVANT (col 3 n'existe pas) -> rien à copier
    local comp = b:buildComp(-1)
    local mimic = compById(comp, "soot_acolyte")
    assert(mimic.effects == nil, "repeat_ability isolé (rien ahead): effects = nil (base, golden-safe)")
    restore()
  end

  -- 23) repeat_ability who="neighbors" : le mimic copie le PLUS FORT voisin du GRAPHE qui porte un on_hit
  -- (heuristique dmg, tie-break slot asc). Au centre (slot 5), voisins = 2,4,6,8. On place une witch (dmg 13,
  -- poison) en 2 et un spore_tick (dmg 3, poison) en 8 -> le mimic copie la WITCH (dmg le plus haut).
  do
    local restore = withEffects("soot_acolyte", { { trigger = "combat_start", op = "repeat_ability", params = { who = "neighbors" } } })
    local b = fresh()
    b:placeId(5, "soot_acolyte") -- mimic au centre (4 voisins)
    b:placeId(2, "witch")        -- voisin fort (dmg 13)
    b:placeId(8, "spore_tick")   -- voisin faible (dmg 3)
    local comp = b:buildComp(-1)
    local mimic = compById(comp, "soot_acolyte")
    assert(mimic and hasOnHitOp(mimic, "poison"), "repeat_ability neighbors: le mimic copie un on_hit du voisin")
    -- on n'a copié QUE le plus fort (1 source) -> exactement 1 poison copié (witch), pas 2.
    assert(countOnHitOp(mimic, "poison") == 1, "repeat_ability neighbors: copie le SEUL plus fort voisin (1 poison, pas 2)")
    restore()
  end

  -- 24) ANTI repeat-of-repeat (PROFONDEUR 1) : deux mimics côte à côte. Le mimic B copie le carry ; le mimic A
  -- (derrière B) ne doit PAS hériter de la copie de B (on ne copie que les on_hit de la DATA du voisin, jamais un
  -- effet viaCopy ni un combat_start repeat_ability). Donc A reste sans copie (B n'a pas d'on_hit propre à copier).
  do
    local restore = withEffects("soot_acolyte", { { trigger = "combat_start", op = "repeat_ability", params = { who = "ahead" } } })
    local b = fresh()
    b:placeId(4, "soot_acolyte") -- mimic A (col 0, arrière)
    b:placeId(5, "soot_acolyte") -- mimic B (col 1) -> copie le carry en col 2
    b:placeId(6, "witch")        -- le carry (col 2, front), poison on_hit
    local comp = b:buildComp(-1)
    local A, B = nil, nil
    for _, s in ipairs(comp) do if s.slot == 4 then A = s elseif s.slot == 5 then B = s end end
    assert(B and hasOnHitOp(B, "poison"), "anti-repeat: le mimic B (devant le carry) copie bien le poison")
    -- A copie les on_hit de la DATA de B (soot_acolyte = repeat_ability, AUCUN on_hit) -> A ne gagne RIEN.
    assert((A.effects == nil) or (countOnHitOp(A, "poison") == 0),
      "anti-repeat-of-repeat: le mimic A n'hérite PAS de la copie de B (profondeur 1)")
    restore()
  end

  -- 25) amplify_auras (méta-multiplicateur, UNITÉ hollow_crown) : un porteur amplify_auras +0.20 MULTIPLIE les
  -- sorties d'aura déjà bakées sur l'équipe. On pose une aura atkInc team (synthétique sur soot) + le porteur
  -- amplify -> l'atkInc baké passe de v à v×1.20 (valeur BRUTE ; le cap ATK_INC_CAP=1.5 clampe à la LECTURE combat).
  do
    local rAura = withEffects("soot_acolyte", { { trigger = "combat_start", op = "aura_stat", target = "team", params = { stat = "atkInc", value = 0.20 } } })
    local rAmp  = withEffects("rot_grub", { { trigger = "combat_start", op = "amplify_auras", params = { frac = 0.20 } } })
    local b = fresh()
    b:placeId(1, "soot_acolyte") -- pose atkInc team 0.20
    b:placeId(2, "rot_grub")     -- amplify_auras +0.20
    b:placeId(3, "marauder")
    local comp = b:buildComp(-1)
    local mar = compById(comp, "marauder")
    -- atkInc baké = 0.20 (team) ; amplifié ×1.20 -> 0.24. SOUS le cap ATK_INC_CAP=1.5 (clampé seulement à la lecture).
    assert(mar.atkInc and math.abs(mar.atkInc - 0.24) < 1e-9,
      "amplify_auras: atkInc 0.20 ×1.20 = 0.24 (valeur brute, obtenu " .. tostring(mar.atkInc) .. ")")
    rAmp(); rAura()
  end

  -- 26) amplify_auras SANS aura à amplifier = inerte (golden-safe) ; et sans porteur amplify, l'aura reste brute.
  do
    local rAura = withEffects("soot_acolyte", { { trigger = "combat_start", op = "aura_stat", target = "team", params = { stat = "atkInc", value = 0.20 } } })
    local b = fresh()
    b:placeId(1, "soot_acolyte"); b:placeId(2, "marauder")
    local comp = b:buildComp(-1)
    local mar = compById(comp, "marauder")
    assert(mar.atkInc and math.abs(mar.atkInc - 0.20) < 1e-9, "amplify_auras absent: l'aura reste brute (0.20)")
    rAura()
  end

  -- 27) amplify_auras CAP préservé (le point CRITIQUE du plan) : même un empilage d'auras + amplify ne franchit
  -- JAMAIS le cap à la LECTURE combat. On bake un atkInc team ÉNORME (1.4) + amplify 0.50 -> 1.4×1.50 = 2.10 baké,
  -- mais l'arène CLAMPE à ATK_INC_CAP=1.5 quand elle lit (makeUnit/hit). On vérifie la valeur lue via Arena.
  do
    local rAura = withEffects("soot_acolyte", { { trigger = "combat_start", op = "aura_stat", target = "team", params = { stat = "atkInc", value = 1.4 } } })
    local rAmp  = withEffects("rot_grub", { { trigger = "combat_start", op = "amplify_auras", params = { frac = 0.50 } } })
    local b = fresh()
    b:placeId(1, "soot_acolyte"); b:placeId(2, "rot_grub"); b:placeId(3, "marauder")
    local comp = b:buildComp(-1)
    local mar = compById(comp, "marauder")
    assert(mar.atkInc and mar.atkInc > 1.5, "amplify_auras: la valeur BRUTE bakée dépasse le cap (2.10), prouve l'ampli")
    -- LECTURE COMBAT : Arena clampe atkInc à ATK_INC_CAP=1.5 -> le bonus effectif est ×(1+1.5)=2.5, JAMAIS plus.
    -- effects={} (et non l'id marauder dont la DATA porte bonus_first/execute) pour ISOLER l'effet du seul atkInc.
    local Arena = require("src.combat.arena")
    local a = Arena.new({ left = { { id = "marauder", hp = 999, dmg = 10, cd = 60, atkInc = mar.atkInc, effects = {}, depth = 0, row = 0, x = 0, y = 0, facing = 1 } },
      right = { { id = "skeleton", hp = 99999, dmg = 1, cd = 60, effects = {}, depth = 0, row = 0, x = 10, y = 0, facing = -1 } }, autoReset = false, seed = 9 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local dealt = hp0 - tgt.hp
    -- dmg base 10, atkInc clampé 1.5 -> 10×(1+1.5)=25 (mais HIT_DMG_CAP_MULT=7 -> max 70 ; ici 25 < 70). Le cap a MORDU.
    assert(dealt == 25, "amplify_auras CAP: atkInc clampé à 1.5 à la lecture -> 10 ->25, le cap a mordu (obtenu " .. dealt .. ")")
    rAmp(); rAura()
  end

  -- 28) DÉTERMINISME (W3) : deux builds identiques (mimic + amplify) -> sorties identiques.
  do
    local rA = withEffects("soot_acolyte", { { trigger = "combat_start", op = "repeat_ability", params = { who = "ahead" } } })
    local function mimicCopies()
      local b = fresh(); b:placeId(4, "soot_acolyte"); b:placeId(5, "witch")
      local m = compById(b:buildComp(-1), "soot_acolyte")
      return m.effects and countOnHitOp(m, "poison") or 0
    end
    assert(mimicCopies() == mimicCopies() and mimicCopies() == 1, "W3 repeat_ability déterministe (1 copie, stable)")
    rA()
  end

  -- 29) W5 — cibles DIRECTIONNELLES relatives (ahead/behind/above/below). Sur carré, depuis le centre slot 5 :
  -- ahead=6, behind=4, above=2, below=8. Elles ne dépendent PAS des arêtes du graphe, mais des coordonnées.
  do
    local restore = withAura("soot_acolyte", { stat = "atkInc", target = "behind", value = 0.15 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
    local hits = {}
    for _, s in ipairs(b:buildComp(-1)) do if s.atkInc and s.atkInc > 0 then hits[#hits + 1] = s.slot end end
    assert(#hits == 1 and hits[1] == 4, "W5 behind depuis slot 5 -> slot 4 (obtenu " .. tostring(hits[1]) .. ")")
    restore()
  end
  do
    local restore = withAura("soot_acolyte", { stat = "haste", target = "ahead", value = 0.12 })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
    local hits = {}
    for _, s in ipairs(b:buildComp(-1)) do if s.haste and s.haste > 0 then hits[#hits + 1] = s.slot end end
    assert(#hits == 1 and hits[1] == 6, "W5 ahead depuis slot 5 -> slot 6 (obtenu " .. tostring(hits[1]) .. ")")
    restore()
  end
  do
    local restore = withEffects("soot_acolyte", {
      { trigger = "combat_start", op = "aura_stat", target = "above", params = { stat = "dmgReduce", value = 0.12 } },
      { trigger = "combat_start", op = "aura_stat", target = "below", params = { stat = "dmgReduce", value = 0.12 } },
    })
    local b = fresh()
    for s = 1, 9 do b:placeId(s, s == 5 and "soot_acolyte" or "marauder") end
    local got = {}
    for _, s in ipairs(b:buildComp(-1)) do if s.dmgReduce and s.dmgReduce > 0 then got[s.slot] = s.dmgReduce end end
    assert(got[2] and got[8] and not got[4] and not got[6], "W5 above/below depuis slot 5 -> slots 2 et 8 uniquement")
    restore()
  end

  print("  auras W3: repeat_ability (ahead/neighbors, copie on_hit viaCopy, isolé=base, anti repeat-of-repeat profondeur 1) OK")
  print("  auras W3: amplify_auras (multiplie l'aura bakée, inerte sans aura, CAP préservé à la lecture combat, déterministe) OK")
  print("  auras W5: targets directionnels ahead/behind/above/below (relatifs au porteur, golden-safe) OK")

  print("  auras : ampli increased sur voisin (lu a la pose) / grant d'effet / isolé = base (golden-safe) OK")
  print("  auras K1: role front/back/center sur carré (unique+stable) / team / tier:N (spec §6.2.1) OK")
  print("  auras W1: target type:X (mono-type, exact+stable+école croisée) / rainbow self-aura (scale par count, borné) OK")
  print("  auras TROU#1: amplis d'école en aura_stat (poison/burn/bleed/rot team|role, routés+additifs, sans fuite) OK")
  print("  auras C0: commandant statInc baké (level:1 / tier:1 / cap, absorbé dans hp/dmg) OK")
  print("  auras C2: 6 commandBonus bien formés (haste/lifesteal/statInc×2/multicast/stripShield) OK")
end)

if ok then
  print("=> AURAS OK : auras d'adjacence build-resolues via le graphe du sigil.")
else
  print("=> AURAS FAIL :")
  print(err)
  os.exit(1)
end
