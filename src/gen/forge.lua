-- src/gen/forge.lua
-- THE FORGE — générateur de créatures par ASSEMBLAGE DE PARTS AUTHORED (refonte 2026-06).
--
-- Paradigme (remplace masque→remplissage→edge-detect→gradient, jugé « brouillon ») : on ne GÉNÈRE plus de
-- silhouette/contour/ombrage. On PIOCHE par seed des parts DESSINÉES MAIN (qualité-relique, `src/gen/atlas.lua`),
-- on les RECOLORE par RÔLES selon la famille, et on les ASSEMBLE sur le rig.
--   · Netteté = tout authored (forme+contour+ombrage+focal). · Variété = combinatoire×recolor. · Liberté = dessiner une part.
--
-- Couvre TOUS les body-plans : bipèdes (humanoid/robe/deformed) + host (blob/eye) via gabarits statiques ;
-- multi-membres (quadruped/cephalopod/serpent/arachnid/swarm) + chimères via builders dynamiques (membres
-- répétés/chaînés) — assemblage et anims calqués sur les anciens builders, mais nourris à l'atlas authored.
--
-- `creaturegen.lua` (legacy) reste INTACT. Sortie = def consommable par Rig.new (mêmes champs : name, parts,
-- rig, idlePose, animations?, bodyplan, scale, glow). DÉTERMINISME : seed=hashId(id), tirages en ORDRE FIXE,
-- pools de l'atlas en ARRAY parcourus en ipairs. API LÖVE : love.math.newRandomGenerator (vérifié 11.5).

local Factions = require("src.gen.factions")
local Ramps    = require("src.gen.ramps")
local Rarity   = require("src.gen.rarity")

local Forge = {}

-- ─────────────────────────── Seed stable (FNV-1a 32 bits, autonome) ───────────────────────────
local function bxor_byte(a, b)
  local r, bit = 0, 1
  for _ = 1, 8 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + bit end
    a = (a - x) / 2; b = (b - y) / 2; bit = bit * 2
  end
  return r
end
local function hashId(str)
  local h = 2166136261
  for i = 1, #str do
    local low = h % 256
    h = (h - low) + bxor_byte(low, str:byte(i))
    h = (h * 16777619) % 4294967296
  end
  return h
end
Forge.hashId = hashId

-- ─────────────────────────── Atlas (injectable pour les tests) ───────────────────────────
local ATLAS
function Forge.setAtlas(a) ATLAS = a end
local function atlas()
  if not ATLAS then ATLAS = require("src.gen.atlas") end
  return ATLAS
end

-- ─────────────────────────── Recolor par rôles ───────────────────────────
local function roleTableFor(fac, ramp, acc, outlineRole)
  return {
    O = outlineRole or fac.outline,
    ["1"] = ramp[1], ["2"] = ramp[3], ["3"] = ramp[4],
    s = fac.shade,
    A = acc[1], a = acc[2], E = acc[1],
  }
end

local function bakeRoles(grid, rt)
  local out = {}
  for y = 1, #grid do
    local row, line = grid[y], {}
    for x = 1, #row do
      local r = row:sub(x, x)
      line[x] = (r ~= "." and r ~= " " and rt[r]) or " "
    end
    out[y] = table.concat(line)
  end
  return out
end

local function pivotOf(grid, mode)
  local minX, maxX, maxY = math.huge, 0, 0
  for y = 1, #grid do
    local row = grid[y]
    for x = 1, #row do
      if row:sub(x, x) ~= " " then
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
      end
    end
  end
  if maxX == 0 then return { x = 0, y = 0 } end
  return { x = math.floor((minX + maxX) / 2) - 1, y = (mode == "top") and 0 or math.max(0, maxY - 1) }
end

-- recolore + pivote une part d'atlas -> { grid, pivot } consommable par Rig.new.
local function bakePart(part, rt, mode)
  if not part then return nil end
  local grid = bakeRoles(part.grid, rt)
  return { grid = grid, pivot = pivotOf(grid, mode) }
end

local function partWH(grid)
  local w, h = 0, #grid
  for _, r in ipairs(grid) do if #r > w then w = #r end end
  return w, h
end

-- ─────────────────────────── Pioche déterministe ───────────────────────────
local function has(tags, v)
  if not tags then return false end
  for _, t in ipairs(tags) do if t == v then return true end end
  return false
end

