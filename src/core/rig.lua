-- src/core/rig.lua
-- Moteur de rigging porté de PixiJS vers la matrix stack de LÖVE.
-- Une "part" = un Container Pixi : position relative au parent, pivot, rotation, scale.
--
-- LÖVE n'a PAS de scene graph. La pile de transformations EST le scene graph :
--   push -> translate(pos) -> rotate -> scale -> translate(-pivot) -> draw -> [enfants] -> pop
-- Les enfants héritent de la transformation du parent parce qu'ils sont dessinés
-- tant que la transformation du parent est encore sur la pile.
--
-- L'horloge des anims est en "frames" (≈ deltaTime PixiJS @60fps) pour réutiliser
-- tels quels les magic numbers de la version JS de référence.

local Sprite = require("src.core.sprite")

local Rig = {}
Rig.ATTACK_DUR = 35
Rig.HURT_DUR = 30

-- ───────────────────────── Animations par défaut ─────────────────────────
-- Signature (char, t, progress) -> { rootDx, rootDy, tint?, alpha? }.
-- Les transformations PER-PART sont écrites directement sur char.parts[name].
-- L'orientation (gauche/droite) est gérée par un miroir au niveau du root (cf. Rig.draw),
-- donc les anims travaillent toujours "vers l'avant" (+x local).

local function defaultIdle(char, t)
  local p = char.parts
  local pose = char.def.idlePose or {}
  local ph = char.idlePhase
  local breathe = math.sin(t * 0.04 + ph) * 0.025
  if p.torso then p.torso.sy = 1 + breathe end
  if p.head then p.head.rot = math.sin(t * 0.04 + ph + 0.7) * 0.025 end
  if p.armFront then
    p.armFront.rot = (pose.armFront or 0) + math.sin(t * 0.04 + ph + 0.5) * 0.03
  end
  if p.armBack then
    p.armBack.rot = (pose.armBack or 0) + math.sin(t * 0.04 + ph + 1.5) * 0.03
  end
  if p.weapon then p.weapon.rot = pose.weapon or 0 end
  if p.tail then p.tail.rot = math.sin(t * 0.05 + ph) * 0.15 end
  return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 1.5 }
end

local function defaultAttack(char, t, prog)
  local pr = char.parts
  local pose = char.def.idlePose or {}
  local armBase = pose.armFront or 0
  local weaponBase = pose.weapon or 0
  local armRot, weaponRot, torsoRot, headRot, rootDx = 0, 0, 0, 0, 0
  if prog < 0.35 then
    -- Windup : le bras lève, le poignet tend l'arme dans l'axe du bras.
    local q = prog / 0.35; local e = q * q
    armRot = armBase + e * (-3.0 - armBase)
    weaponRot = weaponBase + e * (0 - weaponBase)
    torsoRot = -e * 0.10; headRot = -e * 0.05
  elseif prog < 0.55 then
    -- Strike : descente brutale, arme alignée au bras.
    local q = (prog - 0.35) / 0.20; local e = q * (2 - q)
    armRot = -3.0 + e * 2.6; weaponRot = 0
    torsoRot = -0.10 + e * 0.30; headRot = -0.05 + e * 0.20; rootDx = e * 6
  else
    -- Recovery : retour à la garde.
    local q = (prog - 0.55) / 0.45
    armRot = -0.4 + q * (armBase + 0.4); weaponRot = q * weaponBase
    torsoRot = 0.20 - q * 0.20; headRot = 0.15 - q * 0.15; rootDx = 6 - q * 6
  end
  if pr.armFront then pr.armFront.rot = armRot end
  if pr.weapon then pr.weapon.rot = weaponRot end
  if pr.torso then pr.torso.rot = torsoRot; pr.torso.sy = 1 + math.sin(t * 0.08) * 0.01 end
  if pr.head then pr.head.rot = headRot end
  return { rootDx = rootDx, rootDy = 0 }
end

local function defaultHurt(char, t, prog)
  local pr = char.parts
  local k = 1 - prog
  if pr.head then pr.head.rot = 0.5 * k * math.cos(prog * math.pi * 2) end
  if pr.torso then pr.torso.rot = -0.25 * k * math.cos(prog * math.pi) end
  if pr.armFront then pr.armFront.rot = 0.4 * k * math.sin(prog * math.pi * 4) end
  if pr.armBack then pr.armBack.rot = 0.3 * k * math.sin(prog * math.pi * 4 + 1) end
  local rootDx = -8 * k * k + math.sin(prog * math.pi * 9) * 1.5 * k
  local rootDy = -3 * k * math.sin(prog * math.pi)
  local g = 1 - k * (0xaa / 0xff) -- flash vers le rouge
  return { rootDx = rootDx, rootDy = rootDy, tint = { 1, g, g } }
end

local DEFAULT = { idle = defaultIdle, attack = defaultAttack, hurt = defaultHurt }
Rig.defaultIdle = defaultIdle -- exposé pour les anims custom (squelette, sorcière...)

