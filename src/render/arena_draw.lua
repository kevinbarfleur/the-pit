-- src/render/arena_draw.lua
-- Couche RENDER du combat. Possède TOUS les love.graphics.* et les rigs (animation). Lit l'état de
-- la SIM en LECTURE SEULE (arena.units : hp/shield/x/y/alive) et s'abonne aux ÉVÉNEMENTS de l'arène
-- (spawned/attack/hit/damage/death) pour déclencher animations et transients visuels (nombres de
-- dégâts, impacts, traînées de frappe). Ne mute JAMAIS la sim. cf. docs/research/engine-architecture.md §4.

local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen") -- visuel généré pour les unités sans rig main
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local T = require("src.core.i18n").t

local ArenaDraw = {}
ArenaDraw.__index = ArenaDraw

function ArenaDraw.new(arena, palette)
  local self = setmetatable({
    arena = arena, palette = palette,
    rigs = {},       -- [unit] = char (rig)
    dead = {},       -- [unit] = age (fondu de mort, géré côté render)
    dmgNumbers = {}, -- nombres flottants
    impacts = {},    -- étincelles d'impact
  }, ArenaDraw)
  self:rebuild()
  -- Abonnements au bus de l'arène (la sim émet, le render réagit).
  arena.bus:on("spawned", function() self:rebuild() end)
  arena.bus:on("attack", function(u) Rig.trigger(self:rigFor(u), "attack") end)
  arena.bus:on("hit", function(a, target)
    Rig.trigger(self:rigFor(target), "hurt")
    table.insert(self.impacts, { x = target.x - a.facing * 6, y = target.y - 14, age = 0 })
  end)
  arena.bus:on("damage", function(rec)
    -- on n'affiche un nombre que pour les dégâts qui touchent les PV (le pur-absorbé reste discret).
    if rec.hp and rec.hp > 0 then
      table.insert(self.dmgNumbers,
        { x = rec.target.x, y = rec.target.y - 24, val = rec.hp, age = 0, poison = rec.poison })
    end
  end)
  return self
end

