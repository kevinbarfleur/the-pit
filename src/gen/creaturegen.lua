-- src/gen/creaturegen.lua
-- GÉNÉRATEUR PROCÉDURAL DE CRÉATURES (Architecture B + hybride A).
-- Couche RENDER (produit de la DATA visuelle ; aucun baking ici : on sort des grilles de strings,
-- Rig.new/Sprite.bake bakent ensuite). SEUL module du dossier qui tire le RNG seedé.
--
-- Déterminisme (pilier snapshot async) : seed STABLE dérivé de l'id (FNV-1a 32 bits) -> même unité =
-- même créature partout, sans table. RNG = love.math.newRandomGenerator(seed). Ordre de tirage FIXE
-- (ipairs sur des listes ordonnées, jamais pairs sur ce qui influe la génération).
--   Réf API (vérifiée love2d.org/wiki, cible 11.5) : love.math.newRandomGenerator(seed) déterministe ;
--   rng:random()->[0,1) ; rng:random(n)->[1,n]. Interface identique dans tests/mock_love.lua.
--
-- Sortie = def consommable telle quelle par Rig.new(def, palette) :
--   { name, parts={<name>={grid={strings}, pivot={x,y}}}, rig={...}, idlePose?, animations? }

local Masks    = require("src.gen.masks")
local Factions = require("src.gen.factions")
local Ramps    = require("src.gen.ramps")
local Details  = require("src.gen.details")
local Rarity   = require("src.gen.rarity")

local CreatureGen = {}

-- ─────────────────────────── Seed stable (FNV-1a 32 bits) ───────────────────────────
-- Arithmétique modulaire pure (pas de lib bit) -> portable Lua 5.1 / LuaJIT, même résultat partout.
local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619
local UINT32     = 4294967296

-- LuaJIT/Lua5.1 n'ont pas l'opérateur `~` portable : on réécrit le XOR par arithmétique sur octets.
local function bxor_byte(a, b)
  local r, bit = 0, 1
  for _ = 1, 8 do
    local abit = a % 2
    local bbit = b % 2
    if abit ~= bbit then r = r + bit end
    a = (a - abit) / 2
    b = (b - bbit) / 2
    bit = bit * 2
  end
  return r
end

local function hashId(str)
  local h = FNV_OFFSET
  for i = 1, #str do
    -- XOR du byte de poids faible de h avec l'octet courant, puis × prime.
    local low = h % 256
    local hi  = h - low
    h = hi + bxor_byte(low, str:byte(i))
    h = (h * FNV_PRIME) % UINT32
  end
  -- seed ∈ [0, 2^53-1] requis par LÖVE : 32 bits suffisent largement et restent dans la plage.
  return h
end
CreatureGen.hashId = hashId

-- ─────────────────────────── Helpers grille ───────────────────────────
-- Une "cell grid" interne = matrice [y][x] de caractères (ou false = transparent), 1-indexée.
local function newCells(w, h)
  local g = {}
  for y = 1, h do
    g[y] = {}
    for x = 1, w do g[y][x] = false end
  end
  return g
end

local function cellsToStrings(g)
  local out = {}
  for y = 1, #g do
    local row = {}
    for x = 1, #g[y] do
      row[x] = g[y][x] or " "
    end
    out[y] = table.concat(row)
  end
  return out
end

-- ─────────────────────────── Remplissage seedé + miroir + corpulence ───────────────────────────
-- half = matrice de rôles (0/1/3/"E"), la colonne de droite touche l'axe. On remplit puis on miroir.
-- corp = corpulence : on duplique la colonne d'axe `corp` fois (élargit le tronc) -> fin vs massif.
-- Renvoie une matrice booléenne "filled" + une liste de marqueurs "E" (positions de détails).
local function fillAndMirror(rng, half, density, corp)
  corp = corp or 0
  local hh = #half
  local hw = #half[1]
  -- élargissement : `corp` colonnes pleines insérées à l'axe (entre les deux moitiés).
  local fullW = hw * 2 + corp
  local filled = newCells(fullW, hh)
  local markers = {}

  for y = 1, hh do
    for x = 1, hw do
      local role = half[y][x]
      local on, isMarker = false, false
      if role == 3 then
        on = true
      elseif role == "E" then
        on = true; isMarker = true
      elseif role == 1 then
        on = rng:random() < density
      end
      if on then
        filled[y][x] = true                       -- moitié gauche
        filled[y][fullW - x + 1] = true           -- miroir -> moitié droite
        if isMarker then markers[#markers + 1] = { x = x, y = y } end
        -- corpulence : si la cellule touche l'axe (x == hw), on remplit les colonnes insérées.
        if x == hw then
          for k = 1, corp do filled[y][hw + k] = true end
        end
      end
    end
  end
  return filled, markers, fullW, hh
end

-- ─────────────────────────── Asymétrie eldritch (post-miroir) ───────────────────────────
-- Casse le miroir : ajoute UNE excroissance COHÉRENTE d'un seul côté (bosse/corne contiguë), pas un
-- peigne. Cappé pour ne jamais détruire la lisibilité (silhouette toujours connexe et lisible).
local function addAsymmetry(rng, filled, fullW, hh, amount)
  if amount <= 0 then return end
  if rng:random() >= amount then return end

  -- choisit UNE colonne d'un côté (en évitant la colonne EXTRÊME -> la bosse pousse depuis le corps,
  -- jamais un pic 1px détaché), trouve son sommet plein, empile 1-2 cellules dessus (corne/bosse).
  local side = rng:random(0, 1) -- 0 gauche, 1 droite
  local half = math.floor(fullW / 2)
  local col = (side == 0) and (2 + rng:random(0, math.max(0, half - 3)))
    or (half + 1 + rng:random(0, math.max(0, half - 3)))

  local top
  for y = 1, hh do
    if filled[y][col] then top = y; break end
  end
  if not top then return end

  local hcount = 1 + rng:random(0, 1) -- corne de 1-2 cellules
  for k = 1, hcount do
    local y = top - k
    if y >= 1 then
      filled[y][col] = true
      -- légère courbure : la 2e cellule peut décaler d'un cran vers l'extérieur (corne courbe).
      if k == 2 and rng:random() < 0.5 then
        local nc = (side == 0) and (col - 1) or (col + 1)
        if nc >= 1 and nc <= fullW then filled[y][nc] = true end
      end
    end
  end
end

