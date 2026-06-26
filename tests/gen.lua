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
  if name == "core" or name == "orb" then return true end -- swarm : core ; eye : orb (masse base-pivot)
  if name:match("^tentacle%d+$") then return true end  -- céphalopode : tentacle1..N
  if name:match("^segment%d+$") then return true end   -- serpent : segment1..N (chaîne)
  if name:match("^leg%d+$") then return true end       -- arachnide : leg1..N (pattes rayonnantes)
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
  local plans = { "blob", "quadruped", "cephalopod", "swarm", "serpent", "arachnid", "eye" }
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
    { id = "rank_swarm", type = "flesh", bodyplan = "swarm" },   -- ornement sur le core
    { id = "rank_serp", type = "arcane", bodyplan = "serpent" }, -- ornement sur la gueule (racine)
    { id = "rank_arac", type = "abyss", bodyplan = "arachnid" }, -- ornement dorsal
    { id = "rank_eye", type = "bone", bodyplan = "eye" },        -- couronne d'épines autour de l'orbe
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

-- ─────────────────────────── 4. CHEMIN PRIMGEN (cachedLive) : PIN de forme + golden de génération ───────────────────────────
-- Les sections 1-3 testent le LEGACY `CreatureGen.build` (masks/Forge), jamais le chemin EN JEU (primgen via
-- cachedLive). Ici on verrouille le chemin réel : (a) PIN -> chaque unité reçoit sa forme CANONIQUE (Units[id].arch),
-- (b) cross-process via hashId (snapshot-safe), (c) distinction (aucune paire au même sprite généré), (d) smoke des
-- 10 nouvelles formes (4 cocon + 6 ELDER). Le PIN A CHANGÉ les sprites (hash-dérivé -> ancré au nom) -> EXPECTED
-- ci-dessous est un RE-BASELINE INTENTIONNEL (B.2). Le golden SIM (tests/golden.lua) reste, lui, INCHANGÉ (firewall).
do
  local Primgen = require("src.gen.primgen")

  -- (d') Les 10 nouvelles formes : rendent via Primgen.live, grille non vide, A.mass présent (anatomie valide).
  local NEW_FORMS = {
    { fam = "cocon", arch = "broodsac" }, { fam = "cocon", arch = "bilesac" },
    { fam = "cocon", arch = "chrysalis" }, { fam = "cocon", arch = "embersac" },
    { fam = "ombre", arch = "voidtyrant" }, { fam = "larve", arch = "devourer" },
    { fam = "crane", arch = "skulltitan" }, { fam = "automate", arch = "juggernaut" },
    { fam = "spectre", arch = "veiledking" }, { fam = "arachnide", arch = "broodmother" },
  }
  for _, t in ipairs(NEW_FORMS) do
    local ai = Primgen.archIndexOf(t.fam, t.arch)
    if not ai then fail("forme NEW '" .. t.arch .. "' absente de la famille '" .. t.fam .. "'") end
    local d = Primgen.live({ seed = 4242, family = t.fam, archIndex = ai, paletteIndex = 1 })
    if d.arch ~= t.arch then fail("archName '" .. tostring(d.arch) .. "' != '" .. t.arch .. "'") end
    if not (d.A and d.A.mass and d.A.mass[1]) then fail(t.arch .. " : A.mass absent (anatomie invalide)") end
    local n = 0; for _ in pairs(d.grid) do n = n + 1 end
    if n < 100 then fail(t.arch .. " : grille trop vide (" .. n .. " px) — builder cassé ?") end
  end
  print("  primgen NEW : OK (10 formes 4 cocon + 6 ELDER -> live() rend, A.mass present, >=100px)")

  -- (a) Toute unité PINnée (Units[id].arch) résout son index DANS sa famille (sinon retombe en hash = régression).
  local unpinned = 0
  for _, id in ipairs(Units.order) do
    local u = Units[id]
    if u.arch then
      if not Primgen.archIndexOf(u.family, u.arch) then
        fail(id .. " : PIN arch='" .. u.arch .. "' introuvable dans family='" .. tostring(u.family) .. "'")
      end
    else
      unpinned = unpinned + 1
    end
  end
  if unpinned > 0 then fail(unpinned .. " unite(s) sans PIN arch= (verrouillage golden incomplet)") end
  print("  primgen PIN : OK (" .. #Units.order .. " unites pinnees, chaque forme resolue in-family)")

  -- (a-bis) SOUS-ÊTRES (engeance, AXE 3) : les 9 tokens d'engeance (src/data/spawn.lua) rendent leur PROPRE
  -- mini-corps de la famille `sousetres` (plus le placeholder famille-parent). On vérifie que chaque token PIN
  -- bien son arch homonyme DANS sousetres, que CreatureGen.cachedLive (chemin EN JEU) le résout, et que le
  -- mini-corps rend (grille non vide, A.mass présent). Les tokens NE sont PAS dans Units.order -> n'entrent
  -- jamais dans le fold du golden de génération (golden-neutre par construction, cf. EXPECTED_GEN ci-dessous).
  do
    local Spawn = require("src.data.spawn")
    for _, tid in ipairs(Spawn.tokenOrder) do
      local tk = Spawn.token(tid)
      if tk.family ~= "sousetres" then
        fail("token '" .. tid .. "' : family='" .. tostring(tk.family) .. "' (attendu 'sousetres')")
      end
      -- l'arch du token DOIT exister dans la famille sousetres (PIN par nom).
      local ai = Primgen.archIndexOf("sousetres", tk.arch)
      if not ai then fail("token '" .. tid .. "' : arch='" .. tostring(tk.arch) .. "' absent de la famille sousetres") end
      -- chemin EN JEU (cachedLive, via le pont Spawn) -> rend SON archetype, pas un placeholder parent.
      local d = CreatureGen.cachedLive({ id = tid, type = tk.type, family = tk.family, arch = tk.arch, rank = tk.rank or 1 })
      if d.family ~= "sousetres" then fail("token '" .. tid .. "' : cachedLive family='" .. tostring(d.family) .. "'") end
      if d.arch ~= tk.arch then fail("token '" .. tid .. "' : cachedLive arch='" .. tostring(d.arch) .. "' != '" .. tk.arch .. "'") end
      if not (d.A and d.A.mass and d.A.mass[1]) then fail("token '" .. tid .. "' : A.mass absent (mini-corps cassé)") end
      local n = 0; for _ in pairs(d.grid) do n = n + 1 end
      if n < 40 then fail("token '" .. tid .. "' : grille trop vide (" .. n .. " px) — mini-corps cassé ?") end
    end
    -- DISTINCTION inter-tokens : les 9 mini-corps doivent différer (un grubling != un boneling).
    local tsigs = {}
    for _, tid in ipairs(Spawn.tokenOrder) do
      local tk = Spawn.token(tid)
      local d = CreatureGen.cachedLive({ id = tid, type = tk.type, family = tk.family, arch = tk.arch, rank = tk.rank or 1 })
      local keys = {}; for k in pairs(d.grid) do keys[#keys + 1] = k end
      table.sort(keys)
      local buf = { d.arch }
      for _, k in ipairs(keys) do buf[#buf + 1] = k .. ":" .. d.grid[k] end
      tsigs[tid] = table.concat(buf, ",")
    end
    for i = 1, #Spawn.tokenOrder do
      for j = i + 1, #Spawn.tokenOrder do
        local a, b = Spawn.tokenOrder[i], Spawn.tokenOrder[j]
        if tsigs[a] == tsigs[b] then fail("tokens '" .. a .. "' == '" .. b .. "' (mini-corps identiques)") end
      end
    end
    print("  primgen engeance : OK (9 sous-etres rendent leur mini-corps dedie, PIN in-family, 0 doublon)")
  end

  -- Helper : grille primgen LIVE d'une unité (chemin EN JEU), sérialisée déterministe (clés numériques triées).
  local function primSig(id)
    local u = Units[id]
    local d = CreatureGen.cachedLive({ id = id, type = u.type, family = u.family, arch = u.arch, effects = u.effects, rank = u.rank })
    local keys = {}
    for k in pairs(d.grid) do keys[#keys + 1] = k end
    table.sort(keys)
    local buf = { tostring(d.family), tostring(d.arch), "w" .. d.w .. "h" .. d.h, "n" .. #keys }
    for _, k in ipairs(keys) do buf[#buf + 1] = k .. ":" .. d.grid[k] end
    return table.concat(buf, ",")
  end

  -- (c) DISTINCTION : aucune paire d'unités ne partage exactement la même grille générée (lisibilité du roster).
  local sigs, collisions = {}, 0
  for _, id in ipairs(Units.order) do sigs[id] = primSig(id) end
  for i = 1, #Units.order do
    for j = i + 1, #Units.order do
      local a, b = Units.order[i], Units.order[j]
      if sigs[a] == sigs[b] then print("  PRIMGEN COLLISION : " .. a .. " == " .. b); collisions = collisions + 1 end
    end
  end
  if collisions > 0 then fail(collisions .. " paire(s) au sprite GENERE identique (chemin primgen)") end
  print("  primgen distinct : OK (" .. #Units.order .. " unites, 0 sprite genere en double)")

  -- (b) GOLDEN DE GÉNÉRATION : empreinte stable cross-process (hashId = FNV-1a 5.1-safe, IEEE déterministe).
  -- Re-baseline INTENTIONNEL au PIN (B.2 : la forme passe de hash-dérivée à ancrée-au-nom). Si tu changes un
  -- builder/une palette/un PIN VOLONTAIREMENT, regénère et colle la nouvelle valeur ici.
  local EXPECTED_GEN = 3256988032 -- re-baseline W2 (2026-06-25) : +7 unités mort&engeance APPEND-ONLY (brood_mother/
  -- larval_host/spore_sac/rat_warren/pit_shepherd/carrion_choir/bone_harvest). PROUVÉ golden-neutre sur les 89
  -- pré-W2 (le fold des 89 d'origine = 541702824 INCHANGÉ) -> seul l'ajout des 7 nouvelles formes déplace
  -- l'empreinte (les 9 tokens d'engeance ne sont PAS dans Units.order -> n'entrent pas dans le fold). Antérieurs :
  -- 541702824 (W1, +6 type-identité) puis 1150543352 (PIN).
  local function roll(acc, s) return CreatureGen.hashId(string.format("%d|", acc) .. s) end
  local acc = 0
  for _, id in ipairs(Units.order) do acc = roll(acc, id .. "=" .. sigs[id]) end
  if acc ~= EXPECTED_GEN then
    fail("empreinte de generation " .. acc .. " != attendu " .. EXPECTED_GEN
      .. " (regression visuelle OU re-baseline a valider : maj EXPECTED_GEN)")
  end
  print("  primgen golden : OK (empreinte de generation stable = " .. acc .. ")")
end

print("=> GEN OK.")
