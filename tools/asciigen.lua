-- tools/asciigen.lua
-- OUTIL DE DEBUG (hors jeu) : composite les parts du rig généré en une SILHOUETTE ASCII unique,
-- au repos (rot=0), pour juger la diversité/lisibilité des créatures SANS lancer LÖVE.
--   Lancement : luajit tools/asciigen.lua [id1 id2 ...]   (sans args = échantillon par faction)
--
-- Maths du composite = reprise EXACTE du rig (sans rotation) :
--   topleft(part) = (0,0) + Σ_{p in chain} (at_p - pivot_p)
-- (cf. src/core/rig.lua : translate(at) puis translate(-pivot) ; enfants hérités).
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local CreatureGen = require("src.gen.creaturegen")
local Units = require("src.data.units")

-- Reconstruit la chaîne d'ancêtres (racine -> part) à partir du rig (liste {part,parent,at}).
local function buildChains(def)
  local nodeOf, parentOf = {}, {}
  for _, n in ipairs(def.rig) do nodeOf[n.part] = n; parentOf[n.part] = n.parent end
  local chains = {}
  for _, n in ipairs(def.rig) do
    local chain, cur = {}, n.part
    while cur do table.insert(chain, 1, cur); cur = parentOf[cur] end
    chains[n.part] = chain
  end
  return chains, nodeOf
end

-- Stamp toutes les parts dans une grille ASCII (chars de palette bruts ; '.' = vide).
local function composite(def)
  local chains, nodeOf = buildChains(def)
  -- 1) topleft absolu de chaque part.
  local placed = {}
  for partName, chain in pairs(chains) do
    local ox, oy = 0, 0
    for _, pn in ipairs(chain) do
      local node = nodeOf[pn]
      local spec = def.parts[pn]
      if spec then
        ox = ox + node.at[1] - spec.pivot.x
        oy = oy + node.at[2] - spec.pivot.y
      end
    end
    placed[partName] = { x = ox, y = oy, grid = def.parts[partName].grid }
  end
  -- 2) bbox globale.
  local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
  for _, p in pairs(placed) do
    local h = #p.grid
    local w = 0
    for _, row in ipairs(p.grid) do if #row > w then w = #row end end
    minX = math.min(minX, p.x); minY = math.min(minY, p.y)
    maxX = math.max(maxX, p.x + w); maxY = math.max(maxY, p.y + h)
  end
  local W, H = maxX - minX, maxY - minY
  -- 3) canvas + ordre de dessin = ordre du rig (z-order).
  local canvas = {}
  for y = 1, H do canvas[y] = {}; for x = 1, W do canvas[y][x] = "." end end
  for _, node in ipairs(def.rig) do
    local p = placed[node.part]
    if p then
      for gy = 1, #p.grid do
        local row = p.grid[gy]
        for gx = 1, #row do
          local ch = row:sub(gx, gx)
          if ch ~= " " then
            local cx = p.x - minX + gx
            local cy = p.y - minY + gy
            if cx >= 1 and cx <= W and cy >= 1 and cy <= H then canvas[cy][cx] = ch end
          end
        end
      end
    end
  end
  return canvas, W, H
end

local function printCreature(id, type_, bodyplan, rank)
  local spec = Units[id] or {}
  local def = CreatureGen.build({ id = id, type = type_ or spec.type, effects = spec.effects, bodyplan = bodyplan, rank = rank })
  local canvas, W, H = composite(def)
  print(string.format("─── %s  [%s/%s R%d]  (%dx%d, scale %.2f)", id, type_ or spec.type or "?",
    bodyplan or def.bodyplan or "?", def.rank or 1, W, H, def.scale or 1))
  for y = 1, H do print("  " .. table.concat(canvas[y])) end
  print("")
end

-- ── Sélection ──
-- args : "id" | "id=type=bodyplan" | "id=type=bodyplan=rank" (ex. "x=arcane=cephalopod=5").
local args = { ... }
if #args > 0 then
  for _, a in ipairs(args) do
    local id, ty, bp, rk = a:match("^([^=]+)=([^=]+)=([^=]+)=([^=]+)$")
    if not id then id, ty, bp = a:match("^([^=]+)=([^=]+)=([^=]+)$") end
    if id then printCreature(id, ty, bp, tonumber(rk)) else printCreature(a) end
  end
elseif os.getenv("PLANS") then
  -- VITRINE des nouveaux body-plans (le trio) à travers les familles.
  local demos = {
    { "blob_a", "abyss", "blob" }, { "blob_b", "bone", "blob" }, { "blob_c", "arcane", "blob" },
    { "quad_a", "flesh", "quadruped" }, { "quad_b", "bone", "quadruped" }, { "quad_c", "abyss", "quadruped" },
    { "ceph_a", "arcane", "cephalopod" }, { "ceph_b", "abyss", "cephalopod" }, { "ceph_c", "order", "cephalopod" },
  }
  for _, d in ipairs(demos) do printCreature(d[1], d[2], d[3]) end
else
  -- échantillon : 3 ids inventés par faction -> montre la (faible) variété intra-faction.
  local sample = {
    flesh = { "flesh_a", "flesh_b", "flesh_c" },
    order = { "order_a", "order_b", "order_c" },
    bone = { "bone_a", "bone_b", "bone_c" },
    arcane = { "arcane_a", "arcane_b", "arcane_c" },
    abyss = { "abyss_a", "abyss_b", "abyss_c" },
  }
  for _, fac in ipairs({ "flesh", "order", "bone", "arcane", "abyss" }) do
    for _, id in ipairs(sample[fac]) do printCreature(id, fac) end
  end
end
