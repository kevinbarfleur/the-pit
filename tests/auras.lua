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
      bellows_priest = { op = "aura_stat", target = "team",       stat = "haste",     value = 0.08 },
      demon          = { op = "aura_stat", target = "team",       stat = "lifesteal", value = 0.05 },
      deep_kraken    = { op = "aura_stat", target = "level:1",    stat = "statInc",   value = 0.40 },
      galvanizer     = { op = "aura_stat", target = "tier:1",     stat = "statInc",   value = 0.50 },
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

  print("  auras : ampli increased sur voisin (lu a la pose) / grant d'effet / isolé = base (golden-safe) OK")
  print("  auras K1: role front/back/center sur carré (unique+stable) / team / tier:N (spec §6.2.1) OK")
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
