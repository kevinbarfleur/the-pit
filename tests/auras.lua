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

  print("  auras : ampli increased sur voisin (lu a la pose) / grant d'effet / isolé = base (golden-safe) OK")
  print("  auras K1: role front/back/center sur carré (unique+stable) / team / tier:N (spec §6.2.1) OK")
end)

if ok then
  print("=> AURAS OK : auras d'adjacence build-resolues via le graphe du sigil.")
else
  print("=> AURAS FAIL :")
  print(err)
  os.exit(1)
end