-- ───────────────────────── Construction ─────────────────────────
function Rig.new(def, palette)
  local char = {
    def = def, parts = {}, root = { children = {} },
    state = "idle", stateAge = 0,
    idlePhase = love.math.random() * math.pi * 2,
    x = 0, y = 0, facing = 1, alpha = 1,
    scale = def.scale or 1, -- échelle globale du sprite (rareté : rangs hauts plus imposants)
    anim = { rootDx = 0, rootDy = 0 },
  }

  for name, spec in pairs(def.parts) do
    local baked = Sprite.bake(spec.grid, palette)
    char.parts[name] = {
      name = name, tex = baked.image, w = baked.w, h = baked.h,
      ox = spec.pivot.x, oy = spec.pivot.y,
      x = 0, y = 0, rot = 0, sx = 1, sy = 1,
      children = {}, parent = nil,
    }
  end

  -- Monte la hiérarchie + positions. L'ORDRE de def.rig = ordre de dessin (z-order).
  for _, node in ipairs(def.rig) do
    local part = char.parts[node.part]
    part.x, part.y = node.at[1], node.at[2]
    if node.parent then
      part.parent = char.parts[node.parent]
      table.insert(part.parent.children, part)
    else
      table.insert(char.root.children, part)
    end
  end

  -- Chaîne d'ancêtres (racine -> part) pour calculer une transform monde (trails, os).
  for _, part in pairs(char.parts) do
    local chain, p = {}, part
    while p do table.insert(chain, 1, p); p = p.parent end
    part.chain = chain
  end

  return char
end

function Rig.trigger(char, state)
  char.state = state
  char.stateAge = 0
end

-- ───────────────────────── Update ─────────────────────────
function Rig.update(char, t, frameDt)
  if char.state ~= "idle" then
    char.stateAge = char.stateAge + frameDt
    local dur = (char.state == "attack") and Rig.ATTACK_DUR or Rig.HURT_DUR
    if char.stateAge >= dur then char.state = "idle"; char.stateAge = 0 end
  end

  -- Reset des transformations per-part (positions conservées, fixées au build).
  for _, p in pairs(char.parts) do p.rot = 0; p.sx = 1; p.sy = 1 end

  local prog = 0
  if char.state ~= "idle" then
    local dur = (char.state == "attack") and Rig.ATTACK_DUR or Rig.HURT_DUR
    prog = math.min(1, char.stateAge / dur)
  end

  local custom = char.def.animations and char.def.animations[char.state]
  local fn = custom or DEFAULT[char.state]
  char.anim = fn(char, t, prog) or { rootDx = 0, rootDy = 0 }
end

-- ───────────────────────── Draw ─────────────────────────
local function drawPart(part)
  love.graphics.push()
  love.graphics.translate(part.x, part.y)        -- pivot placé ici (espace local du parent)
  love.graphics.rotate(part.rot)
  love.graphics.scale(part.sx, part.sy)
  love.graphics.translate(-part.ox, -part.oy)    -- origine = coin haut-gauche de la grille
  love.graphics.draw(part.tex, 0, 0)
  for _, c in ipairs(part.children) do drawPart(c) end
  love.graphics.pop()
end

function Rig.draw(char)
  local a = char.anim or {}
  local facing = char.facing or 1
  local rx = math.floor(char.x + (a.rootDx or 0) * facing + 0.5)
  local ry = math.floor(char.y + (a.rootDy or 0) + 0.5)
  local tint = a.tint or { 1, 1, 1 }
  local alpha = (a.alpha or 1) * (char.alpha or 1)

  local s = char.scale or 1
  love.graphics.push()
  love.graphics.translate(rx, ry)
  love.graphics.scale(facing * s, s)             -- miroir horizontal (équipe droite) + échelle de rareté
  love.graphics.setColor(tint[1], tint[2], tint[3], alpha)
  for _, part in ipairs(char.root.children) do drawPart(part) end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop()
end

-- ───────────────────────── Transforms monde (trails / os) ─────────────────────────
-- Reconstruit la transformation accumulée d'une part en composant un love.math.Transform
-- par maillon de sa chaîne (équivalent exact des push/translate/rotate/scale empilés).
local function worldTransform(char, part)
  local facing = char.facing or 1
  local s = char.scale or 1
  local a = char.anim or {}
  local tf = love.math.newTransform(
    char.x + (a.rootDx or 0) * facing, char.y + (a.rootDy or 0), 0, facing * s, s, 0, 0)
  for _, pp in ipairs(part.chain) do
    tf:apply(love.math.newTransform(pp.x, pp.y, pp.rot, pp.sx, pp.sy, pp.ox, pp.oy))
  end
  return tf
end

-- Pointe de l'arme en coordonnées virtuelles (pour la traînée de frappe).
function Rig.weaponTip(char)
  local w = char.parts.weapon
  if not w then return nil end
  return worldTransform(char, w):transformPoint(w.ox, w.h - 1)
end

-- Position monde du pivot d'une part (overlay debug "os").
function Rig.partPivot(char, part)
  return worldTransform(char, part):transformPoint(part.ox, part.oy)
end

return Rig