-- ─────────────────────────── Nettoyage : pas de pixel orphelin ───────────────────────────
-- Retire toute cellule pleine sans AUCUN voisin 8-connexe plein -> jamais de point de contour
-- flottant (artefact d'asym). Garantit une silhouette connexe et lisible.
local function pruneOrphans(filled, fullW, hh)
  local function on(x, y) return x >= 1 and x <= fullW and y >= 1 and y <= hh and filled[y][x] end
  local kill = {}
  for y = 1, hh do
    for x = 1, fullW do
      if filled[y][x] then
        local nb = 0
        for dy = -1, 1 do
          for dx = -1, 1 do
            if (dx ~= 0 or dy ~= 0) and on(x + dx, y + dy) then nb = nb + 1 end
          end
        end
        if nb == 0 then kill[#kill + 1] = { x, y } end
      end
    end
  end
  for _, c in ipairs(kill) do filled[c[2]][c[1]] = false end
end

-- ─────────────────────────── Outline auto (edge-detection) ───────────────────────────
-- Toute cellule pleine adjacente (4-voisinage, y compris hors-grille) à du vide -> outline.
-- Sinon body. On colorise le body par gradient vertical sur la SOUS-RAMPE choisie. cell-grid finale.
local function colorize(filled, fullW, hh, fac, ramp)
  local g = newCells(fullW, hh)
  -- bbox verticale réelle (pour le gradient 0..1).
  local minY, maxY = hh + 1, 0
  for y = 1, hh do
    for x = 1, fullW do
      if filled[y][x] then
        if y < minY then minY = y end
        if y > maxY then maxY = y end
      end
    end
  end
  local span = math.max(1, maxY - minY)

  local function isFilled(x, y)
    return x >= 1 and x <= fullW and y >= 1 and y <= hh and filled[y][x]
  end

  for y = 1, hh do
    for x = 1, fullW do
      if filled[y][x] then
        local edge = (not isFilled(x - 1, y)) or (not isFilled(x + 1, y))
          or (not isFilled(x, y - 1)) or (not isFilled(x, y + 1))
        if edge then
          g[y][x] = fac.outline
        else
          local y01 = (y - minY) / span
          g[y][x] = Ramps.bodyChar(ramp, y01)
        end
      end
    end
  end
  return g, minY, maxY
end

-- ─────────────────────────── Injection des détails (hybride B+A) ───────────────────────────
-- detail = sous-grille de RÔLES (O contour / B body moyen / A,a accents) injectée à (cx,cy). ax/ay = ancre 0-indexée.
local function stampDetail(g, fullW, hh, detail, cx, cy, fac, ramp, accentPair)
  local dgrid = detail.grid
  for dy = 1, #dgrid do
    local row = dgrid[dy]
    for dx = 1, #row do
      local r = row:sub(dx, dx)
      if r ~= "." and r ~= " " then
        local gx = cx + (dx - 1) - detail.ax
        local gy = cy + (dy - 1) - detail.ay
        if gx >= 1 and gx <= fullW and gy >= 1 and gy <= hh then
          local ch
          if r == "O" then ch = fac.outline
          elseif r == "B" then ch = ramp[3]
          elseif r == "A" then ch = accentPair[1]
          elseif r == "a" then ch = accentPair[2]
          end
          if ch then g[gy][gx] = ch end
        end
      end
    end
  end
end

-- (tweak D/C « visage authored hybride » retiré au nettoyage 2026-06 — remplacé par la refonte src/gen/forge.lua.)

-- Place l'accent (œil/orbite) aux marqueurs "E" du mask, en coords pleines (markers en moitié gauche).
-- eyeCfg = { count=1|2|3, spread=0|1 } : varie le nombre et l'écartement par unité.
--   count 1 -> un œil cyclope au centre ; 2 -> paire symétrique ; 3 -> paire + œil central.
-- Ne peint que sur du body existant (jamais sur du vide) -> reste lisible.
local function stampEyes(g, fullW, hh, markers, accentPair, eyeCfg)
  local function paint(x, y)
    if x >= 1 and x <= fullW and y >= 1 and y <= hh and g[y][x] then g[y][x] = accentPair[1] end
  end
  if #markers == 0 then return end
  -- on se base sur le 1er marqueur comme "ligne des yeux".
  local m = markers[1]
  local center = math.floor(fullW / 2)
  local off = (eyeCfg.spread == 1) and 2 or 1

  -- 1px par œil (évite les bandes SiSiSi). center pour parité paire = colonne juste à gauche du milieu.
  local cl = center            -- œil gauche
  local crr = fullW - center + 1 -- œil droit (miroir exact)
  if eyeCfg.count == 1 then
    paint(center, m.y) -- cyclope : un seul point central
  else
    paint(cl - off + 1, m.y)
    paint(crr + off - 1, m.y)
    -- 3e œil bas (eldritch) : seulement si la tête est assez HAUTE (sinon 2 rangées d'yeux sur une
    -- tête de 2-3px interne -> bandes illisibles). On exige du body 2 rangées sous la ligne d'yeux.
    if eyeCfg.count == 3 and m.y + 1 < hh and g[m.y + 1] and g[m.y + 1][center] then
      paint(center, m.y + 1)
    end
  end
  -- marqueurs supplémentaires du mask (abyss à yeux étagés) : 1px chacun, miroité.
  for i = 2, #markers do
    local mm = markers[i]
    paint(mm.x, mm.y)
    paint(fullW - mm.x + 1, mm.y)
  end
end

-- ─────────────────────────── Armes générées par faction (variantes seedées) ───────────────────────────
-- weapon : pivot au MANCHE en haut, pointe en bas (weaponTip lit (ox, h-1)).
-- Renvoie { grid, pivot } ou nil (abyss : pas d'arme). `variant` ∈ {1,2,3} -> longueur/garde/tête.
local function buildWeapon(rng, fac, accentPair, variant)
  local kind = fac.weapon
  if not kind then return nil end
  local I, K = "I", fac.outline -- corps métal / contour
  if kind == "blade" then
    -- épée : variantes de garde + longueur de lame (court/standard/long).
    local guard = (variant == 2) and {
      "KKKKK",
      "K" .. I .. I .. I .. "K",
      "KKKKK",
    } or {
      " KKK ",
      "K" .. I .. I .. I .. "K",
      "KKKKK",
    }
    local bladeLen = (variant == 3) and 5 or (variant == 1 and 3 or 4)
    local grid = {}
    for _, r in ipairs(guard) do grid[#grid + 1] = r end
    for _ = 1, bladeLen do grid[#grid + 1] = " K" .. I .. "K " end
    grid[#grid + 1] = "  K  "
    return { grid = grid, pivot = { x = 2, y = 0 } }
  elseif kind == "mace" then
    -- masse : tête lourde EN BAS (pivot manche en haut). Variantes de tête (boule/épi/bloc).
    local handle = (variant == 3) and 4 or (variant == 1 and 2 or 3)
    local grid = { " KKK " }
    for _ = 1, handle do grid[#grid + 1] = " K" .. I .. "K " end
    if variant == 2 then -- tête à épis (accent)
      grid[#grid + 1] = "KKKKK"
      grid[#grid + 1] = accentPair[2] .. I .. I .. I .. accentPair[2]
      grid[#grid + 1] = "K" .. I .. I .. I .. "K"
      grid[#grid + 1] = " KKK "
    else -- bloc / boule
      grid[#grid + 1] = "KKKKK"
      grid[#grid + 1] = "K" .. I .. I .. I .. "K"
      grid[#grid + 1] = "K" .. I .. I .. I .. "K"
      grid[#grid + 1] = " KKK "
    end
    return { grid = grid, pivot = { x = 2, y = 0 } }
  elseif kind == "staff" then
    -- bâton : sommet variable (gemme simple / double gemme / fourche). idlePose.weapon=-π (vertical).
    local gem = accentPair[1]
    local body = fac.ramp and fac.ramp[2] or "V"
    local handle = (variant == 3) and 4 or 3
    local grid = {}
    if variant == 2 then -- fourche en haut
      grid = { "K K", "KIK" }
    else
      grid = { " K ", "K" .. I .. "K" }
    end
    for _ = 1, handle do
      grid[#grid + 1] = " K "
      grid[#grid + 1] = "K" .. I .. "K"
    end
    grid[#grid + 1] = " K "
    grid[#grid + 1] = "K" .. gem .. "K"
    if variant == 3 then grid[#grid + 1] = "K" .. gem .. "K" end -- grosse gemme
    grid[#grid + 1] = " K "
    -- `body` réservé pour une future variante de manche teinté ; gardé pour cohérence d'API.
    local _ = body
    return { grid = grid, pivot = { x = 1, y = 0 } }
  end
  return nil
end

-- ─────────────────────────── Bras / griffe ───────────────────────────
-- Un bras = limbe FIN 3 de large (K-body-K) ; pivot au sommet (épaule). La longueur vient du mask.
-- Abyss (deformed, sans arme) : armFront se termine en griffe (accent) -> attaque par défaut l'abat.
local function buildArm(rng, half, fac, ramp, accentPair, isClaw)
  local len = #half
  local body = ramp[2]
  local K = fac.outline
  local grid = {}
  for y = 1, len do grid[y] = K .. body .. K end
  if isClaw then
    -- main griffue : 3 dards accent en bas.
    grid[len] = K .. body .. K
    grid[len + 1] = accentPair[1] .. K .. accentPair[1]
  else
    -- main fermée : un cran d'ombre + pointe.
    grid[len] = K .. fac.shade .. K
    grid[len + 1] = " " .. K .. " "
  end
  return { grid = grid, pivot = { x = 1, y = 0 } } -- pivot épaule en haut
end

-- ─────────────────────────── Construction d'une part ───────────────────────────
-- half = demi-mask CHOISI (variante seedée). cfg = { ramp, corp, eyeCfg, detailChance, pivotMode }.
local function buildPart(rng, half, fac, accentPair, asym, cfg, allowDetails)
  local filled, markers, fullW, hh = fillAndMirror(rng, half, cfg.density, cfg.corp)
  addAsymmetry(rng, filled, fullW, hh, asym)
  pruneOrphans(filled, fullW, hh)
  local g, minY, maxY = colorize(filled, fullW, hh, fac, cfg.ramp)
  if allowDetails or #markers > 0 then stampEyes(g, fullW, hh, markers, accentPair, cfg.eyeCfg) end

  -- Détails signature (hybride B+A) : marques discrètes (flesh/order/bone), cornes/tentacules (abyss),
  -- runes (arcane). PLACEMENT séparé de la ligne d'yeux -> jamais de cluster d'accent sur le visage.
  --   horn/tentacle -> sommet/bord ; autres marques -> FRONT (au-dessus des yeux) ou bord latéral.
  if allowDetails and #fac.details > 0 and rng:random() < cfg.detailChance then
    local pick = fac.details[rng:random(1, #fac.details)]
    local d = Details[pick]
    if d then
      local cx, cy
      local eyeY = (markers[1] and markers[1].y) or math.floor((minY + maxY) / 2)
      if pick == "horn" or pick == "tentacle" then
        cx = rng:random(2, math.max(2, fullW - 1)); cy = minY -- excroissance au sommet
      else
        -- marque sur le FRONT (une rangée au-dessus des yeux) si possible, sinon sur le bord.
        cy = math.max(minY, eyeY - 1)
        cx = (rng:random(0, 1) == 0) and math.floor(fullW / 2) or (2 + rng:random(0, math.max(0, fullW - 4)))
      end
      stampDetail(g, fullW, hh, d, cx, cy, fac, cfg.ramp, accentPair)
    end
  end

  -- ORNEMENT DE RANG (rareté) : couronne/épines au SOMMET. On rajoute des rangées vides en haut pour
  -- la place (base-pivot seulement -> le pivot BAS ne bouge pas). DÉTERMINISTE (aucun rng) : ornament==0
  -- ne fait STRICTEMENT rien -> unités existantes (rank 1) byte-identiques.
  if (cfg.ornament or 0) > 0 and cfg.pivotMode ~= "top" then
    local pad = 3
    local g2 = newCells(fullW, hh + pad)
    for y = 1, hh do for x = 1, fullW do g2[y + pad][x] = g[y][x] end end
    g, hh, minY, maxY = g2, hh + pad, minY + pad, maxY + pad
    local cx = math.floor(fullW / 2)
    stampDetail(g, fullW, hh, Details.crown, cx, minY, fac, cfg.ramp, accentPair)
    if cfg.ornament >= 2 then -- épines dorsales/latérales symétriques
      local off = math.max(2, math.floor(fullW / 4))
      stampDetail(g, fullW, hh, Details.spike, cx - off, minY, fac, cfg.ramp, accentPair)
      stampDetail(g, fullW, hh, Details.spike, cx + off, minY, fac, cfg.ramp, accentPair)
    end
    if cfg.ornament >= 3 then -- corne centrale plus haute (légendaire)
      stampDetail(g, fullW, hh, Details.horn, cx, minY - 1, fac, cfg.ramp, accentPair)
    end
  end

  -- Pivot : x = centre de la bbox horizontale ; y selon le mode.
  local minX, maxX = fullW + 1, 0
  for y = 1, hh do
    for x = 1, fullW do
      if g[y][x] then
        if x < minX then minX = x end
        if x > maxX then maxX = x end
      end
    end
  end
  if maxX == 0 then minX, maxX = 1, fullW end -- garde-fou : part vide improbable
  local px = math.floor((minX + maxX) / 2) - 1 -- 0-indexé
  local py = (cfg.pivotMode == "top") and 0 or (maxY - 1) -- base = bas de la silhouette
  if py < 0 then py = 0 end

  return { grid = cellsToStrings(g), pivot = { x = px, y = py } }, hh, fullW
end

-- ─────────────────────────── Gabarits de rig par squelette ───────────────────────────
-- at = position où le PIVOT de la part se place dans l'espace local du parent (cf. rig.lua).
-- Calqué sur les 6 créatures main pour rester cohérent (humanoïde ~ marauder ; robe ~ witch).
local function assembleRig(skeleton, parts)
  if skeleton == "robe" then
    return {
      { part = "armBack", at = { -2, -7 } },
      { part = "torso", at = { 0, 0 } },
      { part = "head", parent = "torso", at = { 4, 0 } },
      { part = "armFront", parent = "torso", at = { 7, 1 } },
      parts.weapon and { part = "weapon", parent = "armFront", at = { 1, 6 } } or nil,
    }, { armFront = 0, weapon = -math.pi } -- bâton vertical
  elseif skeleton == "deformed" then
    return {
      { part = "legs", at = { 0, -5 } },
      { part = "armBack", at = { -2, -10 } },
      { part = "torso", at = { 0, -5 } },
      { part = "head", parent = "torso", at = { 3, 0 } },
      { part = "armFront", parent = "torso", at = { 6, 1 } }, -- griffe (pas d'arme)
    }, { armFront = 0, armBack = 0 }
  else -- humanoid
    return {
      { part = "legs", at = { 0, -5 } },
      { part = "armBack", at = { -2, -10 } },
      { part = "torso", at = { 0, -5 } },
      { part = "head", parent = "torso", at = { 3, 0 } },
      { part = "armFront", parent = "torso", at = { 6, 1 } },
      parts.weapon and { part = "weapon", parent = "armFront", at = { 1, 6 } } or nil,
    }, { armFront = 0, weapon = -math.pi / 2 } -- arme horizontale forward
  end
end

-- ─────────────────────────── Anims custom auto par squelette (Phase 3) ───────────────────────────
local function autoAnims(skeleton)
  local Rig = require("src.core.rig") -- require tardif : évite un cycle si rig requiert gen un jour
  if skeleton == "robe" then
    return { idle = function(char, t)
      Rig.defaultIdle(char, t)
      local ph = char.idlePhase
      if char.parts.weapon then
        char.parts.weapon.rot = char.parts.weapon.rot + math.sin(t * 0.06 + ph) * 0.04
      end
      if char.parts.torso then char.parts.torso.rot = math.sin(t * 0.03 + ph) * 0.015 end
      return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 1 }
    end }
  elseif skeleton == "deformed" then
    return { idle = function(char, t)
      local res = Rig.defaultIdle(char, t)
      local ph = char.idlePhase
      if char.parts.head then char.parts.head.rot = char.parts.head.rot + math.sin(t * 0.05 + ph) * 0.03 end
      return res
    end }
  end
  return nil -- humanoïde : idle par défaut suffit
end

-- ═══════════════════════════ BODY-PLANS NON-BIPÈDES (axe découplé de la faction) ═══════════════════════════
-- La FAMILLE (opts.type) porte palette/accent/détails ; le BODY-PLAN (opts.bodyplan) porte la SILHOUETTE.
-- Ces builders sortent { parts, rig, idlePose, animations } comme assembleRig+autoAnims, mais pour des
-- formes radicalement non-bipèdes. Ils RÉUTILISENT buildPart (masks miroités) et buildArm (limbes fins).
-- Append-only : ces plans ne sont atteints que si opts.bodyplan est fourni -> golden/déterminisme intacts.

local function partWH(grid)
  local h = #grid
  local w = 0
  for _, r in ipairs(grid) do if #r > w then w = #r end end
  return w, h
end

-- demi-mask factice de longueur n (buildArm ne lit que #half pour la longueur du limbe).
local function dummyHalf(n)
  local t = {}
  for i = 1, n do t[i] = 0 end
  return t
end

-- Segment de serpent : bloc plein RECTANGULAIRE (contour latéral + corps), pivot TOP-center -> il s'empile
-- proprement (le top de l'enfant se pose dans le corps du parent = chaîne CONNEXE, jamais de gap). w impair.
local function buildSegment(fac, ramp, w, h)
  local K, body = fac.outline, ramp[2]
  local grid = {}
  for _ = 1, h do
    local row = K
    for _ = 2, w - 1 do row = row .. body end
    grid[#grid + 1] = row .. K
  end
  return { grid = grid, pivot = { x = math.floor(w / 2), y = 0 } } -- pivot sommet (chaînage vers le haut)
end

-- ── Anims de plan (écrivent rot/sx/sy ; le scale se fait AUTOUR du pivot -> base-pivot = pousse vers le haut) ──
-- BLOB : la masse PULSE (squash/stretch volume-ish). Aucun membre.
local BLOB_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  local b = char.parts.bulb
  if b then
    local s = math.sin(t * 0.045 + ph)
    b.sy = 1 + s * 0.06
    b.sx = 1 - s * 0.045
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.03 + ph) * 0.6 }
end }

-- QUADRUPÈDE : échine qui respire, pattes alternées, tête basse qui balance.
local QUAD_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  local p = char.parts
  if p.body then p.body.sy = 1 + math.sin(t * 0.04 + ph) * 0.02 end
  if p.head then p.head.rot = math.sin(t * 0.05 + ph) * 0.05 end
  for name, part in pairs(p) do
    if name:match("^leg") then
      local sgn = (name == "legFL" or name == "legBL") and 1 or -1
      part.rot = math.sin(t * 0.06 + ph) * 0.06 * sgn
    end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 0.8 }
end }

-- CÉPHALOPODE : mantle qui pulse, tentacules qui ONDULENT déphasées (closure sur le nombre).
local function cephAnim()
  return { idle = function(char, t)
    local ph = char.idlePhase
    if char.parts.mantle then char.parts.mantle.sy = 1 + math.sin(t * 0.035 + ph) * 0.03 end
    for name, part in pairs(char.parts) do
      local idx = name:match("^tentacle(%d+)$")
      if idx then part.rot = math.sin(t * 0.06 + ph + tonumber(idx) * 0.9) * 0.22 end
    end
    return { rootDx = 0, rootDy = math.sin(t * 0.03 + ph) * 1.2 } -- flotte
  end }
end

-- ── Builders (rng, fac, lv) -> parts, rig, idlePose, animations. lv = leviers seedés déjà tirés. ──
local function planBlob(rng, fac, lv)
  local variants = Masks.get("blob").body.variants
  local half = variants[((lv.torsoIdx - 1) % #variants) + 1]
  local bulb = (buildPart(rng, half, fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = 0, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  return { bulb = bulb }, { { part = "bulb", at = { 0, 0 } } }, {}, BLOB_ANIM
end

local function planQuadruped(rng, fac, lv)
  local M = Masks.get("quadruped")
  local bodyV = M.body.variants
  local headV = M.head.variants
  -- ornement sur le DOS (corps, base-pivot) -> épines dorsales : lecture « bête de haut rang ».
  local body = (buildPart(rng, bodyV[((lv.torsoIdx - 1) % #bodyV) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, false))
  -- tête à pivot HAUT : elle PEND depuis le bas-centre du corps (gueule baissée entre les pattes avant),
  -- sinon (pivot base) elle se dessinerait DANS le bloc-corps et resterait invisible.
  local head = (buildPart(rng, headV[((lv.headIdx - 1) % #headV) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = 0, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "top",
  }, true))
  local legLen = 3 + rng:random(0, 1) -- 3-4 (seedé)
  local function leg() return (buildArm(rng, dummyHalf(legLen), fac, lv.ramp, lv.accentPair, false)) end
  local parts = { body = body, head = head, legBL = leg(), legBR = leg(), legFL = leg(), legFR = leg() }
  local bw, bh = partWH(body.grid)
  -- pattes = enfants du corps (émergent du bas) ; 4 colonnes réparties. Le corps est relevé d'une longueur
  -- de patte pour que les pieds touchent la ligne de sol. Tête baissée au centre-façade (pend du corps).
  local x1, x2 = 2, bw - 2
  local rig = {
    { part = "legBL", parent = "body", at = { x1, bh - 1 } },
    { part = "legBR", parent = "body", at = { x2, bh - 1 } },
    { part = "body", at = { 0, -legLen + 1 } },
    { part = "legFL", parent = "body", at = { x1 - 1, bh } },
    { part = "legFR", parent = "body", at = { x2 + 1, bh } },
    { part = "head", parent = "body", at = { math.floor(bw / 2), bh - 2 } },
  }
  return parts, rig, {}, QUAD_ANIM
end

local function planCephalopod(rng, fac, lv)
  local variants = Masks.get("cephalopod").mantle.variants
  local mantle = (buildPart(rng, variants[((lv.headIdx - 1) % #variants) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  local mw, mh = partWH(mantle.grid)
  local nTent = 4 + rng:random(0, 2) -- 4-6 tentacules (seedé)
  local parts = { mantle = mantle }
  local rig = {}
  local span = math.max(2, mw - 2)
  local maxLen = 0
  for i = 1, nTent do
    local len = 4 + rng:random(0, 2)
    if len > maxLen then maxLen = len end
    parts["tentacle" .. i] = (buildArm(rng, dummyHalf(len), fac, lv.ramp, lv.accentPair, false))
    local fx = 1 + math.floor((i - 0.5) * span / nTent) -- réparties sur la largeur du mantle
    rig[#rig + 1] = { part = "tentacle" .. i, parent = "mantle", at = { fx, mh - 1 } }
  end
  -- mantle relevé pour que les tentacules atteignent ~le sol ; dessiné AVANT (les tentacules par-dessus).
  table.insert(rig, 1, { part = "mantle", at = { 0, -maxLen + 2 } })
  return parts, rig, {}, cephAnim()
end

-- ── SWARM : amas grouillant. La masse-« core » micro-jitter par sous-élément (yeux désynchronisés via les
-- positions des E -> chaque colonne tremble à sa phase) + bob lent. On déphase par la PARITÉ de la colonne du
-- pixel pour donner l'illusion de plusieurs petits corps qui s'agitent (pas un bloc rigide). ──
local SWARM_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  local c = char.parts.core
  if c then
    -- squash/stretch léger asymétrique (la masse « bout »).
    c.sx = 1 + math.sin(t * 0.07 + ph) * 0.03
    c.sy = 1 + math.cos(t * 0.06 + ph * 1.7) * 0.025
    c.rot = math.sin(t * 0.05 + ph) * 0.02 -- frémit
  end
  return { rootDx = math.sin(t * 0.08 + ph * 2.3) * 0.5, rootDy = math.sin(t * 0.04 + ph) * 0.5 }
end }

-- ── SERPENT : onde sinusoïdale le long de la chaîne de segments (rot indexée) + gueule qui tangue. ──
local SERPENT_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  for name, part in pairs(char.parts) do
    local idx = name:match("^segment(%d+)$")
    if idx then part.rot = math.sin(t * 0.07 + ph + tonumber(idx) * 0.6) * 0.18 end
  end
  if char.parts.head then char.parts.head.rot = math.sin(t * 0.06 + ph) * 0.08 end
  return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 0.6 }
end }

-- ── ARACHNID : pattes qui « tapotent » par paires déphasées (gauche vs droite alternées) + corps micro-bob. ──
local ARACHNID_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  if char.parts.body then char.parts.body.sy = 1 + math.sin(t * 0.05 + ph) * 0.02 end
  if char.parts.head then char.parts.head.rot = math.sin(t * 0.05 + ph) * 0.04 end
  for name, part in pairs(char.parts) do
    local idx = name:match("^leg(%d+)$")
    if idx then
      local i = tonumber(idx)
      -- déphasage par patte : pattes voisines tapotent en décalé (effet « marche sur place » nerveuse).
      part.rot = math.sin(t * 0.09 + ph + i * 1.3) * 0.05
    end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.045 + ph) * 0.5 }
end }

-- ── EYE : orbe qui FLOTTE (rootDy fort & lent) + pupille qui pulse (sy/alpha léger). ──
local EYE_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  local o = char.parts.orb
  if o then
    -- pulse de l'orbe (respiration de globe) + très léger roulis.
    o.sy = 1 + math.sin(t * 0.045 + ph) * 0.035
    o.sx = 1 - math.sin(t * 0.045 + ph) * 0.025
    o.rot = math.sin(t * 0.03 + ph) * 0.03
  end
  -- flottaison ample et lente (il LÉVITE, ne marche pas) + dérive horizontale douce.
  return { rootDx = math.sin(t * 0.025 + ph) * 1.2, rootDy = math.sin(t * 0.028 + ph) * 2.6 }
end }

-- SWARM : une masse-core unique (base-pivot, porte l'ornement) ; toute la diversité vient des E du mask.
local function planSwarm(rng, fac, lv)
  local variants = Masks.get("swarm").core.variants
  local core = (buildPart(rng, variants[((lv.torsoIdx - 1) % #variants) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  return { core = core }, { { part = "core", at = { 0, 0 } } }, {}, SWARM_ANIM
end

-- SERPENT : cobra dressé. La GUEULE (tête, base-pivot, yeux + ornement) est la RACINE en haut ; la queue
-- s'effile vers le BAS en segments chaînés (parent->enfant) qui se RECOUVRENT d'1 px (chaîne CONNEXE,
-- jamais de gap), décalés G/D alternés = l'ondulation en S. Pivots TOP-center (buildSegment) : l'enfant
-- pend SOUS son parent. Largeur décroissante (5->3) -> conicité ; verticalité + S = lecture « serpent ».
local function planSerpent(rng, fac, lv)
  local nSeg = 5 + rng:random(0, 2) -- 5-7 segments de queue (seedé)
  local parts = {}
  -- gueule = racine en haut (base-pivot pour porter l'ornement/couronne au sommet).
  local headV = Masks.get("serpent").head.variants
  parts.head = (buildPart(rng, headV[((lv.headIdx - 1) % #headV) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = 0, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  local hw = partWH(parts.head.grid)

  local segH = {}
  for i = 1, nSeg do
    segH[i] = 2 + rng:random(0, 1)                   -- 2-3 px de haut par segment
    -- largeur décroissante du cou (5) vers la queue (3), impaire pour un axe propre.
    local w = 5 - 2 * math.floor((i - 1) * 2 / nSeg) -- 5 puis 3
    if w < 3 then w = 3 end
    parts["segment" .. i] = buildSegment(fac, lv.ramp, w, segH[i])
  end

  -- rig : head (racine) -> segment1 pendu sous la gueule -> segment2 sous segment1 -> ... (queue qui tombe).
  -- La tête est en base-pivot : sa rangée du BAS est à y=0 dans son espace local. segment1 (pivot TOP) se
  -- pose à y=-1 (recouvrement 1px = connexité). Chaque segment suivant pend de (segH-1) sous son parent.
  local _ = hw
  local rig = { { part = "head", at = { 0, 0 } } }
  rig[#rig + 1] = { part = "segment1", parent = "head", at = { 0, -1 } }
  for i = 2, nSeg do
    local sway = ((i % 2 == 0) and 1 or -1)
    rig[#rig + 1] = { part = "segment" .. i, parent = "segment" .. (i - 1), at = { sway, segH[i - 1] - 1 } }
  end
  return parts, rig, {}, SERPENT_ANIM
end

-- ARACHNID : corps central compact (base-pivot, ornement) + 6-8 pattes anguleuses rayonnantes.
-- Pattes = buildArm `legN` (limbes fins) écartées en éventail bas de part et d'autre, longueurs/positions
-- seedées. Le corps est relevé d'une longueur de patte pour que les pieds touchent ~le sol.
local function planArachnid(rng, fac, lv)
  local variants = Masks.get("arachnid").body.variants
  local body = (buildPart(rng, variants[((lv.torsoIdx - 1) % #variants) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  local bw, bh = partWH(body.grid)
  local nLeg = 6 + rng:random(0, 1) * 2 -- 6 ou 8 (paires)
  local perSide = nLeg / 2
  local parts = { body = body }
  -- pattes plus LONGUES vers l'extérieur (la patte la plus écartée touche le sol comme les internes alors
  -- qu'elle attache plus haut -> aspect anguleux rayonnant). longueurs seedées légèrement.
  local legLen, maxLen = {}, 0
  for i = 1, nLeg do
    local k = ((i - 1) % perSide) + 1                    -- rang 1..perSide sur le côté
    legLen[i] = 3 + k + rng:random(0, 1)                 -- interne court .. externe longue
    if legLen[i] > maxLen then maxLen = legLen[i] end
    parts["leg" .. i] = (buildArm(rng, dummyHalf(legLen[i]), fac, lv.ramp, lv.accentPair, false))
  end
  -- EMPREINTE RADIALE : les attaches s'ÉCARTENT horizontalement DE PART ET D'AUTRE du corps (k=1 collé au
  -- flanc, k=perSide loin dehors) et MONTENT (attache plus haute => patte plus longue => pieds au même sol).
  -- C'est l'étalement des x d'attache (pas une rotation au build) qui crée la large empreinte d'araignée.
  local rig = {}
  for i = 1, nLeg do
    local side = (i <= perSide) and -1 or 1               -- gauche / droite
    local k = ((i - 1) % perSide) + 1                     -- 1 (interne) .. perSide (externe)
    local fx = (side < 0) and (1 - (k - 1)) or (bw + (k - 1)) -- s'écarte hors du corps
    local fy = math.floor(bh * 0.35) - (k - 1)            -- externe = épaule plus HAUTE (patte plus longue)
    rig[#rig + 1] = { part = "leg" .. i, parent = "body", at = { fx, fy } }
  end
  -- corps dessiné PAR-DESSUS les pattes (inséré en tête), relevé pour que les pattes atteignent ~le sol.
  table.insert(rig, 1, { part = "body", at = { 0, -maxLen + 2 } })
  return parts, rig, {}, ARACHNID_ANIM
end

-- EYE : orbe unique flottant (base-pivot, porte l'ornement = couronne d'épines au rang haut). Une seule grosse
-- idée : le disque. Il flotte AU-DESSUS du sol -> l'`at` le remonte (et l'anim ajoute un rootDy ample).
local function planEye(rng, fac, lv)
  local variants = Masks.get("eye").orb.variants
  local orb = (buildPart(rng, variants[((lv.headIdx - 1) % #variants) + 1], fac, lv.accentPair, fac.asym, {
    ramp = lv.ramp, density = lv.density, corp = 0, eyeCfg = lv.eyeCfg,
    detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament,
  }, true))
  -- remonté de quelques pixels : il lévite (les pieds-de-sol des autres plans ne s'appliquent pas).
  return { orb = orb }, { { part = "orb", at = { 0, -4 } } }, {}, EYE_ANIM
end

local PlanBuilders = {
  blob = planBlob, quadruped = planQuadruped, cephalopod = planCephalopod,
  swarm = planSwarm, serpent = planSerpent, arachnid = planArachnid, eye = planEye,
}

-- ═══════════════════════════ CHIMÈRE (légendaire R5) : « Le Puits ne crée pas, il assemble. » ═══════════════════════════
-- Fusion de DEUX body-plans : le HAUT (masse-tête) + le BAS (locomotion) viennent de plans distincts.
-- La silhouette VIOLE les attentes (toutes les autres unités sont mono-plan) -> lecture instantanée
-- « anormal/puissant ». Recette FIXÉE en data (bodyplan="chimera:top:bottom"), variation seedée -> snapshot-safe.

-- Anim : pulse de masse + ondulation des tentacules + balancement des pattes/bras (combine les idles).
local CHIMERA_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  local p = char.parts
  if p.mantle then p.mantle.sy = 1 + math.sin(t * 0.035 + ph) * 0.03 end
  if p.torso then p.torso.sy = 1 + math.sin(t * 0.04 + ph) * 0.02 end
  if p.head then p.head.rot = math.sin(t * 0.04 + ph + 0.7) * 0.03 end
  for name, part in pairs(p) do
    local idx = name:match("^tentacle(%d+)$")
    if idx then
      part.rot = math.sin(t * 0.06 + ph + tonumber(idx) * 0.9) * 0.20
    elseif name:match("^arm") then
      part.rot = math.sin(t * 0.04 + ph + 0.5) * 0.04
    elseif name:match("^leg") then
      local sgn = (name == "legFL" or name == "legBL") and 1 or -1
      part.rot = math.sin(t * 0.06 + ph) * 0.05 * sgn
    end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.03 + ph) * 1.0 }
end }

-- top ∈ {humanoid, cephalopod} (masse-tête) ; bottom ∈ {quadruped, tentacles} (locomotion).
local function buildChimera(rng, fac, lv, top, bottom)
  local parts = {}
  local legLen = 3 + rng:random(0, 1)
  local tentLen = 4 + rng:random(0, 2)
  local botLen = (bottom == "tentacles") and tentLen or legLen

  -- ── HAUT : masse-tête (part « core », base-pivot) ──
  local coreName, coreW, coreH
  if top == "humanoid" then
    local HM = Masks.get("humanoid")
    parts.torso = (buildPart(rng, HM.torso.variants[((lv.torsoIdx - 1) % #HM.torso.variants) + 1], fac, lv.accentPair, fac.asym,
      { ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg, detailChance = lv.detailChance, pivotMode = "base", ornament = 0 }, false))
    parts.head = (buildPart(rng, HM.head.variants[((lv.headIdx - 1) % #HM.head.variants) + 1], fac, lv.accentPair, fac.asym,
      { ramp = lv.ramp, density = lv.density, corp = 0, eyeCfg = lv.eyeCfg, detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament }, true))
    parts.armBack = (buildArm(rng, dummyHalf(4), fac, lv.ramp, lv.accentPair, true))  -- griffes (chimère monstrueuse)
    parts.armFront = (buildArm(rng, dummyHalf(4), fac, lv.ramp, lv.accentPair, true))
    coreName = "torso"; coreW, coreH = partWH(parts.torso.grid)
  else -- cephalopod : mantle bulbeux à yeux multiples
    local mv = Masks.get("cephalopod").mantle.variants
    parts.mantle = (buildPart(rng, mv[((lv.headIdx - 1) % #mv) + 1], fac, lv.accentPair, fac.asym,
      { ramp = lv.ramp, density = lv.density, corp = lv.corp, eyeCfg = lv.eyeCfg, detailChance = lv.detailChance, pivotMode = "base", ornament = lv.ornament }, true))
    coreName = "mantle"; coreW, coreH = partWH(parts.mantle.grid)
  end

  -- ── BAS : locomotion (pattes de bête OU jupe de tentacules) ──
  local nTent = 0
  if bottom == "quadruped" then
    for _, nm in ipairs({ "legBL", "legBR", "legFL", "legFR" }) do
      parts[nm] = (buildArm(rng, dummyHalf(legLen), fac, lv.ramp, lv.accentPair, false))
    end
  else
    nTent = 4 + rng:random(0, 2)
    for i = 1, nTent do
      parts["tentacle" .. i] = (buildArm(rng, dummyHalf(tentLen + rng:random(0, 1)), fac, lv.ramp, lv.accentPair, false))
    end
  end

  -- ── RIG : membres arrière (derrière) -> core relevé -> membres avant + tête ──
  local rig = {}
  local x1, x2 = 2, coreW - 2
  if bottom == "quadruped" then
    rig[#rig + 1] = { part = "legBL", parent = coreName, at = { x1, coreH - 1 } }
    rig[#rig + 1] = { part = "legBR", parent = coreName, at = { x2, coreH - 1 } }
  end
  rig[#rig + 1] = { part = coreName, at = { 0, -botLen + 1 } }
  if top == "humanoid" then
    rig[#rig + 1] = { part = "armBack", parent = "torso", at = { 1, 1 } }
    rig[#rig + 1] = { part = "head", parent = "torso", at = { math.floor(coreW / 2) - 1, 0 } }
    rig[#rig + 1] = { part = "armFront", parent = "torso", at = { coreW - 1, 1 } }
  end
  if bottom == "quadruped" then
    rig[#rig + 1] = { part = "legFL", parent = coreName, at = { x1 - 1, coreH } }
    rig[#rig + 1] = { part = "legFR", parent = coreName, at = { x2 + 1, coreH } }
  else
    local span = math.max(2, coreW - 2)
    for j = 1, nTent do
      rig[#rig + 1] = { part = "tentacle" .. j, parent = coreName, at = { 1 + math.floor((j - 0.5) * span / nTent), coreH - 1 } }
    end
  end

  local idlePose = (top == "humanoid") and { armFront = 0, armBack = 0 } or {}
  return parts, rig, idlePose, CHIMERA_ANIM
end

-- ─────────────────────────── API publique ───────────────────────────
-- opts = { id, type, tier?, effects?, seed?, bodyplan?, rank? }
--   type     = FAMILLE (palette/accent/détails) ; bodyplan = SILHOUETTE (défaut = squelette de la famille).
--   rank     = 1..5 (rareté ; métadonnée pour l'instant, pilotera échelle/cadre/glow côté render).
-- Déterministe : (id) -> toujours la même def (seed = hashId(id) sauf si opts.seed fourni).
function CreatureGen.build(opts)
  local id = opts.id or "anon"
  local fac = Factions.get(opts.type)
  local tier = opts.tier or 1
  local seed = opts.seed or hashId(id)
  local rng = love.math.newRandomGenerator(seed)

  -- ═══ LEVIERS DE VARIÉTÉ : tirés AVANT la génération, en ORDRE FIXE (déterminisme). Chaque tirage
  -- diverge entre deux ids (seeds) différents -> deux unités même faction = silhouette/teinte/arme
  -- distinctes, tout en restant fidèles à la faction. ═══
  local rampIdx   = rng:random(1, #fac.ramps)          -- 1) sous-rampe (teinte intra-faction)
  local ramp      = fac.ramps[rampIdx]
  local headIdx   = rng:random(1, 4)                    -- 2) variante de silhouette de tête
  local torsoIdx  = rng:random(1, 4)                    -- 3) variante de torse
  local legIdx    = rng:random(1, 3)                    -- 4) variante de jambes
  local corp      = rng:random(0, 2)                    -- 5) corpulence (0 fin .. 2 massif)
  local wpnVar    = rng:random(1, 3)                    -- 6) variante d'arme
  local eyeCount  = rng:random(1, 3)                    -- 7) nombre d'yeux
  local eyeSpread = rng:random(0, 1)                    -- 8) écartement des yeux
  -- détails fréquents mais pas systématiques (head = yeux OU marque, rarement les deux saturés).
  local detailChance = 0.40 + fac.asym * 0.45

  -- tier agit sur l'INTENSITÉ seulement (pas la silhouette) : densité des cellules molles.
  local density = 0.5 + math.min(2, tier - 1) * 0.12
  local accentPair = Ramps.accentFor(opts.effects, fac.accent)
  -- AXE DÉCOUPLÉ : la famille (opts.type) porte la palette ; le BODY-PLAN porte la silhouette. Par défaut
  -- bodyplan = squelette de la faction (rétro-compat : unités existantes inchangées, golden/seeds intacts).
  local bodyplan = opts.bodyplan or fac.skeleton
  local rank = opts.rank or 1
  local rar = Rarity.get(rank) -- leviers visuels de rareté (échelle/ornement/glow), bornés & déterministes

  -- leviers seedés communs aux builders non-bipèdes + chimère (AUCUN RNG ici -> ordre de tirage préservé).
  local lv = {
    ramp = ramp, density = density, corp = corp, detailChance = detailChance,
    eyeCfg = { count = eyeCount, spread = eyeSpread },
    headIdx = headIdx, torsoIdx = torsoIdx, legIdx = legIdx, accentPair = accentPair,
    rank = rank, ornament = rar.ornament,
  }
  -- chimère = "chimera:top:bottom" (légendaire). Le `match` 2-captures DOIT être hors multi-assign avec `and`.
  local chimTop, chimBot
  if type(bodyplan) == "string" then chimTop, chimBot = bodyplan:match("^chimera:([^:]+):([^:]+)$") end

  local parts, rig, idlePose, animations
  if chimTop then
    parts, rig, idlePose, animations = buildChimera(rng, fac, lv, chimTop, chimBot)
  elseif PlanBuilders[bodyplan] then
    -- Body-plan non-bipède (blob/quadruped/cephalopod) : builder dédié. Les leviers seedés déjà tirés
    -- sont passés tels quels -> mêmes tirages quelle que soit la forme, déterminisme préservé.
    parts, rig, idlePose, animations = PlanBuilders[bodyplan](rng, fac, lv)
  else
    -- Humanoïde / robe / difforme (LEGACY, inchangé) : masks miroités + gabarit de rig + anims auto.
    local masks = Masks.get(bodyplan)
    -- sélection de variante bornée au nombre réel disponible (index seedé -> modulo lisible).
    local function pickVariant(part, idx)
      local vs = part.variants
      return vs[((idx - 1) % #vs) + 1]
    end

    parts = {}
    -- ORDRE FIXE de génération (déterminisme : même suite de tirages quel que soit l'ordre des clés).
    local PART_ORDER = { "head", "torso", "armBack", "armFront", "legs" }
    local clawHands = (bodyplan == "deformed") -- abyss : pas d'arme -> griffes
    for _, name in ipairs(PART_ORDER) do
      local part = masks[name]
      if part then
        if name == "armBack" or name == "armFront" then
          -- bras fins 3-large (la griffe abyss ne s'applique qu'au bras AVANT).
          local half = pickVariant(part, 1)
          parts[name] = buildArm(rng, half, fac, ramp, accentPair, clawHands and name == "armFront")
        else
          local idx = (name == "head") and headIdx or (name == "torso") and torsoIdx or legIdx
          local half = pickVariant(part, idx)
          local allowDetails = (name == "head")
          -- corpulence : seulement sur le TORSE (le tronc s'épaissit). head/legs gardent une largeur
          -- propre -> pas d'encoche d'axe ni de centre d'yeux décalé.
          local cfg = {
            ramp = ramp, density = density,
            corp = (name == "torso") and corp or 0,
            eyeCfg = { count = eyeCount, spread = eyeSpread },
            detailChance = detailChance,
            pivotMode = (name == "legs") and "top" or "base",
            ornament = (name == "head") and rar.ornament or 0, -- couronne de rang sur la tête
          }
          parts[name] = (buildPart(rng, half, fac, accentPair, fac.asym, cfg, allowDetails))
        end
      end
    end

    -- Arme (faction) : générée après les parts pour un ordre de tirage stable.
    local w = buildWeapon(rng, fac, accentPair, wpnVar)
    if w then parts.weapon = w end

    rig, idlePose = assembleRig(bodyplan, parts)
    animations = autoAnims(bodyplan)
  end

  -- compacte le rig (assembleRig peut insérer des nil via `and ... or nil`).
  local cleanRig = {}
  for _, node in ipairs(rig) do cleanRig[#cleanRig + 1] = node end

  local def = {
    name = id:upper(),
    parts = parts,
    rig = cleanRig,
    idlePose = idlePose,
    animations = animations,
    bodyplan = bodyplan, -- métadonnée de forme
    rank = rank,
    scale = rar.scale,   -- échelle du sprite (lue par Rig.draw) : rangs hauts = plus imposants
    glow = rar.glow,     -- alpha de halo additif (lu par le render : galerie/arène), 0 = aucun
  }
  return def
end

-- ─────────────── MAPPING unité -> famille visuelle (GÉNÉRATEUR PAR PRIMITIVES v3, src/gen/primgen.lua) ───────────────
-- ROLLOUT « ALL IN » (2026-06-22) : `cached` est le POINT DE BASCULE UNIQUE du jeu (galerie/build/Grimoire/
-- combat passent TOUS ici) -> il délègue au générateur par PRIMITIVES pour TOUTES les unités, les 6
-- ex-dessinées-main comprises (src/data/creatures.lua est désormais vide -> les scènes tombent toutes sur cet
-- appel). Le `type` MÉCANIQUE choisit le THÈME visuel (famille v3) ; l'id (FNV-1a) tire l'archétype + la palette
-- DANS cette famille + le seed de corruption -> chaque unité est UNIQUE et DÉTERMINISTE (snapshot-safe).
--   Le legacy `build` (masks + Forge) reste INTACT : il n'est plus sur le chemin du jeu mais le test `gen`
--   l'appelle directement (couverture conservée). require paresseux de Primgen (zéro cycle : primgen n'importe
--   pas creaturegen). Échelle/halo de rareté préservés via Rarity (rangs hauts plus imposants).
-- BASCULE v7 (2026-06-22) : le `type` n'est plus 1 famille mais 1 PÔLE (liste de familles, cf. TYPE_TO_FAMILIES
-- plus bas). `deriveFamily` tire la famille DANS le pôle, biaisée par l'affliction primaire de l'unité
-- (tendance-pôle : un poison-caster eldritch -> spore/plante/cauchemar, pas golem) -> visuel cohérent + varié +
-- déterministe (snapshot-safe). Une unité peut forcer `opts.family` (override). Les 41 familles sont ainsi en jeu.

-- HACHAGE MULTIPLICATIF (nombre d'or) : range un hash entier en n seaux de façon UNIFORME, même quand n est
-- une puissance de 2 (cas où `h % n` s'effondre : les bits faibles de FNV-1a sont mal mélangés -> sinon 13/15
-- unités tombaient sur le même archetype). Le sel est mis en PRÉFIXE (`"arch."..id`) : la queue variable de la
-- chaîne mélange mieux FNV que le suffixe. Arithmétique flottante pure (IEEE déterministe) -> snapshot-safe.
local PHI = 0.6180339887498949
local function bucket(h, n) return 1 + math.floor(((h * PHI) % 1) * n) end

-- PÔLES : type mécanique -> familles visuelles candidates (les 41 réparties sur 5 pôles).
local TYPE_TO_FAMILIES = {
  arcane = { "cauchemar", "oeil", "cristal", "golem", "spore", "plante", "cocon", "chimere" },
  abyss  = { "demon", "cephalo", "abyssal", "kraken", "gelatine", "hydre", "meduse", "ombre" },
  bone   = { "mortvivant", "spectre", "crane", "pendu", "wendigo", "larve", "annelide" },
  flesh  = { "bete", "canide", "bandit", "rongeur", "colosse", "reptile", "echassier", "crustace", "arachnide" },
  order  = { "templier", "inquisiteur", "seraphin", "griffon", "automate", "insecte", "essaim" },
}
-- TENDANCE : familles qui PENCHENT vers chaque affliction (cf. plan §1). On INTERSECTE avec le pôle ;
-- si l'intersection est vide (affliction hors-thème du pôle), on retombe sur tout le pôle (variété préservée).
local LEAN = {
  poison = { cauchemar = 1, spore = 1, plante = 1, cocon = 1, cephalo = 1, kraken = 1, hydre = 1, insecte = 1, essaim = 1, arachnide = 1, reptile = 1, rongeur = 1 },
  rot    = { mortvivant = 1, larve = 1, annelide = 1, pendu = 1, gelatine = 1, ombre = 1, colosse = 1, wendigo = 1, spore = 1 },
  shock  = { oeil = 1, cristal = 1, abyssal = 1, meduse = 1, ombre = 1, automate = 1 },
  bleed  = { bete = 1, canide = 1, echassier = 1, bandit = 1, spectre = 1, wendigo = 1, aile = 1, kraken = 1, griffon = 1 },
  burn   = { demon = 1, culte = 1, crane = 1, inquisiteur = 1, chimere = 1 },
  tank   = { golem = 1, templier = 1, seraphin = 1, griffon = 1, crustace = 1, mortvivant = 1 },
}
local AFFL_CAT = {
  poison = "poison", aura_poison_dps = "poison",
  rot = "rot", aura_rot_growth = "rot", convert_to_rot = "rot", spread_rot = "rot",
  burn = "burn", aura_burn_dps = "burn", spread_burn_on_death = "burn",
  bleed = "bleed", aura_grant_bleed = "bleed",
  shock = "shock",
  shield_aura = "tank", aura_shield = "tank", shield_caster = "tank", thorns = "tank",
}
local function primaryOp(effects)
  if type(effects) == "table" then
    for _, e in ipairs(effects) do if e.op then return e.op end end
  end
  return nil
end
-- (type, affliction, id) -> famille DANS le pôle (tendance respectée si possible), pick par hash d'id.
local function deriveFamily(typ, effects, id)
  local pool = TYPE_TO_FAMILIES[typ] or TYPE_TO_FAMILIES.arcane
  local cat = AFFL_CAT[primaryOp(effects) or ""]
  local lean = cat and LEAN[cat]
  local cands = pool
  if lean then
    local sub = {}
    for _, f in ipairs(pool) do if lean[f] then sub[#sub + 1] = f end end
    if #sub > 0 then cands = sub end
  end
  return cands[bucket(hashId("fam." .. id), #cands)]
end

local CACHE = {}
function CreatureGen.cached(opts)
  local id = opts.id or "anon"
  local rank = opts.rank or 1
  local key = id .. "#" .. rank
  local def = CACHE[key]
  if not def then
    local Primgen = require("src.gen.primgen")
    local fam = opts.family or deriveFamily(opts.type, opts.effects, id)
    local nArch, nPal = Primgen.familyShape(fam)
    -- index DANS la famille, dérivés de l'id (un hash distinct par axe) -> variété par unité sans table dédiée.
    local archIndex = bucket(hashId("arch." .. id), nArch)
    local palIndex  = bucket(hashId("palette." .. id), nPal)
    local rar = Rarity.get(rank)
    def = Primgen.def({
      id = id, family = fam, archIndex = archIndex, paletteIndex = palIndex,
      -- AJUSTEMENT-MONDE : sprite primgen 64px -> ~empreinte de l'ancien générateur dans le board/combat 320x180
      -- (cf. Primgen.WORLD_FIT) -> toutes les scènes (dont arena_draw protégé) fonctionnent sans retouche.
      seed = hashId(id), rank = rank, scale = Primgen.WORLD_FIT * rar.scale, glow = rar.glow,
    })
    CACHE[key] = def
  end
  return def
end

return CreatureGen
