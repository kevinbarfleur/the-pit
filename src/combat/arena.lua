-- src/combat/arena.lua
-- MOTEUR de combat auto-résolu — couche SIM PURE : aucun love.graphics, aucun rig, aucun RNG global.
-- Deux équipes face à face ; chaque unité frappe l'ennemi le plus proche à son cooldown (modèle
-- cooldown, pas de timeline temps réel : celui des autobattlers les plus addictifs, le moins coûteux).
--
-- Déterministe : RNG SEEDÉ injecté (opts.rng / opts.seed), jamais le global. La sim ÉMET des
-- événements sur self.bus (spawned/attack/hit/damage/death) que la couche RENDER
-- (src/render/arena_draw.lua) consomme pour l'animation et les transients visuels. La sim ne
-- dessine JAMAIS et n'a aucune dépendance visuelle. cf. docs/research/engine-architecture.md.
--
-- spec d'unité : { id, hp, dmg, cd, [effects], shield?, x, y, facing }
-- Effets via le registre (src/effects). Le « swing » (timer de frappe) est purement logique :
-- la frappe connecte à mi-animation, indépendamment de tout rig.

local Units = require("src.data.units")
local Bus = require("src.core.bus")
local Effects = require("src.effects.engine")
require("src.effects.ops") -- enregistre les ops de base (effet de bord)

local Arena = {}
Arena.__index = Arena

-- Timing de frappe (en "frames") : cohérent avec l'anim "attack" du rig pour la synchro visuelle.
-- La frappe CONNECTE à mi-animation (équivalent de l'ancien `p >= 0.5`).
local SWING_DUR = 35
local CONNECT_AT = 0.5

local ROWS_Y = { 70, 104, 138 }

-- Compo de démonstration (si aucune compo fournie) : reprend les stats de units.lua.
local function demoComp(side)
  local ids = (side == "left") and { "marauder", "templar", "skeleton" }
    or { "demon", "witch", "bandit" }
  local facing = (side == "left") and 1 or -1
  local x = (side == "left") and 130 or 190
  local comp = {}
  for i, id in ipairs(ids) do
    local u = Units[id]
    comp[i] = { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd,
      depth = 0, row = i - 1, shield = 0, x = x, y = ROWS_Y[i], facing = facing }
  end
  return comp
end

function Arena.new(opts)
  opts = opts or {}
  local self = setmetatable({
    t = 0, leftComp = opts.left, rightComp = opts.right,
  }, Arena)
  -- Déterminisme : RNG seedé injecté (de préférence opts.rng ; sinon construit depuis opts.seed).
  self.seed = opts.seed or 0
  self.rng = opts.rng or love.math.newRandomGenerator(self.seed)
  self.bus = opts.bus or Bus.new() -- bus d'événements par combat (render + event-log s'y abonnent)
  self.ctx = {} -- contexte d'effets RÉUTILISÉ (aucune allocation par hook)
  if opts.autoReset ~= nil then
    self.autoReset = opts.autoReset
  else
    self.autoReset = (opts.left == nil) -- la démo se relance, une vraie bataille s'arrête
  end
  self:spawn()
  return self
end

function Arena:makeUnit(spec, team)
  local u = Units[spec.id]
  return {
    spec = spec, team = team, slot = spec.slot, x = spec.x, y = spec.y, facing = spec.facing,
    id = spec.id,
    maxHp = spec.hp, hp = spec.hp, dmg = spec.dmg, cd = spec.cd,
    -- effets : du spec si fourni (build résolu avec reliques, plus tard), sinon la base.
    effects = spec.effects or (u and u.effects),
    -- ciblage déterministe : depth (0 = colonne avant), row (tie-break haut->bas),
    -- aggro (stat, défaut INERTE = 0 ; future stat de tank), taunt (override dur, via reliques).
    depth = spec.depth or 0, row = spec.row or 0,
    aggro = spec.aggro or (u and u.aggro) or 0,
    taunt = spec.taunt or (u and u.taunt) or false,
    shield = spec.shield or 0, maxShield = spec.shield or 0,
    atkTimer = self.rng:random() * spec.cd, -- décalage seedé -> pas de swings synchronisés
    firstHit = true, poison = nil,
    swinging = false, swingAge = 0, swingHit = false,
    alive = true, target = nil,
  }
end

function Arena:spawn()
  self.units = {}
  self.resetTimer = nil
  self.over = false
  self.win = nil
  self.overAge = 0
  for _, spec in ipairs(self.leftComp or demoComp("left")) do
    table.insert(self.units, self:makeUnit(spec, "left"))
  end
  for _, spec in ipairs(self.rightComp or demoComp("right")) do
    table.insert(self.units, self:makeUnit(spec, "right"))
  end
  self.bus:emit("spawned", self.units) -- la couche render (re)construit ses rigs
end

