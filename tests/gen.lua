-- tests/gen.lua
-- Tests du GÉNÉRATEUR PROCÉDURAL de créatures (src/gen/). Tourne sous mock_love (headless) : le
-- générateur sort des GRILLES (strings), aucun baking -> testable sans écran ni love.image réel.
--   Lancement : luajit tests/gen.lua   (depuis la racine du projet)
--
-- 1. Déterminisme : build{id} deux fois -> deep-equal ; deux ids différents -> grilles différentes.
-- 2. Validation structurelle pour TOUTES les unités de Units.order :
--    (a) chaque char ∈ Palette, (b) outline présent sur le périmètre, (c) pivot ∈ bbox,
--    (d) partName reconnu, (e) weapon (si présente) pivot.y proche de 0.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Units = require("src.data.units")
local Rig = require("src.core.rig")
local CreatureGen = require("src.gen.creaturegen")

local PART_NAMES = { head = true, torso = true, armBack = true, armFront = true, weapon = true, legs = true, tail = true }

-- Noms de parts valides : le set bipède + les parts des body-plans non-bipèdes (masse/membres indexés).
local function validPartName(name)
  if PART_NAMES[name] then return true end
  if name == "bulb" or name == "mantle" or name == "body" then return true end
  if name:match("^tentacle%d+$") then return true end -- céphalopode : tentacle1..N
  if name:match("^leg%u%u$") then return true end      -- quadrupède : legFL/FR/BL/BR
  return false
end

local function fail(msg) print("=> GEN FAIL : " .. msg); os.exit(1) end