-- pioche dans un pool ARRAY une part compatible (famille+plan), fallbacks garantissant un résultat. ipairs partout.
local function pick(pool, family, bodyplan, rng)
  if not pool or #pool == 0 then return nil end
  local function gather(test)
    local c = {}
    for _, p in ipairs(pool) do if test(p) then c[#c + 1] = p end end
    return c
  end
  local cands = gather(function(p) return has(p.tags, bodyplan) and has(p.tags, family) end)
  if #cands == 0 then cands = gather(function(p) return has(p.tags, bodyplan) end) end
  if #cands == 0 then cands = pool end
  return cands[rng:random(#cands)]
end

-- ═══════════════════════════ Bipèdes + host : gabarits statiques ═══════════════════════════
local PI = math.pi
local LAYOUTS = {
  humanoid = { pose = { armFront = 0, weapon = -PI / 2 }, layout = {
    { part = "legs", at = { 0, -5 } }, { part = "armBack", at = { -2, -10 } }, { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } }, { part = "armFront", parent = "torso", at = { 6, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  } },
  robe = { pose = { armFront = 0, weapon = -PI }, layout = {
    { part = "armBack", at = { -2, -7 } }, { part = "torso", at = { 0, 0 } },
    { part = "head", parent = "torso", at = { 4, 0 } }, { part = "armFront", parent = "torso", at = { 7, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  } },
  deformed = { pose = { armFront = 0, armBack = 0 }, layout = {
    { part = "legs", at = { 0, -5 } }, { part = "armBack", at = { -2, -10 } }, { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } }, { part = "armFront", parent = "torso", at = { 6, 1 } },
  } },
  blob = { pose = {}, layout = { { part = "host", at = { 0, 0 } } } },
  eye  = { pose = {}, layout = { { part = "host", at = { 0, -4 } } } },
}
local BIPED_PICKS = {
  humanoid = { "head", "torso", "arm", "legs", "weapon" },
  robe     = { "head", "torso", "arm", "weapon" },
  deformed = { "head", "torso", "arm", "legs" },
  blob     = { "host" },
  eye      = { "host" },
}
local POOL = { head = "head", torso = "torso", arm = "arm", legs = "legs", weapon = "weapon", host = "host" }
local TOP_PIVOT = { arm = true, legs = true, weapon = true }

local function buildStatic(rng, family, bodyplan, A, rt)
  local got = {}
  for _, slot in ipairs(BIPED_PICKS[bodyplan] or BIPED_PICKS.humanoid) do
    got[slot] = bakePart(pick(A[POOL[slot]], family, bodyplan, rng), rt, TOP_PIVOT[slot] and "top" or "base")
  end
  local parts = { head = got.head, torso = got.torso, legs = got.legs, weapon = got.weapon, host = got.host }
  if got.arm then parts.armBack = got.arm; parts.armFront = got.arm end
  local spec = LAYOUTS[bodyplan] or LAYOUTS.humanoid
  local rig = {}
  for _, node in ipairs(spec.layout) do if parts[node.part] then rig[#rig + 1] = node end end
  return parts, rig, spec.pose, nil
end

-- ═══════════════════════════ Multi-membres : builders dynamiques + anims (portés du legacy) ═══════════════════════════
-- (anims = idle ; lisent char.parts par nom + char.idlePhase. pairs() OK ici : render, pas la SIM.)
local QUAD_ANIM = { idle = function(char, t)
  local ph, p = char.idlePhase, char.parts
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
local CEPH_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  if char.parts.mantle then char.parts.mantle.sy = 1 + math.sin(t * 0.035 + ph) * 0.03 end
  for name, part in pairs(char.parts) do
    local idx = name:match("^tentacle(%d+)$")
    if idx then part.rot = math.sin(t * 0.06 + ph + tonumber(idx) * 0.9) * 0.22 end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.03 + ph) * 1.2 }
end }
local SERPENT_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  for name, part in pairs(char.parts) do
    local idx = name:match("^segment(%d+)$")
    if idx then part.rot = math.sin(t * 0.07 + ph + tonumber(idx) * 0.6) * 0.18 end
  end
  if char.parts.head then char.parts.head.rot = math.sin(t * 0.06 + ph) * 0.08 end
  return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 0.6 }
end }
local ARACHNID_ANIM = { idle = function(char, t)
  local ph = char.idlePhase
  if char.parts.body then char.parts.body.sy = 1 + math.sin(t * 0.05 + ph) * 0.02 end
  for name, part in pairs(char.parts) do
    local idx = name:match("^leg(%d+)$")
    if idx then part.rot = math.sin(t * 0.09 + ph + tonumber(idx) * 1.3) * 0.05 end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.045 + ph) * 0.5 }
end }
local SWARM_ANIM = { idle = function(char, t)
  local ph, c = char.idlePhase, char.parts.core
  if c then
    c.sx = 1 + math.sin(t * 0.07 + ph) * 0.03
    c.sy = 1 + math.cos(t * 0.06 + ph * 1.7) * 0.025
    c.rot = math.sin(t * 0.05 + ph) * 0.02
  end
  return { rootDx = math.sin(t * 0.08 + ph * 2.3) * 0.5, rootDy = math.sin(t * 0.04 + ph) * 0.5 }
end }
local CHIMERA_ANIM = { idle = function(char, t)
  local ph, p = char.idlePhase, char.parts
  if p.mantle then p.mantle.sy = 1 + math.sin(t * 0.035 + ph) * 0.03 end
  if p.torso then p.torso.sy = 1 + math.sin(t * 0.04 + ph) * 0.02 end
  if p.head then p.head.rot = math.sin(t * 0.04 + ph + 0.7) * 0.03 end
  for name, part in pairs(p) do
    local idx = name:match("^tentacle(%d+)$")
    if idx then part.rot = math.sin(t * 0.06 + ph + tonumber(idx) * 0.9) * 0.20
    elseif name:match("^arm") then part.rot = math.sin(t * 0.04 + ph + 0.5) * 0.04
    elseif name:match("^leg") then
      local sgn = (name == "legFL" or name == "legBL") and 1 or -1
      part.rot = math.sin(t * 0.06 + ph) * 0.05 * sgn
    end
  end
  return { rootDx = 0, rootDy = math.sin(t * 0.03 + ph) * 1.0 }
end }