-- Ciblage DÉTERMINISTE (zéro dé -> async-vérifiable, rejouable ; cf.
-- docs/research/combat-model-decision.md). Ordre de résolution :
--   1. colonne AVANT ennemie occupée (depth minimal = front) ; on n'avance qu'une fois vidée
--   2. override TAUNT (parmi les candidats du front)
--   3. AGGRO la plus haute  4. tie-break ordre fixe : row (haut->bas) puis slot
-- depth est DÉRIVÉ de la géométrie du sigil (maxCol - cell.x) -> chaque forme a son profil
-- d'exposition. Tout est une fonction pure de l'état : pas de RNG, mirror-safe.
function Arena:chooseTarget(a)
  local minDepth
  for _, o in ipairs(self.units) do
    if o.alive and o.team ~= a.team and (not minDepth or o.depth < minDepth) then minDepth = o.depth end
  end
  if not minDepth then return nil end

  local anyTaunt = false
  for _, o in ipairs(self.units) do
    if o.alive and o.team ~= a.team and o.depth == minDepth and o.taunt then anyTaunt = true; break end
  end

  local target
  for _, o in ipairs(self.units) do
    if o.alive and o.team ~= a.team and o.depth == minDepth and (not anyTaunt or o.taunt) then
      if not target
        or o.aggro > target.aggro
        or (o.aggro == target.aggro and o.row < target.row)
        or (o.aggro == target.aggro and o.row == target.row and (o.slot or 0) < (target.slot or 0))
      then
        target = o
      end
    end
  end
  return target
end

-- Application centralisée des dégâts : le bouclier absorbe d'abord (sauf ignoreShield), puis les
-- PV. Émet un événement "damage" RICHE (record d'attribution : source/cause/brut/absorbé/débordement)
-- consommé par le render (nombre flottant) ET l'event-log (stats d'équilibrage), puis "death".
-- opts : { ignoreShield?, silent?, poison?, source?, cause? }. Renvoie les PV réellement perdus.
function Arena:damage(target, amount, opts)
  opts = opts or {}
  local raw = math.max(0, amount)
  local absorbed = 0
  amount = raw
  if not opts.ignoreShield and target.shield and target.shield > 0 then
    absorbed = math.min(target.shield, amount)
    target.shield = target.shield - absorbed
    amount = amount - absorbed
  end
  local before = target.hp
  target.hp = before - amount
  local dealt = before - target.hp -- PV réellement perdus (borné à 0)
  local overkill = amount - dealt  -- dégâts au-delà de 0 PV
  local died = false
  if target.hp <= 0 then
    target.hp = 0
    target.alive = false
    died = true
  end
  if raw > 0 and not opts.silent then
    self.bus:emit("damage", {
      target = target, source = opts.source, cause = opts.cause or "attack",
      raw = math.floor(raw + 0.5), absorbed = absorbed, hp = dealt, overkill = overkill,
      poison = opts.poison, hpAfter = target.hp, shieldAfter = target.shield,
    })
  end
  if died then self.bus:emit("death", target) end
  return dealt
end

-- Une frappe passe par les HOOKS du système d'effets. ctx réutilisé : aucune allocation par coup.
function Arena:hit(a, target)
  local ctx = self.ctx
  ctx.arena, ctx.source, ctx.victim = self, a, target
  ctx.amount, ctx.dealt = a.dmg, 0
  Effects.run(a, "on_attack", ctx) -- peut modifier ctx.amount (ex. bonus 1re frappe)

  local dealt = self:damage(target, ctx.amount, { source = a, cause = "attack" })
  ctx.dealt = dealt
  self.bus:emit("hit", a, target) -- le render déclenche l'anim "hurt" + l'impact

  Effects.run(a, "on_hit", ctx) -- ex. vol de vie (soigne a), poison (applique a la victime)

  if target.alive then
    ctx.source, ctx.victim = target, a -- le defenseur reagit
    Effects.run(target, "on_attacked", ctx) -- ex. epines (renvoie a l'attaquant)
  end
end

function Arena:update(frameDt, t)
  self.t = t

  for _, u in ipairs(self.units) do
    if u.alive then
      -- Poison (DoT) : ignore le bouclier.
      if u.poison then
        u.poison.remaining = u.poison.remaining - frameDt
        u.poison.acc = u.poison.acc + u.poison.dps * (frameDt / 60)
        if u.poison.acc >= 1 then
          local n = math.floor(u.poison.acc)
          u.poison.acc = u.poison.acc - n
          self:damage(u, n, { ignoreShield = true, poison = true, cause = "poison", source = u.poison.source })
        end
        if u.poison.remaining <= 0 then u.poison = nil end
      end
    end

    if u.alive then
      if not (u.target and u.target.alive) then u.target = self:chooseTarget(u) end

      -- Le timer s'écoule en continu : le cooldown EST l'intervalle entre deux frappes.
      u.atkTimer = u.atkTimer - frameDt
      if not u.swinging and u.target and u.atkTimer <= 0 then
        u.swinging = true; u.swingAge = 0; u.swingHit = false
        u.atkTimer = u.cd
        u.target = self:chooseTarget(u)
        self.bus:emit("attack", u) -- le render joue l'anim d'attaque
      end

      if u.swinging then
        u.swingAge = u.swingAge + frameDt
        if u.swingAge >= SWING_DUR * CONNECT_AT and not u.swingHit and u.target and u.target.alive then
          self:hit(u, u.target)
          u.swingHit = true
        end
        if u.swingAge >= SWING_DUR then u.swinging = false end
      end
    end
  end

  -- Décompte des vivants par camp.
  local left, right = 0, 0
  for _, u in ipairs(self.units) do
    if u.alive then
      if u.team == "left" then left = left + 1 else right = right + 1 end
    end
  end

  if self.autoReset then
    if (left == 0 or right == 0) and not self.resetTimer then self.resetTimer = 120 end
    if self.resetTimer then
      self.resetTimer = self.resetTimer - frameDt
      if self.resetTimer <= 0 then self:spawn() end
    end
  else
    if (left == 0 or right == 0) and not self.over then
      self.over = true
      self.win = (right == 0 and left > 0) -- "left" = équipe du joueur
    end
    if self.over then self.overAge = self.overAge + frameDt end
  end
end

return Arena