-- ─────────────────────────── deep-equal d'une def (parts: grid+pivot, rig) ───────────────────────────
local function gridEqual(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function defGridsEqual(d1, d2)
  for name, p1 in pairs(d1.parts) do
    local p2 = d2.parts[name]
    if not p2 then return false end
    if not gridEqual(p1.grid, p2.grid) then return false end
    if p1.pivot.x ~= p2.pivot.x or p1.pivot.y ~= p2.pivot.y then return false end
  end
  for name in pairs(d2.parts) do if not d1.parts[name] then return false end end
  return true
end

-- ─────────────────────────── 1. Déterminisme ───────────────────────────
do
  local a = CreatureGen.build({ id = "spore_tick", type = "arcane", effects = {} })
  local b = CreatureGen.build({ id = "spore_tick", type = "arcane", effects = {} })
  if not defGridsEqual(a, b) then fail("non-déterministe : même id -> grilles différentes") end

  local c = CreatureGen.build({ id = "emberling", type = "abyss", effects = {} })
  if defGridsEqual(a, c) then fail("collision : deux ids différents -> grilles identiques") end

  -- seed explicite identique -> même résultat, quel que soit l'id.
  local s1 = CreatureGen.build({ id = "x", type = "flesh", seed = 12345 })
  local s2 = CreatureGen.build({ id = "y", type = "flesh", seed = 12345 })
  if not defGridsEqual(s1, s2) then fail("seed explicite identique -> grilles différentes") end
  print("  determinisme : OK (meme id/seed -> identique ; ids differents -> distincts)")
end

-- ─────────────────────────── 2. Validation structurelle (toutes les unités) ───────────────────────────
local function validateDef(id, def)
  -- (d) parts nommées reconnues + au moins une part.
  local n = 0
  for name in pairs(def.parts) do
    if not validPartName(name) then fail(id .. " : part inconnue '" .. tostring(name) .. "'") end
    n = n + 1
  end
  if n == 0 then fail(id .. " : aucune part générée") end

  for name, p in pairs(def.parts) do
    local g = p.grid
    local h = #g
    if h == 0 then fail(id .. "/" .. name .. " : grille vide") end
    local w = 0
    for _, row in ipairs(g) do if #row > w then w = #row end end

    -- (a) chaque char ∈ Palette (ou espace = transparent).
    -- (c) pivot ∈ bbox.
    local minX, maxX, minY, maxY = w + 1, 0, h + 1, 0
    local hasPixel = false
    for y = 1, h do
      local row = g[y]
      for x = 1, #row do
        local ch = row:sub(x, x)
        if ch ~= " " then
          if not Palette[ch] then
            fail(id .. "/" .. name .. " : char '" .. ch .. "' hors palette (pixel-trou)")
          end
          hasPixel = true
          if x - 1 < minX then minX = x - 1 end
          if x - 1 > maxX then maxX = x - 1 end
          if y - 1 < minY then minY = y - 1 end
          if y - 1 > maxY then maxY = y - 1 end
        end
      end
    end
    if not hasPixel then fail(id .. "/" .. name .. " : part totalement transparente") end

    local pv = p.pivot
    if pv.x < 0 or pv.x >= w or pv.y < 0 or pv.y >= h then
      fail(id .. "/" .. name .. " : pivot (" .. pv.x .. "," .. pv.y .. ") hors grille " .. w .. "x" .. h)
    end

    -- (b) outline présent : au moins un K ou F dans la grille (le moteur de silhouette en pose toujours).
    local hasOutline = false
    for y = 1, h do
      if g[y]:find("K") or g[y]:find("F") then hasOutline = true; break end
    end
    if not hasOutline then fail(id .. "/" .. name .. " : aucun contour (K/F) sur la silhouette") end

    -- (e) weapon : pivot au manche en haut (py proche de 0).
    if name == "weapon" and pv.y > 1 then
      fail(id .. "/weapon : pivot.y=" .. pv.y .. " (doit etre ~0, manche en haut)")
    end
  end
end

local function validate(id)
  local spec = Units[id] or {}
  local def = CreatureGen.build({ id = id, type = spec.type, effects = spec.effects, bodyplan = spec.bodyplan })
  validateDef(id, def)
end

do
  local count = 0
  for _, id in ipairs(Units.order) do
    validate(id)
    count = count + 1
  end
  print("  validation : OK (" .. count .. " unites : palette + contour + pivot + nommage + weapon)")
end

-- ─────────────────────────── 2a-bis. BODY-PLANS non-bipèdes (blob/quadruped/cephalopod) ───────────────────────────
-- Construits explicitement (axe bodyplan) à travers les familles : structure valide + déterminisme + rendu.
do
  local plans = { "blob", "quadruped", "cephalopod" }
  local fams = { "flesh", "order", "bone", "arcane", "abyss" }
  local count = 0
  for _, bp in ipairs(plans) do
    for _, fam in ipairs(fams) do
      local id = "demo_" .. bp .. "_" .. fam
      local def = CreatureGen.build({ id = id, type = fam, bodyplan = bp, effects = {} })
      validateDef(id, def)
      local def2 = CreatureGen.build({ id = id, type = fam, bodyplan = bp, effects = {} })
      if not defGridsEqual(def, def2) then fail(id .. " : body-plan non-déterministe") end
      local c = Rig.new(def, Palette)
      Rig.update(c, 0, 1); Rig.trigger(c, "attack"); Rig.update(c, 10, 1)
      Rig.trigger(c, "hurt"); Rig.update(c, 20, 1); Rig.draw(c)
      count = count + 1
    end
  end

  -- RANGS (rareté) : ornement + échelle ne cassent ni structure ni déterminisme (legacy + plans).
  local rankCombos = {
    { id = "rank_human", type = "flesh" }, -- legacy humanoïde (ornement sur la tête)
    { id = "rank_ceph", type = "arcane", bodyplan = "cephalopod" },
    { id = "rank_quad", type = "bone", bodyplan = "quadruped" },
    { id = "rank_blob", type = "abyss", bodyplan = "blob" },
  }
  for _, rc in ipairs(rankCombos) do
    for rank = 1, 5 do
      local id = rc.id .. "_r" .. rank
      local def = CreatureGen.build({ id = id, type = rc.type, bodyplan = rc.bodyplan, rank = rank, effects = {} })
      validateDef(id, def)
      if not (def.scale and def.scale >= 1) then fail(id .. " : scale de rang manquante") end
      local def2 = CreatureGen.build({ id = id, type = rc.type, bodyplan = rc.bodyplan, rank = rank, effects = {} })
      if not defGridsEqual(def, def2) then fail(id .. " : rang non-déterministe") end
      local c = Rig.new(def, Palette); Rig.update(c, 0, 1); Rig.draw(c)
      count = count + 1
    end
  end

  -- CHIMÈRES (légendaires) : fusion "chimera:top:bottom" -> structure valide + déterministe + rendu.
  local chimeras = { "chimera:humanoid:tentacles", "chimera:cephalopod:quadruped", "chimera:humanoid:quadruped" }
  for _, bp in ipairs(chimeras) do
    for _, fam in ipairs({ "arcane", "abyss", "flesh" }) do
      local id = "chim_" .. fam .. "_" .. bp:gsub(":", "_")
      local def = CreatureGen.build({ id = id, type = fam, bodyplan = bp, rank = 5, effects = {} })
      validateDef(id, def)
      local def2 = CreatureGen.build({ id = id, type = fam, bodyplan = bp, rank = 5, effects = {} })
      if not defGridsEqual(def, def2) then fail(id .. " : chimère non-déterministe") end
      local c = Rig.new(def, Palette)
      Rig.update(c, 0, 1); Rig.trigger(c, "attack"); Rig.update(c, 10, 1)
      Rig.trigger(c, "hurt"); Rig.update(c, 20, 1); Rig.draw(c)
      count = count + 1
    end
  end
  print("  body-plans : OK (" .. count .. " combos plan/famille/rang/chimère : structure + determinisme + rendu)")
end

-- ─────────────────────────── 2b. Smoke rendu (le rig consomme la def sans crash) ───────────────────────────
do
  for _, id in ipairs(Units.order) do
    local spec = Units[id] or {}
    local def = CreatureGen.build({ id = id, type = spec.type, effects = spec.effects })
    local c = Rig.new(def, Palette)
    Rig.update(c, 0, 1)
    Rig.trigger(c, "attack"); Rig.update(c, 10, 1)
    Rig.trigger(c, "hurt"); Rig.update(c, 20, 1)
    Rig.draw(c)
    if c.parts.weapon then assert(select("#", Rig.weaponTip(c)) >= 1, "weaponTip nil pour " .. id) end
  end
  print("  smoke rendu : OK (Rig.new/update/attack/hurt/draw sur toutes les defs generees)")
end

-- ─────────────────────────── 2c. DISTINCTION PAR PAIRES (anti-doublons) ───────────────────────────
-- Pour toute paire d'unités générées, head+torso (signature visuelle) doivent différer. Les 6 unités
-- DÉDIÉES (Creatures[id]) ne passent pas par le générateur en jeu, mais on les build quand même ici
-- via CreatureGen.build pour s'assurer qu'AUCUNE collision n'existe dans le pool généré.
do
  -- signature = TOUTES les parts (noms triés -> déterministe), pas seulement head+torso : un blob/
  -- céphalopode n'a ni head ni torso, donc l'ancienne signature les aurait tous fait collisionner.
  local function sig(id)
    local spec = Units[id] or {}
    local def = CreatureGen.build({ id = id, type = spec.type, effects = spec.effects, bodyplan = spec.bodyplan })
    local names = {}
    for n in pairs(def.parts) do names[#names + 1] = n end
    table.sort(names)
    local parts = {}
    for _, n in ipairs(names) do
      parts[#parts + 1] = n .. ":" .. table.concat(def.parts[n].grid, "\n")
    end
    return table.concat(parts, "\n##\n")
  end

  local sigs = {}
  for _, id in ipairs(Units.order) do sigs[id] = sig(id) end

  local collisions = 0
  for i = 1, #Units.order do
    for j = i + 1, #Units.order do
      local a, b = Units.order[i], Units.order[j]
      if sigs[a] == sigs[b] then
        print("  COLLISION : " .. a .. " == " .. b .. " (head+torso identiques)")
        collisions = collisions + 1
      end
    end
  end
  if collisions > 0 then fail(collisions .. " paire(s) d'unites visuellement identiques (head+torso)") end
  print("  distinction : OK (" .. #Units.order .. " unites, 0 doublon head+torso sur "
    .. (#Units.order * (#Units.order - 1) / 2) .. " paires)")
end

-- ─────────────────────────── 3. Aperçu ASCII (head + torso, 4 factions) ───────────────────────────
local function ascii(id)
  local spec = Units[id] or {}
  local def = CreatureGen.build({ id = id, type = spec.type, effects = spec.effects })
  print("  --- " .. id .. " (" .. tostring(spec.type) .. ") ---")
  for _, pname in ipairs({ "head", "torso" }) do
    local p = def.parts[pname]
    if p then
      print("  [" .. pname .. "] pivot=(" .. p.pivot.x .. "," .. p.pivot.y .. ")")
      for _, row in ipairs(p.grid) do print("    " .. row:gsub(" ", ".")) end
    end
  end
end

if os.getenv("GEN_PREVIEW") then
  print("\n== APERCU ASCII : 3 FLESH (doivent etre distincts) ==")
  ascii("razorkin")
  ascii("pyre_tender")
  ascii("hookjaw")
  print("\n== APERCU ASCII : 3 ARCANE (doivent etre distincts) ==")
  ascii("spore_tick")
  ascii("stormcaller")
  ascii("bile_spitter")
  print("\n== APERCU ASCII : varietes croisees ==")
  ascii("emberling")      -- abyss
  ascii("rot_hound")      -- bone
  ascii("plague_doctor")  -- order
end

print("=> GEN OK.")
