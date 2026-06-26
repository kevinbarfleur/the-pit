-- feel-lab/rooms/attackvfx.lua
-- ╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  VFX D'ATTAQUE — MODÈLE « CAST + IMPACT DIRECTIONNEL » (zéro projectile/trait qui traverse).        ║
-- ║  game-feel pose le mouvement/impact/timing ; pixel-art fournit les SPRITES (consommés défensivement).║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝
--
-- DA : SEMI-PIXEL ART, NET, glow SHADER. RÈGLE ABSOLUE : AUCUN disque/halo/plaque de fond « pour mettre en
-- valeur » (banni). Le glow appartient au SPRITE/à la FORME elle-même (cœur additif qui bloom via le postfx du
-- lab), jamais un disque décoratif derrière. RENDU PRODUIT — pas de ligne de debug : le fallback (sprites pas
-- encore là) est lui-même PROPRE (FORMES PLEINES nettes orientées + particules pixel, zéro trait de trajectoire).
--
-- ── NOUVEAU MODÈLE (retour user : « plus de traits/projectiles qui traversent, ça nuit à la lisibilité ») ──
--   L'instance « émetteur -> receveur » se lit par DEUX tells, JAMAIS par un sprite volant :
--     (a) CAST CUE chez l'ÉMETTEUR : un petit éclat de départ coloré par le type, orienté vers la cible
--         (l'anim de lunge du rig est déjà jouée par combat_lab via Critter ; ici on ajoute l'accent VFX).
--     (b) IMPACT DIRECTIONNEL sur la CIBLE à connectAt : l'effet élémentaire ÉCLOT SUR la cible, biaisé vers
--         le côté FACE à l'émetteur, avec une bourrade/recoil dans la direction du coup. C'est LA STAR.
--   L'ESPACE ENTRE LES DEUX RESTE PROPRE : zéro trait/streak/projectile. La direction se lit par le biais de
--   l'impact (origine décalée côté émetteur + gerbe qui part À L'OPPOSÉ de l'émetteur = recoil).
--
-- ── IDENTITÉ DE L'IMPACT PAR TYPE ──────────────────────────────────────────────────────────────────────
--   attack (PHYSIQUE = 1re classe) : CROISSANT de taille (arc qui grandit) face à l'émetteur + éclats ACIER+SANG.
--   burn  : bloom de flamme (braises en éventail vers le haut + anneau chaud).
--   shock : ÉTOILE/éclair d'étincelles qui FRAPPE sur la cible (zigzag court POSÉ sur la cible) + flash.
--   poison/bleed/rot : SPLAT de famille (gerbe directionnelle de la couleur + gouttes).
--
-- ── CONTRAT (signatures stables) ───────────────────────────────────────────────────────────────────────
--   AV.new("A") · layer:emit{ fromX,fromY, toX,toY, cause, connectAt, val } · layer:update(dt[frames]) ·
--   layer:draw(view) · layer:setVariant(name) · AV.VARIANTS · layer:clear()
--   coords MONDE virtuel 320×180 ; ×4 -> DESIGN au draw ; connectAt en SECONDES ; age en FRAMES.
--
-- ── SPRITES (lib/attacksprites.lua — pixel-art EN PARALLÈLE ; chargé DÉFENSIVEMENT, fallback PROPRE si nil) ──
--   AS.load() · AS.cast(cause) [éclat de DÉPART à l'émetteur] · AS.impact(cause) [LA STAR : burst directionnel] ·
--   AS.bolt(cause) [frappe instantanée posée SUR la cible : foudre zigzag / taille physique] ·
--   AS.proj(cause) [DÉ-PRIORISÉ, peut être nil] · AS.tint(cause). Tout nil -> fallback particules/formes pleines.

local Draw  = require("lib.draw")
local Theme = require("lib.theme")
local Juice = require("lib.juice")
local P     = require("lib.particles")
local c = Theme.c

-- SPRITES pixel-art : chargés DÉFENSIVEMENT (le module peut ne pas exister encore -> fallback propre).
local AS = nil
do
  local ok, mod = pcall(require, "lib.attacksprites")
  if ok and mod then AS = mod end
end
local function asLoad() if AS and AS.load then pcall(AS.load) end end
local function asGet(fn, cause)
  if not AS or not AS[fn] then return nil end
  local ok, res = pcall(AS[fn], cause)
  if ok then return res end
  return nil
end

local AV = {}

-- DEUX variantes POLIES, toutes deux SANS streak (l'ancien « Tout projectile » qui traverse est abandonné).
AV.VARIANTS = {
  { id = "A", name = "Impact sobre" },
  { id = "B", name = "Impact + cast" },
}

-- Teinte par cause (palette d'afflictions ; attack = sang-acier « coup franc »).
local CAUSE_COL = {
  attack = c.bloodL, burn = c.burn, bleed = c.bleed, poison = c.poison,
  rot = c.rot, shock = c.shock,
}
local function colOf(cause) return CAUSE_COL[cause] or c.bloodL end
local function tintOf(cause) return asGet("tint", cause) or colOf(cause) end

-- ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- HELPERS communs
-- ─────────────────────────────────────────────────────────────────────────────────────────────────────
local PXSNAP = 4
local function snap(v) return math.floor(v / PXSNAP + 0.5) * PXSNAP end
local function easeOut(e) return 1 - (1 - e) * (1 - e) end

-- Constantes de timing PARTAGÉES (déclarées AVANT les closures de draw = upvalues visibles).
local CAST_LEAD  = 0.10   -- s : le cast cue précède l'impact (anticipation à l'émetteur)
local CAST_DUR   = 14     -- frames de vie du cast cue
local IMPACT_DUR = 18     -- frames de vie de l'impact
local LIFE_PAD   = 8      -- marge avant retrait

-- dessine un sprite-set baké à (x,y) DESIGN, orienté rot, teinté, additif (semi-pixel net via filtre nearest).
local function drawSprite(set, frameIdx, x, y, rot, col, alpha, additive, scale)
  if not set then return false end
  local frames = set.frames or set        -- attacksprites renvoie une LISTE NUE de frames ; tolère aussi {frames=…}
  local nf = #frames
  if nf == 0 then return false end
  local spr = frames[math.max(1, math.min(nf, frameIdx))]
  if not (spr and spr.image) then return false end
  if additive then love.graphics.setBlendMode("add") end
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  local s = (scale or 1) * PXSNAP
  love.graphics.draw(spr.image, snap(x), snap(y), rot, s, s, spr.w / 2, spr.h / 2)
  if additive then love.graphics.setBlendMode("alpha") end
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

-- ═══════════════════ ANTI-SHAKE (retour user : screen-shake CATASTROPHIQUE en 4v4) ═══════════════════
-- AVANT : Juice.addTrauma(0.05 + val*0.010) PAR COUP -> empilement chaotique sur frappes simultanées.
-- APRÈS : ZÉRO shake sur les frappes normales. Une TOUTE PETITE secousse réservée aux GROS CRITS, CAPPÉE DUR
-- (le trauma ne dépasse jamais TRAUMA_CAP même sur une volée). Le « punch » d'impact reste 100% LOCAL :
-- squash du rig cible (canal Juice par cible) + micro-hitstop TRÈS léger sur crit seulement. Écran STABLE.
local TRAUMA_CAP  = 0.16   -- plafond DUR du trauma total (≈ un frémissement, jamais l'« explosion d'écran »)
local CRIT_TRAUMA = 0.10   -- secousse d'un crit (one-shot) — sinon ZÉRO
local function impactJuice(x, y, cause, val, crit, fromX, fromY)
  val = val or 8
  -- SQUASH LOCAL de la cible (lu par combat_lab si branché ; sinon inerte) — canal stable par position cible.
  local id = "av_hit_" .. math.floor(x / 8) .. "_" .. math.floor(y / 8)
  Juice.juice_up(id, math.min(0.26, 0.10 + val * 0.010))
  -- SHAKE : RIEN sur un coup normal. Gros crit seulement -> un frémissement, et le total est CAPPÉ DUR.
  if crit then
    if Juice.trauma() < TRAUMA_CAP then
      Juice.addTrauma(math.min(CRIT_TRAUMA, TRAUMA_CAP - Juice.trauma()))
    end
    Juice.freeze(0.03) -- micro-hitstop TRÈS léger, crit uniquement
  end
end

-- direction unitaire émetteur->cible (pour orienter cast + biaiser l'impact). Repli (1,0) si dégénéré.
local function dirOf(it)
  local dx, dy = (it.toX - it.fromX), (it.toY - it.fromY)
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then return 1, 0 end
  return dx / len, dy / len
end

-- ═══════════════════ CAST CUE (à l'ÉMETTEUR, orienté vers la cible) — éclat de DÉPART, PAS un voyageur ═══
-- Un petit pli de lumière du type, décalé d'un cran du torse vers la cible, qui pop puis s'éteint sur place.
-- (variant B : + quelques particules LANCÉES vers la cible qui meurent en ~6px — accentue le « lancer ».)
local function emitCastParticles(it, big)
  local dx, dy = dirOf(it)
  local cx, cy = (it.fromX + dx * 5) * 4, (it.fromY + dy * 5) * 4
  local tint = tintOf(it.cause)
  P.burst(cx, cy, { type = "mote", count = big and 5 or 3, dir = math.atan2(dy, dx),
    spread = math.pi * 0.5, speed = { 30, big and 90 or 60 }, life = { 0.10, 0.20 }, drag = 5, tint = tint })
  if big then
    -- « lancer » : 2-3 étincelles brèves vers la cible, vie courte -> ne traversent JAMAIS l'espace.
    P.burst(cx, cy, { type = "spark", count = 3, dir = math.atan2(dy, dx),
      spread = math.pi * 0.25, speed = { 70, 130 }, life = { 0.08, 0.16 }, drag = 6, tint = tint })
  end
end

local function drawCastCue(it, k, big)
  -- k : 1 (pop) -> 0 (éteint). Le cast = un ÉCLAT DIRECTIONNEL chez l'émetteur : une POINTE DE FLÈCHE pleine,
  -- nette, qui DÉSIGNE la cible (direction d'attaque évidente). 100% PLAT, ZÉRO disque/halo de fond ; le glow
  -- vient du blending additif de la forme elle-même (bloomée par le postfx).
  local dx, dy = dirOf(it)
  local ex, ey = (it.fromX + dx * 6) * 4, (it.fromY + dy * 6) * 4
  local ang = math.atan2(dy, dx)
  local col = colOf(it.cause)
  -- sprite de cast si fourni (le cœur bloom appartient au sprite), sinon pointe de flèche pleine + barbes.
  local set = asGet("cast", it.cause)
  if drawSprite(set, 1 + math.floor((1 - k) * 4), ex, ey, ang, tintOf(it.cause), k, true, big and 1.0 or 0.8) then return end
  love.graphics.setBlendMode("add")
  local nx, ny = -dy, dx
  local L = (big and 11 or 8)               -- longueur de la pointe
  local Wd = (big and 5 or 4)               -- demi-largeur des barbes
  local tipX, tipY = ex + dx * L, ey + dy * L           -- pointe DEVANT (vers la cible)
  local baseX, baseY = ex - dx * 2, ey - dy * 2
  -- pointe de flèche PLEINE (triangle orienté) — c'est la forme elle-même, pas un fond.
  love.graphics.setColor(col[1], col[2], col[3], 0.95 * k)
  love.graphics.polygon("fill", tipX, tipY, baseX + nx * Wd, baseY + ny * Wd, baseX - nx * Wd, baseY - ny * Wd)
  -- cœur clair (ivoire) à la pointe -> netteté/punch (le « bloom » du cœur, pas un disque décoratif)
  love.graphics.setColor(1, 0.95, 0.82, 0.85 * k)
  love.graphics.polygon("fill", tipX, tipY, ex + nx * (Wd * 0.4), ey + ny * (Wd * 0.4), ex - nx * (Wd * 0.4), ey - ny * (Wd * 0.4))
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
end

-- ═══════════════════ IMPACT DIRECTIONNEL (sur la CIBLE, biaisé côté émetteur) — LA STAR ═══════════════
-- Particules : gerbe qui part À L'OPPOSÉ de l'émetteur (recoil) -> on LIT d'où vient le coup sans aucun trait.
local function emitImpactParticles(it)
  local dx, dy = dirOf(it)
  local tint = tintOf(it.cause)
  -- origine biaisée vers le CÔTÉ FACE à l'émetteur (l'effet éclot là où le coup mord).
  local ox, oy = (it.toX - dx * 3) * 4, (it.toY - dy * 3) * 4
  local recoil = math.atan2(dy, dx) -- la gerbe principale part dans le sens du coup (= loin de l'émetteur)
  local v = it.val or 8
  if it.cause == "attack" then
    -- PHYSIQUE = 1re classe : éclats ACIER + SANG tranchants, projetés dans le sens du coup. FORT, net.
    P.burst(ox, oy, { type = "shard", count = 7, dir = recoil, spread = math.pi * 0.7,
      speed = { 120, 260 }, life = { 0.28, 0.5 }, gravity = 180, drag = 1.7, spin = 14, tint = c.steel })
    P.burst(ox, oy, { type = "spark", count = 6, dir = recoil, spread = math.pi * 0.6,
      speed = { 90, 200 }, life = { 0.12, 0.26 }, drag = 3, tint = c.bloodL })
    P.burst(ox, oy, { type = "mote", count = 4, speed = { 40, 110 }, life = { 0.16, 0.3 }, drag = 3, tint = c.bloodL })
  elseif it.cause == "burn" then
    P.burst(ox, oy, { type = "ember", count = 9, dir = -math.pi / 2, spread = math.pi * 0.9,
      speed = { 50, 150 }, life = { 0.4, 0.9 }, gravity = -50, drag = 2.2, tint = tint })
    P.burst(ox, oy, { type = "mote", count = 4, dir = recoil, spread = math.pi * 0.7, speed = { 40, 120 }, life = { 0.15, 0.3 }, drag = 3, tint = tint })
  elseif it.cause == "shock" then
    P.burst(ox, oy, { type = "spark", count = 9, speed = { 110, 240 }, life = { 0.10, 0.22 }, drag = 3, tint = tint })
    P.burst(ox, oy, { type = "mote", count = 5, speed = { 60, 160 }, life = { 0.12, 0.26 }, drag = 3, tint = tint })
  else
    -- poison / bleed / rot : SPLAT de famille (gerbe directionnelle + gouttes qui retombent).
    P.burst(ox, oy, { type = "ash", count = 7, dir = recoil, spread = math.pi * 0.8,
      speed = { 60, 150 }, life = { 0.3, 0.6 }, gravity = 120, drag = 2.2, tint = tint })
    P.burst(ox, oy, { type = "mote", count = 5, dir = recoil, spread = math.pi * 0.7, speed = { 50, 140 }, life = { 0.18, 0.34 }, drag = 3, tint = tint })
  end
  -- onde de choc dithérée (chunky pixel = un LISERÉ qui s'écarte, pas un disque plein/halo de fond), réservée
  -- au coup PHYSIQUE (1re classe) où elle souligne l'impact ; les altérations s'en passent (pas de glow décoratif).
  if it.cause == "attack" then
    P.ring(ox, oy, { color = c.bloodL, r0 = 4, r1 = 14 + math.min(28, v * 1.8), life = 0.26 })
  end
end

-- forme d'impact NETTE par type (par-dessus les particules) : croissant phys / étoile foudre / bloom feu / splat.
local function drawImpactShape(it, k)
  if k <= 0 then return end
  local dx, dy = dirOf(it)
  local ang = math.atan2(dy, dx)
  local tx, ty = it.toX * 4, it.toY * 4
  -- origine biaisée côté émetteur (l'effet mord le côté face à l'attaquant).
  local ix, iy = (it.toX - dx * 2) * 4, (it.toY - dy * 2) * 4
  local col = colOf(it.cause)
  local tint = tintOf(it.cause)
  local grow = easeOut(1 - k) -- 0 (impact) -> 1 (épanoui)

  -- sprite d'impact baké si fourni (LA STAR côté pixel-art) — orienté dans le sens du coup.
  local impSet = asGet("impact", it.cause)
  if drawSprite(impSet, 1 + math.floor(grow * 4), ix, iy, ang, tint, math.max(0, k), true, 1.0) then
    -- foudre : un bolt POSÉ sur la cible en plus (frappe instantanée), si fourni
    local boltSet = (it.cause == "shock") and asGet("bolt", it.cause) or nil
    if boltSet then drawSprite(boltSet, 1 + math.floor(grow * 3), ix, iy, ang, tint, k, true, 1.0) end
    return
  end

  -- FALLBACK PROPRE (formes pleines nettes, ZÉRO trait de trajectoire) :
  love.graphics.setBlendMode("add")
  if it.cause == "attack" then
    -- CROISSANT de taille (arc épais) face à l'émetteur, qui s'ouvre et s'efface. Sang + liseré acier.
    local R = (10 + 16 * grow)
    local steps = 12
    local a0 = ang + math.pi * 0.5 + math.pi * 0.18 * k   -- arc balayé, perpendiculaire au coup
    local a1 = ang - math.pi * 0.5 - math.pi * 0.18 * k
    love.graphics.setColor(col[1], col[2], col[3], 0.9 * k)
    love.graphics.setLineWidth(3.0 * k + 1)
    local pts = {}
    for i = 0, steps do
      local a = a0 + (a1 - a0) * (i / steps)
      pts[#pts + 1] = ix + math.cos(a) * R; pts[#pts + 1] = iy + math.sin(a) * R
    end
    love.graphics.line(pts)
    -- liseré acier (croissant intérieur)
    love.graphics.setColor(c.steel[1], c.steel[2], c.steel[3], 0.7 * k)
    love.graphics.setLineWidth(1.5 * k + 1)
    for i = 1, #pts, 2 do pts[i] = ix + (pts[i] - ix) * 0.78; pts[i + 1] = iy + (pts[i + 1] - iy) * 0.78 end
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)
  elseif it.cause == "shock" then
    -- ÉTOILE/éclair d'étincelles POSÉE sur la cible : branches en zigzag, la PLUS LONGUE pointant vers le sens du
    -- coup (loin de l'émetteur) -> direction lisible. Cœur = nucléus du bolt (pas un disque décoratif).
    local branches = 5
    love.graphics.setColor(col[1], col[2], col[3], 0.95 * k)
    love.graphics.setLineWidth(2 * k + 1)
    for i = 0, branches - 1 do
      local a = ang + (i / branches) * math.pi * 2
      -- branche dans le sens du coup = plus longue (biais directionnel)
      local fwd = math.max(0, math.cos(a - ang))
      local L = (7 + 11 * grow) * (0.7 + 0.6 * fwd)
      local mxp, myp = ix + math.cos(a) * L * 0.55, iy + math.sin(a) * L * 0.55
      local na = a + 0.5 * (((i % 2) == 0) and 1 or -1)
      love.graphics.line(ix, iy, mxp, myp, ix + math.cos(na) * L, iy + math.sin(na) * L)
    end
    -- nucléus clair (le cœur du bolt « bloom » — petit, c'est l'effet, pas un fond)
    love.graphics.setColor(1, 1, 0.92, k)
    love.graphics.circle("fill", snap(ix), snap(iy), 2 * k + 1)
    love.graphics.setLineWidth(1)
  elseif it.cause == "burn" then
    -- BLOOM de flamme = LANGUES de feu (triangles/teardrops) qui jaillissent dans le sens du coup + montent,
    -- PAS un disque de glow. 3 langues décalées (sang/braise/ivoire) -> forme de flamme, 100% directionnelle.
    local base = ang                                   -- sens du coup (loin de l'émetteur)
    local tongues = { { c = col, len = 10 + 16 * grow, w = 6, off = 0 },
                      { c = c.ember, len = 8 + 12 * grow, w = 4, off = -0.5 },
                      { c = { 1, 0.92, 0.72 }, len = 5 + 7 * grow, w = 2.5, off = 0.4 } }
    for _, tg in ipairs(tongues) do
      local a = base + tg.off
      -- flamme = courbée vers le HAUT (la chaleur monte) : on biaise la pointe vers -y.
      local tipX = ix + math.cos(a) * tg.len
      local tipY = iy + math.sin(a) * tg.len - tg.len * 0.5
      local nx2, ny2 = -math.sin(a), math.cos(a)
      love.graphics.setColor(tg.c[1], tg.c[2], tg.c[3], 0.85 * k)
      love.graphics.polygon("fill", tipX, tipY, ix + nx2 * tg.w, iy + ny2 * tg.w, ix - nx2 * tg.w, iy - ny2 * tg.w)
    end
  else
    -- SPLAT de famille (poison/bleed/rot) : éclaboussure ÉTIRÉE dans le sens du coup (gouttes projetées),
    -- pas un disque rond. Lobes irréguliers, allongés vers l'avant -> directionnel + organique.
    local lobes = 8
    local pts = {}
    for i = 0, lobes - 1 do
      local a = i / lobes * math.pi * 2
      local fwd = 0.6 + 0.7 * math.max(0, math.cos(a - ang)) -- étirement vers l'avant (sens du coup)
      local rr = (5 + 11 * grow) * fwd * (0.7 + 0.3 * math.abs(math.sin(a * 2 + (it.seed or 0))))
      pts[#pts + 1] = ix + math.cos(a) * rr; pts[#pts + 1] = iy + math.sin(a) * rr
    end
    love.graphics.setColor(col[1], col[2], col[3], 0.7 * k)
    love.graphics.polygon("fill", pts)
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- BASE COMMUNE : émission + cycle de vie + drive des particules. Les variantes ne diffèrent que par le
-- POIDS du cast cue (sobre vs appuyé). AUCUN sprite ne voyage : seuls cast (émetteur) et impact (cible) vivent.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local function makeBase(bigCast)
  local M = {}

  function M.emit(self, inst)
    local connect = (inst.connectAt or 0.29) * 60
    self.items[#self.items + 1] = {
      fromX = inst.fromX, fromY = inst.fromY, toX = inst.toX, toY = inst.toY,
      cause = inst.cause or "attack", val = inst.val or 8, crit = inst.crit or false,
      connect = connect, castAt = math.max(0, connect - CAST_LEAD * 60),
      age = 0, casted = false, hit = false, castAge = 0, impactAge = 0,
      seed = (self.fxN or 0) % 997, big = bigCast,
    }
    self.fxN = (self.fxN or 0) + 1
  end

  function M.update(self, dt)
    for i = #self.items, 1, -1 do
      local it = self.items[i]
      it.age = it.age + dt
      -- CAST CUE (à l'émetteur) : se déclenche un cran AVANT l'impact (anticipation).
      if not it.casted and it.age >= it.castAt then
        it.casted = true; it.castAge = 0
        emitCastParticles(it, it.big)
      end
      if it.casted and not it.hit then it.castAge = it.castAge + dt end
      -- IMPACT (sur la cible) à connectAt : éclot l'effet directionnel + le jus LOCAL (zéro shake hors crit).
      if not it.hit and it.age >= it.connect then
        it.hit = true; it.impactAge = 0
        emitImpactParticles(it)
        impactJuice(it.toX * 4, it.toY * 4, it.cause, it.val, it.crit, it.fromX, it.fromY)
      end
      if it.hit then it.impactAge = it.impactAge + dt end
      if it.hit and it.impactAge >= IMPACT_DUR + LIFE_PAD then table.remove(self.items, i) end
    end
    if dt and dt > 0 then P.update(dt / 60) end -- drive du singleton de particules (frames -> secondes)
  end

  function M.draw(self, view)
    Draw.begin(view)
    love.graphics.setLineStyle("rough")
    for _, it in ipairs(self.items) do
      -- CAST CUE chez l'émetteur (tant qu'il vit, AVANT/pendant le début de l'impact). NET, additif (glow shader).
      if it.casted and it.castAge < CAST_DUR and not (it.hit and it.impactAge > 4) then
        drawCastCue(it, 1 - it.castAge / CAST_DUR, it.big)
      end
      -- IMPACT directionnel sur la cible (la STAR).
      if it.hit then
        drawImpactShape(it, 1 - it.impactAge / IMPACT_DUR)
      end
    end
    love.graphics.setLineWidth(1)
    Draw.finish()
    P.draw()  -- particules pixel (sous le même contexte ×4 design), bloomées par le shader postfx
    Draw.reset()
  end

  return M
end

local IMPL = {
  A = makeBase(false), -- Impact sobre : cast cue minimal + impact directionnel fort.
  B = makeBase(true),  -- Impact + cast : cast cue appuyé (anticipation + lancer) + même impact.
}

-- ── DISPATCHER ────────────────────────────────────────────────────────────────────────────────────────
local Layer = {}
Layer.__index = Layer

function AV.new(variant)
  asLoad()
  return setmetatable({ items = {}, fxN = 0, variant = IMPL[variant] and variant or "A" }, Layer)
end

function Layer:setVariant(name)
  if IMPL[name] then self.variant = name; self.items = {}; P.clear() end
end
function Layer:variantName() return self.variant end

function Layer:emit(inst) IMPL[self.variant].emit(self, inst) end
function Layer:update(dt) IMPL[self.variant].update(self, dt) end
function Layer:draw(view) IMPL[self.variant].draw(self, view) end
function Layer:clear() self.items = {}; self.fxN = 0; P.clear() end

return AV