function ArenaDraw:rigFor(u)
  local c = self.rigs[u]
  if not c then
    -- Visuel : priorité au rig dessiné MAIN (Creatures[id], les 6 vanille) ; sinon créature GÉNÉRÉE
    -- procéduralement, déterministe (seed = hashId de l'id), mémoïsée par id dans le générateur.
    local def = Creatures[u.id]
    if not def then
      local spec = Units[u.id] or {}
      def = CreatureGen.cached({ id = u.id, type = spec.type, effects = spec.effects })
    end
    c = Rig.new(def, self.palette)
    c.x, c.y, c.facing = u.x, u.y, u.facing
    c.trail = {}
    self.rigs[u] = c
  end
  return c
end

-- (Re)construit les rigs à partir des unités courantes (initial + respawn de la démo).
function ArenaDraw:rebuild()
  self.rigs = {}; self.dead = {}; self.dmgNumbers = {}; self.impacts = {}
  for _, u in ipairs(self.arena.units) do self:rigFor(u) end
end

function ArenaDraw:update(frameDt, t)
  for _, u in ipairs(self.arena.units) do
    local c = self:rigFor(u)
    c.x, c.y, c.facing = u.x, u.y, u.facing
    Rig.update(c, t, frameDt)

    -- Traînée de frappe : pointe de l'arme pendant l'anim "attack".
    if c.state == "attack" and c.parts.weapon then
      local p = c.stateAge / Rig.ATTACK_DUR
      if p >= 0.3 and p <= 0.65 then
        local tx, ty = Rig.weaponTip(c)
        if tx then table.insert(c.trail, { x = tx, y = ty, age = 0 }) end
      end
    end
    for _, pt in ipairs(c.trail) do pt.age = pt.age + frameDt end
    for i = #c.trail, 1, -1 do if c.trail[i].age >= 12 then table.remove(c.trail, i) end end

    -- Fondu de mort (état purement visuel, géré ici).
    if not u.alive then
      local age = (self.dead[u] or 0) + frameDt
      self.dead[u] = age
      c.alpha = math.max(0, 1 - age / 40)
    end
  end

  for i = #self.dmgNumbers, 1, -1 do
    local d = self.dmgNumbers[i]; d.age = d.age + frameDt
    if d.age >= 40 then table.remove(self.dmgNumbers, i) end
  end
  for i = #self.impacts, 1, -1 do
    local im = self.impacts[i]; im.age = im.age + frameDt
    if im.age >= 12 then table.remove(self.impacts, i) end
  end
end

-- ───────────────────────── Rendu monde (canvas virtuel) ─────────────────────────
function ArenaDraw:draw(showBones)
  local units = self.arena.units

  for _, u in ipairs(units) do
    local c = self.rigs[u]
    local a = u.alive and 0.5 or 0.5 * ((c and c.alpha) or 1)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.ellipse("fill", u.x, u.y + 2, 8, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for _, u in ipairs(units) do Rig.draw(self:rigFor(u)) end

  love.graphics.setLineStyle("rough")
  for _, u in ipairs(units) do
    local c = self.rigs[u]
    local trail = c and c.trail
    if trail and #trail >= 2 then
      for i = 1, #trail - 1 do
        local a, b = trail[i], trail[i + 1]
        local life = 1 - a.age / 12
        love.graphics.setColor(1, 0.94, 0.66, life * 0.7)
        love.graphics.setLineWidth(1 + life * 2)
        love.graphics.line(a.x, a.y, b.x, b.y)
      end
    end
  end
  love.graphics.setLineWidth(1)

  for _, im in ipairs(self.impacts) do
    local life = 1 - im.age / 12
    love.graphics.setColor(1, 0.8, 0.5, life)
    love.graphics.circle("line", im.x, im.y, 1 + im.age * 0.6)
    love.graphics.setColor(1, 1, 1, life)
    love.graphics.rectangle("fill", im.x, im.y, 1, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for _, u in ipairs(units) do
    if u.alive then self:drawHpBar(u) end
  end

  if showBones then self:drawBones() end
end

function ArenaDraw:drawHpBar(u)
  local c = Theme.c
  local w = 18
  local x, y = math.floor(u.x - w / 2), u.y - 42
  local frac = u.hp / u.maxHp
  love.graphics.setColor(0.04, 0.02, 0.04, 0.9)
  love.graphics.rectangle("fill", x - 1, y - 1, w + 2, 4)
  love.graphics.setColor(c.bloodDeep[1], c.bloodDeep[2], c.bloodDeep[3], 1)
  love.graphics.rectangle("fill", x, y, w, 2)
  love.graphics.setColor(c.blood[1], c.blood[2], c.blood[3], 1)
  love.graphics.rectangle("fill", x, y, math.floor(w * frac + 0.5), 2)
  if u.shield and u.shield > 0 then
    local sw = math.floor(w * math.min(1, u.shield / u.maxHp) + 0.5)
    love.graphics.setColor(c.shield[1], c.shield[2], c.shield[3], 1)
    love.graphics.rectangle("fill", x, y - 2, sw, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function ArenaDraw:drawBones()
  for _, u in ipairs(self.arena.units) do
    local c = self.rigs[u]
    if c then
      for _, part in pairs(c.parts) do
        local px, py = Rig.partPivot(c, part)
        if part.parent then
          local qx, qy = Rig.partPivot(c, part.parent)
          love.graphics.setColor(0.35, 0.51, 0.58, 0.5)
          love.graphics.line(px, py, qx, qy)
        end
        love.graphics.setColor(0.35, 0.51, 0.58, 1)
        love.graphics.rectangle("fill", px - 1, py - 1, 2, 2)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ───────────────────────── Overlay (espace design, texte net) ─────────────────────────
-- Gère sa PROPRE transform (appelée entre deux blocs Draw de la scène combat). Coords sim (u.x,u.y)
-- en virtuel -> ×4 design.
function ArenaDraw:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  local nameFont = Theme.ui(9)
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      Draw.textC((Units[u.id] and T("unit." .. u.id .. ".name")) or u.id, u.x * 4, (u.y + 8) * 4, c.faint, nameFont)
    end
  end

  local numFont = Theme.uiBold(16)
  for _, d in ipairs(self.dmgNumbers) do
    local life = 1 - d.age / 40
    local col = d.poison and c.heal or c.dmg -- DoT (poison) vert ; frappe directe rouge
    Draw.textC("-" .. d.val, d.x * 4, (d.y - d.age * 0.3) * 4, { col[1], col[2], col[3], life }, numFont)
  end

  Draw.finish()
end

return ArenaDraw
