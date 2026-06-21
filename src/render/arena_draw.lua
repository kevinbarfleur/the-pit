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
local HealthBar = require("src.render.healthbar")
local AfflictionFx = require("src.render.affliction_fx") -- feedback visuel des afflictions (particules + contour bouclier)
local T = require("src.core.i18n").t

-- Nombres de dégâts flottants : trajectoire « feu d'artifice » (éjection vers le haut + dérive latérale +
-- gravité) et REGROUPEMENT des tics par (cible, auteur, cause) -> ils s'additionnent au lieu de s'empiler.
local DMG_LIFE = 55    -- durée de vie (frames)
local DMG_MERGE = 20   -- fenêtre de regroupement (frames) : un tic récent de même cible/auteur/cause s'ajoute
local DMG_VY0 = -1.35  -- vitesse verticale initiale (négatif = vers le haut)
local DMG_G = 0.05     -- gravité (le nombre retombe -> arc)

local ArenaDraw = {}
ArenaDraw.__index = ArenaDraw

function ArenaDraw.new(arena, palette)
  local self = setmetatable({
    arena = arena, palette = palette,
    rigs = {},       -- [unit] = char (rig)
    dead = {},       -- [unit] = age (fondu de mort, géré côté render)
    dmgNumbers = {}, -- nombres flottants
    impacts = {},    -- étincelles d'impact
    t = 0,           -- horloge de combat (mémorisée en update -> lue en draw pour les anims VFX)
  }, ArenaDraw)
  self.fx = AfflictionFx.new() -- couche d'afflictions (créée avant rebuild, qui peut la reset)
  self:rebuild()
  -- Abonnements au bus de l'arène (la sim émet, le render réagit).
  arena.bus:on("spawned", function() self:rebuild() end)
  arena.bus:on("attack", function(u) Rig.trigger(self:rigFor(u), "attack") end)
  arena.bus:on("hit", function(a, target)
    Rig.trigger(self:rigFor(target), "hurt")
    table.insert(self.impacts, { x = target.x - a.facing * 6, y = target.y - 14, age = 0 })
  end)
  arena.bus:on("damage", function(rec)
    -- CHOC : la décharge du condensateur (cause="shock") déclenche les étincelles « Super Saiyan » sur la cible.
    if rec.cause == "shock" and rec.target then self.fx:shockSpark(rec.target) end
    -- on n'affiche un nombre que pour les dégâts qui touchent les PV (le pur-absorbé reste discret).
    local n = rec.hp
    if not (n and n > 0) then return end
    local tgt, src, cause = rec.target, rec.source, rec.cause or "attack"
    -- REGROUPEMENT : additionne dans un nombre RÉCENT de même (cible, auteur, cause) plutôt que d'empiler
    -- un nouveau « 1 » par tic. Résout le flot de petits nombres des DoT (chaque stack tick séparément).
    for i = #self.dmgNumbers, 1, -1 do
      local d = self.dmgNumbers[i]
      if d.cause == cause and d.target == tgt and d.source == src and d.age < DMG_MERGE then
        d.val = d.val + n
        return
      end
    end
    -- Nouveau nombre : éjecté du haut de la cible avec une trajectoire en arc. Spread latéral DÉTERMINISTE
    -- (suite de Weyl via le nombre d'or) -> pas de RNG, mais une dispersion organique gauche/droite.
    self.fxN = (self.fxN or 0) + 1
    local vx = (((self.fxN * 0.6180339887) % 1) - 0.5) * 0.9 -- dérive ~[-0.45, 0.45] px/frame
    table.insert(self.dmgNumbers, {
      target = tgt, source = src, cause = cause, val = n,
      x = tgt.x, y = tgt.y - 26, vx = vx, vy = DMG_VY0, age = 0,
    })
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
      def = CreatureGen.cached({ id = u.id, type = spec.type, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
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
  if self.fx then self.fx:reset() end
  for _, u in ipairs(self.arena.units) do self:rigFor(u) end
end

function ArenaDraw:update(frameDt, t)
  self.t = t
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
    local d = self.dmgNumbers[i]
    d.age = d.age + frameDt
    d.x = d.x + (d.vx or 0) * frameDt              -- dérive latérale
    d.vy = (d.vy or 0) + DMG_G * frameDt           -- gravité
    d.y = d.y + d.vy * frameDt                     -- arc (monte puis retombe)
    if d.age >= DMG_LIFE then table.remove(self.dmgNumbers, i) end
  end
  for i = #self.impacts, 1, -1 do
    local im = self.impacts[i]; im.age = im.age + frameDt
    if im.age >= 12 then table.remove(self.impacts, i) end
  end

  self.fx:update(self.arena.units, frameDt, t) -- émission + intégration des particules d'affliction
end

-- GRILLE de combat : un SLOT sous chaque unité vivante, teinté par équipe (bleu = gauche/joueur, rouge =
-- droite/adverse) -> le placement de chaque grille reste lisible en permanence (et l'adversaire voit la
-- forme qu'il affronte). Reconstruit depuis la position de l'unité (zéro dépendance au plateau/sigil) : on
-- n'affiche que les cases OCCUPÉES — les cases VIDES du sigil demanderaient de router la shape jusqu'ici.
function ArenaDraw:drawGrid()
  local C = Theme.c
  local W, H = 28, 30 -- ~ pas de la grille (Place CELL=30) -> les cases se jointoient en grille lisible
  love.graphics.setLineStyle("rough")
  love.graphics.setLineWidth(1)
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      local col = (u.team == "left") and C.shield or C.blood
      local x = math.floor(u.x - W / 2)
      local y = math.floor(u.y + 2 - H) -- la case ENCADRE le monstre (tête en haut, pieds en bas)
      love.graphics.setColor(col[1], col[2], col[3], 0.08)
      love.graphics.rectangle("fill", x, y, W, H)
      love.graphics.setColor(col[1], col[2], col[3], 0.42)
      love.graphics.rectangle("line", x, y, W, H)
      love.graphics.setColor(col[1], col[2], col[3], 0.85) -- accents de coin (lecture « slot »)
      love.graphics.rectangle("fill", x, y, 1, 1); love.graphics.rectangle("fill", x + W - 1, y, 1, 1)
      love.graphics.rectangle("fill", x, y + H - 1, 1, 1); love.graphics.rectangle("fill", x + W - 1, y + H - 1, 1, 1)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ───────────────────────── Rendu monde (canvas virtuel) ─────────────────────────
function ArenaDraw:draw(showBones)
  local units = self.arena.units

  self:drawGrid() -- repères de slots (derrière ombres + unités)

  for _, u in ipairs(units) do
    local c = self.rigs[u]
    local a = u.alive and 0.5 or 0.5 * ((c and c.alpha) or 1)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.ellipse("fill", u.x, u.y + 2, 8, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for _, u in ipairs(units) do Rig.draw(self:rigFor(u)) end

  -- Afflictions : matière (sang/spores/bulles/mouches) sur les rigs, puis glow additif (flammes/chaleur).
  self.fx:drawBody(units, self.t)
  self.fx:drawGlow(units, self.t)

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

  -- Contour de bouclier (shader) : en dernier, sur la silhouette complète (lit self.rigs aplatis en canvas).
  self.fx:drawOutlines(units, self.rigs, self.t)

  if showBones then self:drawBones() end
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

  -- Nom de l'unité : juste AU-DESSUS de l'encadré de vie (et non plus sous l'unité).
  local nameFont = Theme.ui(9)
  local nameH = nameFont and nameFont:getHeight() or 9
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      local ny = (u.y + (HealthBar.BAR_DY or -34)) * 4 - nameH - 1
      Draw.textC((Units[u.id] and T("unit." .. u.id .. ".name")) or u.id, u.x * 4, ny, c.faint, nameFont)
    end
  end

  -- Barres de vie (encadré runique + segments + icônes) en espace design, grille fine ×2 -> finition d'UI.
  -- Dessinées AVANT les nombres flottants pour que ces derniers restent au-dessus.
  for _, u in ipairs(self.arena.units) do
    if u.alive then HealthBar.draw(u, 2) end
  end

  -- Nombres flottants : couleur par CAUSE + ICÔNE d'affliction à gauche (poison/saignement/brûlure/
  -- pourriture) -> on lit l'effet d'un coup d'œil. Frappe directe = rouge, sans icône. Fondu en fin de vie.
  local CAUSE_COL = { burn = c.burn, bleed = c.bleed, poison = c.poison, rot = c.rot, shock = c.shock }
  local numFont = Theme.uiBold(16)
  local numH = numFont and numFont:getHeight() or 16
  for _, d in ipairs(self.dmgNumbers) do
    local p = d.age / DMG_LIFE
    local alpha = (p < 0.6) and 1 or math.max(0, 1 - (p - 0.6) / 0.4)
    local col = CAUSE_COL[d.cause] or c.dmg
    local str = "-" .. d.val
    local cx, cy = d.x * 4, d.y * 4
    local ic = (d.cause ~= "attack") and HealthBar.icon(d.cause) or nil
    local iconW = ic and ic.w or 0
    local gap = ic and 2 or 0
    local leftX = cx - (iconW + gap + (numFont and numFont:getWidth(str) or #str * 6)) / 2
    if ic then
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(ic.image, math.floor(leftX), math.floor(cy + (numH - ic.h) / 2))
      love.graphics.setColor(1, 1, 1, 1)
    end
    Draw.text(str, leftX + iconW + gap, cy, { col[1], col[2], col[3], alpha }, numFont)
  end

  Draw.finish()
end

return ArenaDraw