local PLAN = {}

PLAN.quadruped = function(rng, fam, A, rt)
  local body = bakePart(pick(A.quad_body, fam, "quadruped", rng), rt, "base")
  local head = bakePart(pick(A.quad_head, fam, "quadruped", rng), rt, "top")
  local leg = bakePart(pick(A.quad_leg, fam, "quadruped", rng), rt, "top")
  local legLen = #leg.grid
  local parts = { body = body, head = head, legBL = leg, legBR = leg, legFL = leg, legFR = leg }
  local bw, bh = partWH(body.grid)
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

PLAN.cephalopod = function(rng, fam, A, rt)
  local mantle = bakePart(pick(A.mantle, fam, "cephalopod", rng), rt, "base")
  local tent = bakePart(pick(A.tentacle, fam, "cephalopod", rng), rt, "top")
  local mw, mh = partWH(mantle.grid)
  local maxLen = #tent.grid
  local nTent = 4 + rng:random(0, 2)
  local parts, rig = { mantle = mantle }, {}
  local span = math.max(2, mw - 2)
  for i = 1, nTent do
    parts["tentacle" .. i] = tent
    rig[#rig + 1] = { part = "tentacle" .. i, parent = "mantle", at = { 1 + math.floor((i - 0.5) * span / nTent), mh - 1 } }
  end
  table.insert(rig, 1, { part = "mantle", at = { 0, -maxLen + 2 } })
  return parts, rig, {}, CEPH_ANIM
end

PLAN.serpent = function(rng, fam, A, rt)
  local head = bakePart(pick(A.serpent_head, fam, "serpent", rng), rt, "base")
  local seg = bakePart(pick(A.segment, fam, "serpent", rng), rt, "top")
  local segH = #seg.grid
  local nSeg = 5 + rng:random(0, 2)
  local parts = { head = head }
  local rig = { { part = "head", at = { 0, 0 } }, { part = "segment1", parent = "head", at = { 0, -1 } } }
  parts.segment1 = seg
  for i = 2, nSeg do
    parts["segment" .. i] = seg
    rig[#rig + 1] = { part = "segment" .. i, parent = "segment" .. (i - 1), at = { (i % 2 == 0) and 1 or -1, segH - 1 } }
  end
  return parts, rig, {}, SERPENT_ANIM
end

PLAN.arachnid = function(rng, fam, A, rt)
  local body = bakePart(pick(A.arachnid_body, fam, "arachnid", rng), rt, "base")
  local leg = bakePart(pick(A.spider_leg, fam, "arachnid", rng), rt, "top")
  local legLen = #leg.grid
  local bw, bh = partWH(body.grid)
  local nLeg = 6 + rng:random(0, 1) * 2
  local perSide = nLeg / 2
  local parts, rig = { body = body }, {}
  for i = 1, nLeg do
    parts["leg" .. i] = leg
    local side = (i <= perSide) and -1 or 1
    local k = ((i - 1) % perSide) + 1
    local fx = (side < 0) and (1 - (k - 1)) or (bw + (k - 1))
    rig[#rig + 1] = { part = "leg" .. i, parent = "body", at = { fx, math.floor(bh * 0.35) - (k - 1) } }
  end
  table.insert(rig, 1, { part = "body", at = { 0, -legLen + 2 } })
  return parts, rig, {}, ARACHNID_ANIM
end

PLAN.swarm = function(rng, fam, A, rt)
  local core = bakePart(pick(A.swarm_core, fam, "swarm", rng), rt, "base")
  return { core = core }, { { part = "core", at = { 0, 0 } } }, {}, SWARM_ANIM
end

-- chimère "chimera:top:bottom" : top ∈ {humanoid,cephalopod} ; bottom ∈ {quadruped,tentacles}.
local function buildChimera(rng, fam, A, rt, top, bottom)
  local parts = {}
  local coreName, coreW, coreH
  if top == "humanoid" then
    parts.torso = bakePart(pick(A.torso, fam, "humanoid", rng), rt, "base")
    parts.head = bakePart(pick(A.head, fam, "humanoid", rng), rt, "base")
    local arm = bakePart(pick(A.arm, fam, "deformed", rng), rt, "top") -- bras griffu si possible
    parts.armBack, parts.armFront = arm, arm
    coreName = "torso"; coreW, coreH = partWH(parts.torso.grid)
  else
    parts.mantle = bakePart(pick(A.mantle, fam, "cephalopod", rng), rt, "base")
    coreName = "mantle"; coreW, coreH = partWH(parts.mantle.grid)
  end

  local nTent, botLen = 0, 0
  if bottom == "quadruped" then
    local leg = bakePart(pick(A.quad_leg, fam, "quadruped", rng), rt, "top")
    botLen = #leg.grid
    for _, nm in ipairs({ "legBL", "legBR", "legFL", "legFR" }) do parts[nm] = leg end
  else
    local tent = bakePart(pick(A.tentacle, fam, "cephalopod", rng), rt, "top")
    botLen = #tent.grid
    nTent = 4 + rng:random(0, 2)
    for i = 1, nTent do parts["tentacle" .. i] = tent end
  end

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
  local pose = (top == "humanoid") and { armFront = 0, armBack = 0 } or {}
  return parts, rig, pose, CHIMERA_ANIM
end

-- ─────────────────────────── API publique ───────────────────────────
-- opts = { id, type, bodyplan?, seed?, effects?, rank?, outlineRole? }. Déterministe : (id) -> même créature.
function Forge.build(opts)
  local id = opts.id or "anon"
  local fac = Factions.get(opts.type)
  local seed = opts.seed or hashId(id)
  local rng = love.math.newRandomGenerator(seed)
  local bodyplan = opts.bodyplan or fac.skeleton or "humanoid"

  -- ORDRE FIXE : 1) sous-rampe (teinte), puis l'assembleur tire ses parts.
  local ramp = fac.ramps[rng:random(#fac.ramps)]
  local acc = Ramps.accentFor(opts.effects, fac.accent)
  local rt = roleTableFor(fac, ramp, acc, opts.outlineRole)
  local A = atlas()

  local parts, rig, idlePose, animations
  local chimTop, chimBot
  if type(bodyplan) == "string" then chimTop, chimBot = bodyplan:match("^chimera:([^:]+):([^:]+)$") end
  if chimTop then
    parts, rig, idlePose, animations = buildChimera(rng, opts.type, A, rt, chimTop, chimBot)
  elseif PLAN[bodyplan] then
    parts, rig, idlePose, animations = PLAN[bodyplan](rng, opts.type, A, rt)
  else
    parts, rig, idlePose, animations = buildStatic(rng, opts.type, bodyplan, A, rt)
  end

  local rar = Rarity.get(opts.rank or 1)
  return {
    name = id:upper(), parts = parts, rig = rig, idlePose = idlePose, animations = animations,
    bodyplan = bodyplan, rank = opts.rank or 1, scale = rar.scale, glow = rar.glow,
  }
end

-- quels body-plans la Forge sait produire (pour le rollout : déléguer si supporté, legacy sinon).
function Forge.supports(bodyplan)
  if type(bodyplan) == "string" and bodyplan:match("^chimera:") then return true end
  return BIPED_PICKS[bodyplan] ~= nil or PLAN[bodyplan] ~= nil
end

local CACHE = {}
function Forge.cached(opts)
  local key = opts.id or "anon"
  if not CACHE[key] then CACHE[key] = Forge.build(opts) end
  return CACHE[key]
end

return Forge
