-- src/render/arena_draw.lua
-- Couche RENDER du combat. Possède TOUS les love.graphics.* et les rigs (animation). Lit l'état de
-- la SIM en LECTURE SEULE (arena.units : hp/shield/x/y/alive) et s'abonne aux ÉVÉNEMENTS de l'arène
-- (spawned/attack/hit/damage/death) pour déclencher animations et transients visuels (nombres de
-- dégâts, impacts, traînées de frappe). Ne mute JAMAIS la sim. cf. docs/research/engine-architecture.md §4.
--
-- B.1b — RENDU VIVANT EN COMBAT : les créatures GÉNÉRÉES (Critter.has(id)=true) sont dessinées via
-- `src/render/critter.lua` (déplacement par pixel : idle + attack/hurt/death), piloté par un état d'anim
-- RENDER-LOCAL (`self.anim[unit]`) commuté par les MÊMES évènements bus (attack -> atk, hit -> hurt,
-- death -> death ; priorité death > hurt > atk, latch sur la mort). Les 6 créatures dessinées-main
-- (Creatures[id]) restent sur le Rig baké (chemin inchangé). TOUS les VFX existants (nombres, shake,
-- flash, impacts, sang/débris de mort, afflictions, traînées) sont CONSERVÉS et s'ajoutent au critter.

local Rig = require("src.core.rig")
local Critter = require("src.render.critter") -- rendu vivant des créatures générées (idle + réactions de combat)
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local Spawn = require("src.data.spawn") -- tokens d'engeance (AXE 3) : pas dans Units -> visuel via le pont (family="sousetres"/arch dédié)
local CreatureGen = require("src.gen.creaturegen") -- visuel généré pour les unités sans rig main
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local HealthBar = require("src.render.healthbar")
local AfflictionFx = require("src.render.affliction_fx") -- feedback visuel des afflictions (particules + contour bouclier)
local SFX = require("src.audio.sfx") -- SON (Oniric grave) : cues de COMBAT (gros coup/mort) — RENDER pur, no-op headless. NE touche JAMAIS la SIM.
local Juice = require("src.ui.juice") -- MOUVEMENT « candy » : screen-shake trauma² + hitstop appariés au SON (RENDER pur, hors SIM)
local T = require("src.core.i18n").t

-- Échelle-monde des sprites générés en combat = MÊME que le Rig baké (def.scale = Primgen.WORLD_FIT) : critter
-- et rig partagent l'espace VIRTUEL (u.x,u.y) et le scale -> bascule sans déplacement ni resize. Le ×4 natif est
-- appliqué par le transform externe (main.lua / export.shoot, scene.nativeWorld), pas ici. cf. primgen.lua:2504.
local WORLD_FIT = require("src.gen.primgen").WORLD_FIT
local COMBAT_UNIT_SCALE = 0.36 -- mirror build board SLOT_SCALE so combat no longer zooms creatures up
local COMBAT_RIG_SCALE = COMBAT_UNIT_SCALE / WORLD_FIT
local COMBAT_SLOT_W, COMBAT_SLOT_H = 20, 22

-- Durées des RÉACTIONS critter, en FRAMES (l'horloge de combat = frames @60fps ; le proto les donne en SECONDES :
-- ATK 1.05s / HURT 0.45s / DEATH 1.2s + DEAD_HOLD 0.7s — cf. docs/generation/generateur-bestiaire.html l.930).
-- La PHASE ph = age/DUR ∈ [0,1] (clampée). Après DEATH_DUR, la mort RESTE figée à ph=1 (corps désagrégé, alpha
-- déjà retombé) le temps du DEAD_HOLD : on laisse le fondu `self.dead` finir d'éteindre le sprite.
local CR_ATK_DUR = 63   -- 1.05 s × 60
local CR_HURT_DUR = 27  -- 0.45 s × 60
local CR_DEATH_DUR = 72 -- 1.2 s × 60

-- Nombres de dégâts : port calibré depuis Feel Lab / dmgnumbers.lua.
-- Gros OPER lisible, pop de scale, petite montée initiale, puis stabilisation proche de la cible.
local DMG_LIFE = 74       -- durée de vie (frames)
local DMG_MERGE = 40      -- fenêtre d'agrégation (frames)
local DMG_RISE_TARGET = -8 -- offset final en design px : on pop juste au-dessus de la cible, sans léviter
local DMG_RISE_TAU = 9     -- stabilisation vers l'offset final (frames)
local DMG_POP_K = 0.10    -- ressort de scale
local DMG_POP_DAMP = 0.55 -- amortissement du pop
local DMG_ROW_H = 26      -- pile stable par cible : même colonne, rangées courtes et prévisibles

-- P2.2 — POIDS DU COUP (RENDER-only) : un gros coup secoue brièvement le TRANSFORM MONDE + flashe la cible
-- en blanc ~2 frames. RIEN ne touche la SIM (jamais u.x/u.y/hp) : un offset render-local décroît dans update,
-- appliqué/retiré DANS draw ; le flash est un re-tracé additif blanc du rig touché (tint render-local restauré).
local SHAKE_MAX = 3.2     -- amplitude max du tremblement (px virtuels) — clampé petit (sprites restent nets)
local SHAKE_DECAY = 0.55  -- décroissance par frame (retour au repos en ~quelques frames)
local SHAKE_PER_HP = 0.16 -- conversion dégât->amplitude (un coup de ~20 PV ≈ amplitude max)
local FLASH_DUR = 3       -- durée du flash blanc sur le rig touché (frames)
-- P2.3 — MOMENT DE MORT (RENDER-only) : un mort doit « compter ». À l'event death -> burst de particules
-- sombres/sang + flash ROUGE de la case (slot) qui s'éteint. Réutilise le pattern particule de affliction_fx.
local DEATH_CELL_DUR = 30 -- durée du flash rouge de la case de mort (frames)
local PHI = 0.6180339887  -- suite de Weyl (dispersion cosmétique déterministe, comme affliction_fx)
local TAU = 6.28318530718

-- VFX d'impact : les coordonnées restent en espace monde 320×180. On considère la créature comme un volume
-- vertical (pieds à u.y, torse/tête au-dessus) pour que les effets entourent la cible plutôt que la case.
local function unitVolume(u)
  return {
    cx = u.x, cy = u.y - 15,
    left = u.x - 11, right = u.x + 11,
    top = u.y - 32, bottom = u.y + 2,
    rx = 11, ry = 18,
  }
end

local function causeColor(cause)
  local C = Theme.c
  if cause == "burn" then return C.burn
  elseif cause == "bleed" then return C.bleed
  elseif cause == "poison" then return C.poison
  elseif cause == "rot" then return C.rot
  elseif cause == "shock" then return C.shock
  end
  return C.bloodL
end

local function causeDeep(cause)
  local C = Theme.c
  if cause == "bleed" then return C.bleedDeep or C.bloodD
  elseif cause == "poison" then return Theme.hex(0x334913)
  elseif cause == "rot" then return Theme.hex(0x3a2048)
  elseif cause == "shock" then return Theme.hex(0x6a5520)
  elseif cause == "burn" then return Theme.hex(0x6a2414)
  end
  return C.bloodD
end

local function easeOutCubic(p)
  local q = 1 - math.max(0, math.min(1, p))
  return 1 - q * q * q
end

local function easeOutQuad(p)
  p = math.max(0, math.min(1, p))
  return 1 - (1 - p) * (1 - p)
end

local function easeInOutBack(p)
  p = math.max(0, math.min(1, p))
  local c1, c2 = 1.45, 2.175
  if p < 0.5 then
    return ((2 * p) * (2 * p) * ((c2 + 1) * 2 * p - c2)) / 2
  end
  return ((2 * p - 2) * (2 * p - 2) * ((c2 + 1) * (p * 2 - 2) + c2) + 2) / 2
end

local function mixCol(a, b, t, alpha)
  return {
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
    a[3] + (b[3] - a[3]) * t,
    alpha or 1,
  }
end

local function damageTextColor(cause)
  local C = Theme.c
  if cause == "burn" then return C.burn
  elseif cause == "bleed" then return Theme.hex(0xfa1428)
  elseif cause == "poison" then return C.poison
  elseif cause == "rot" then return C.rot
  elseif cause == "shock" then return C.shock
  elseif cause == "reflect" then return C.shield
  elseif cause == "thorns" then return C.steel
  end
  return Theme.hex(0xff1208) -- vrai rouge, pas rouge délavé
end

local function isDotCause(cause)
  return cause == "poison" or cause == "bleed" or cause == "burn" or cause == "rot"
end

local function damageLane(cause)
  if cause == "attack" or cause == "cleave" or cause == "thorns" or cause == "reflect" then return 0 end
  if cause == "shock" then return 1 end
  if cause == "poison" then return 2 end
  if cause == "bleed" then return 3 end
  if cause == "burn" then return 4 end
  if cause == "rot" then return 5 end
  return 6
end

local function damageFontSize(val, crit)
  val = val or 0
  local px = 30
  if val >= 10 then px = 32 end
  if val >= 20 then px = 34 end
  if crit then px = px + 4 end
  return px
end

local function drawTextOutline(str, x, y, font, radius, color, alpha)
  for oy = -radius, radius do
    for ox = -radius, radius do
      if not (ox == 0 and oy == 0) and ox * ox + oy * oy <= radius * radius + 0.25 then
        Draw.text(str, x + ox, y + oy, { color[1], color[2], color[3], alpha }, font)
      end
    end
  end
end

-- BADGE DE RÔLE (overlay) : signale d'un coup d'œil les unités qui pèsent sur le CIBLAGE. `taunt` (override
-- dur) prime ; sinon une aggro NETTEMENT au-dessus du standard (>= 2× AGGRO_STD=10 -> tanks à 40 qui tirent
-- le focus sans le forcer). Les bruisers (15) / carries (5) ne badgent pas -> zéro bruit sur le champ.
local AGGRO_BADGE = 20
local function roleOf(u)
  local C = Theme.c
  if u.taunt then
    return { label = T("ui.taunt"), col = C.brassS, border = C.brass, fill = { 0.07, 0.05, 0.02, 0.9 } }
  elseif (u.aggro or 0) >= AGGRO_BADGE then
    return { label = T("ui.aggro"), col = C.bloodL, border = C.bloodDeep, fill = { 0.09, 0.04, 0.05, 0.9 } }
  end
  return nil
end

-- C4 — (couronne du commandant RETIRÉE — retour user : « pas très joli ». Le chef est désormais signalé par sa
-- CASE dorée distincte en combat, cf. drawGrid, et par le pédestal en build. Pas de glyphe couronne.)

local ArenaDraw = {}
ArenaDraw.__index = ArenaDraw

-- Durées des réactions critter exposées (lecture seule) : permet aux planches d'export (--shoot) de poser une
-- phase de pic (age = ph × DUR) sur une unité sans dupliquer ces constantes. RENDER-only (zéro impact SIM).
ArenaDraw.CR_DUR = { atk = CR_ATK_DUR, hurt = CR_HURT_DUR, death = CR_DEATH_DUR }

function ArenaDraw.new(arena, palette)
  local self = setmetatable({
    arena = arena, palette = palette,
    rigs = {},       -- [unit] = char (rig)
    anim = {},       -- B.1b : [unit] = { state = "idle"|"atk"|"hurt"|"death", age } pour les créatures GÉNÉRÉES (critter)
    dead = {},       -- [unit] = age (fondu de mort, géré côté render)
    dmgNumbers = {}, -- nombres flottants
    impacts = {},    -- étincelles d'impact
    hitRings = {},   -- anneaux/ripples d'impact {x,y,r0,r1,age,life,col,layer,width}
    hitParts = {},   -- particules de matière {kind,x,y,vx,vy,ay,age,life,col,size,layer}
    hitStreaks = {}, -- traits courts/splashs {x1,y1,x2,y2,vx,vy,age,life,col,width,layer}
    hitBolts = {},   -- arcs électriques pré-bakés autour de la cible {pts,age,life,col,width,layer}
    hitBubbles = {}, -- bulles/gaz poison {x,y,vx,vy,age,life,r0,r1,col,layer}
    hitShapes = {},  -- grandes formes d'impact typées, portées du Feel Lab {cause,cx,cy,dx,dy,age,life,val}
    bodyMotion = {}, -- impulsions locales attaquant/cible { [unit] = { atk=..., hurt=... } }, jamais SIM
    shake = { x = 0, y = 0, mag = 0 }, -- P2.2 : offset render-local du transform monde (décroît dans update)
    flash = {},      -- P2.2 : [unit] = age (flash blanc bref du rig touché)
    deathFx = {},    -- P2.3 : { x, y, age } flashs de case de mort (rouge -> fondu)
    dparts = {},     -- P2.3 : particules de mort (sang/débris sombres) {x,y,vx,vy,ay,age,life,col,size}
    fxN = 0,         -- compteur Weyl (dispersion cosmétique déterministe)
    t = 0,           -- horloge de combat (mémorisée en update -> lue en draw pour les anims VFX)
    -- SON (RENDER pur, no-op headless) : on AGRÈGE l'intention de cue pendant les events bus (qui peuvent
    -- arriver par centaines/frame en SKIP) puis on joue AU PLUS UN accent de famille + UN « thud » + UN « death »
    -- par frame RENDER (throttle dans update). Évite le spam ET garde le coût audio borné. cf. firewall.
    sndThud = 0,     -- plus grosse magnitude de coup vue cette frame (>0 -> on jouera 1 thud, pitch ∝ poids)
    sndCause = nil,  -- famille sonore dominante de la frame (bleed/poison/shock/rot/burn/attack)
    sndCauseMag = 0, -- magnitude de la famille dominante (anti-spam : un accent par frame)
    sndDeaths = 0,   -- nb de morts vues cette frame (>0 -> on jouera 1 cue de mort, throttlé)
  }, ArenaDraw)
  self.fx = AfflictionFx.new() -- couche d'afflictions (créée avant rebuild, qui peut la reset)
  self:rebuild()
  -- Abonnements au bus de l'arène (la sim émet, le render réagit). Chaque évènement pilote À LA FOIS le Rig
  -- baké (6 main) ET l'état d'anim critter (générés) — un seul est ensuite dessiné par unité selon Critter.has.
  arena.bus:on("spawned", function() self:rebuild({ preserve = true }) end)
  arena.bus:on("attack", function(u)
    Rig.trigger(self:rigFor(u), "attack")
    self:setAnim(u, "atk") -- B.1b : armé seulement si pas déjà en hurt/death (priorité ; cf. setAnim)
    self:emitAttackMotion(u, u and u.target)
  end)
  arena.bus:on("hit", function(a, target)
    Rig.trigger(self:rigFor(target), "hurt")
    self:setAnim(target, "hurt") -- B.1b : le coup reçu interrompt l'attaque, mais jamais la mort
    self:emitHurtMotion(a, target)
    table.insert(self.impacts, { x = target.x - a.facing * 6, y = target.y - 14, age = 0 })
  end)
  arena.bus:on("damage", function(rec)
    -- CHOC : la décharge du condensateur (cause="shock") déclenche les étincelles « Super Saiyan » sur la cible.
    if rec.cause == "shock" and rec.target then self.fx:shockSpark(rec.target) end
    -- on n'affiche un nombre que pour les dégâts qui touchent les PV (le pur-absorbé reste discret).
    local n = rec.hp
    if not (n and n > 0) then return end
    -- P2.2 — POIDS DU COUP : un coup qui mord les PV secoue le monde (∝ dégât, clampé) + flashe la cible en
    -- blanc. Seuls les coups un peu lourds (>=3 PV) déclenchent le shake -> les tics de DoT ne font pas trembler.
    if n >= 3 then
      local mag = math.min(SHAKE_MAX, n * SHAKE_PER_HP)
      if mag > self.shake.mag then self.shake.mag = mag end -- garde le plus gros choc en cours
    end
    -- SON : un gros coup arme le « thud » de poids ; chaque famille arme aussi un accent sonore discret (bleed,
    -- poison, shock...). On agrège seulement la plus grosse magnitude de la frame, puis flushAudio throttle le
    -- rendu sonore. RENDER pur -> golden inchangé.
    if n >= 8 and n > self.sndThud then self.sndThud = n end
    if n > (self.sndCauseMag or 0) then
      self.sndCause = rec.cause or "attack"
      self.sndCauseMag = n
    end
    if rec.target then self.flash[rec.target] = 0 end -- (re)arme le flash blanc sur la cible
    local tgt, src, cause = rec.target, rec.source, rec.cause or "attack"
    self:emitDamageFx(rec, n)
    self:spawnDamageNumber({ target = tgt, source = src, cause = cause }, n)
  end)
  -- P2.3 — MOMENT DE MORT : la SIM émet "death" {unit} quand une entité tombe. Le RENDER pose un flash ROUGE
  -- de la case + un petit burst de particules sombres/sang -> un mort « compte » visuellement (la disparition
  -- du rig est sinon gérée par le fondu `dead`, trop discret seul). 100% RENDER, ne mute jamais la SIM.
  arena.bus:on("death", function(u)
    if not u then return end
    self:setAnim(u, "death") -- B.1b : latch — la créature générée se désagrège (deathPix), priorité absolue
    self.sndDeaths = self.sndDeaths + 1 -- SON : agrège (throttle 1 cue de mort/frame, joué dans update)
    self.deathFx[#self.deathFx + 1] = { x = u.x, y = u.y, age = 0 }
    -- éclat de sang : ~10 fragments éjectés du torse (gravité), couleur sang/sang-séché, dispersion Weyl.
    local cx, cy = u.x, u.y - 12
    for i = 1, 10 do
      self.fxN = self.fxN + 1
      local ang = (i / 10) * 6.2832 + ((self.fxN * PHI) % 1 - 0.5) * 0.9
      local spd = 0.9 + ((self.fxN * 0.7548776662) % 1) * 1.6
      local dark = (i % 3 == 0)
      self.dparts[#self.dparts + 1] = {
        x = cx, y = cy, vx = math.cos(ang) * spd, vy = math.sin(ang) * spd - 0.4, ay = 0.09,
        age = 0, life = 16 + ((self.fxN * 0.5698402909) % 1) * 12,
        col = dark and Theme.c.bloodDeep or Theme.c.blood, size = dark and 1 or 2,
      }
    end
  end)

  -- TRANSMISSION (Partie 2) : une affliction saute d'une unité à une autre (contagion / propagation à la
  -- mort). La SIM émet "spread" {from,to,family} ; le RENDER lance un projectile en arc + impact.
  arena.bus:on("spread", function(ev)
    if ev and ev.from and ev.to then self.fx:spread(ev.from, ev.to, ev.family, ev.magnitude, ev.capped) end
  end)
  -- Signal « ça s'allume » : une pose d'affliction RENFORCÉE (aura d'ampli) -> pulse de couleur sur la cible.
  arena.bus:on("amped", function(ev)
    if ev and ev.unit then self.fx:amped(ev.unit, ev.family) end
  end)
  -- Boucliers périodiques : pulse cyan à chaque (re)cast ; étincelles sur l'attaquant à une réflexion.
  arena.bus:on("shield_cast", function(ev)
    if ev and ev.targets then self.fx:shieldCast(ev.targets, ev.overcharge) end
  end)
  arena.bus:on("reflect", function(ev)
    if ev and ev.from then self.fx:reflect(ev.from) end
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
      local spec = Units[u.id] or Spawn.token(u.id) or {} -- engeance : Units[id] nil -> pont Spawn (family="sousetres"/arch dédié)
      def = CreatureGen.cached({ id = u.id, type = spec.type, family = spec.family, arch = spec.arch, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank or 1 })
    end
    c = Rig.new(def, self.palette)
    c.x, c.y, c.facing = u.x, u.y, u.facing
    c.trail = {}
    self.rigs[u] = c
  end
  return c
end

-- B.1b — COMMUTATION de l'état d'anim critter (RENDER-local), piloté par le bus. Priorité death > hurt > atk,
-- exactement comme le driver du proto (l.932-938) : un mort n'attaque plus (latch), un touché interrompt l'attaque.
-- On (ré)arme l'âge à 0 quand l'évènement EST autorisé à prendre la main ; sinon on l'ignore (l'état en cours
-- de priorité supérieure poursuit son cours). No-op pour les unités dessinées-main (jamais lues : rendu via Rig).
local ANIM_PRIO = { idle = 0, atk = 1, hurt = 2, death = 3 }
function ArenaDraw:setAnim(u, state)
  if not (u and Critter.has and Critter.has(u.id)) then return end
  local a = self.anim[u]
  if not a then a = { state = "idle", age = 0 }; self.anim[u] = a end
  if a.state == "death" then return end                 -- mort = définitif (latch), aucun évènement ne le relance
  -- atk ne s'arme PAS si un hurt est encore en cours (le coup reçu prime tant qu'il n'est pas résorbé).
  if state == "atk" and a.state == "hurt" and a.age < CR_HURT_DUR then return end
  if ANIM_PRIO[state] >= ANIM_PRIO[a.state] or a.state == "idle" then
    a.state, a.age = state, 0
  end
end

-- (Re)construit les rigs à partir des unités courantes (initial + respawn de la démo).
function ArenaDraw:rebuild(opts)
  opts = opts or {}
  local oldRigs = opts.preserve and self.rigs or nil
  local oldAnim = opts.preserve and self.anim or nil
  local oldDead = opts.preserve and self.dead or nil
  self.rigs, self.anim, self.dead = {}, {}, {}
  if not opts.preserve then
    self.dmgNumbers = {}; self.impacts = {}
    self.hitRings = {}; self.hitParts = {}; self.hitStreaks = {}; self.hitBolts = {}; self.hitBubbles = {}
    self.hitShapes = {}; self.bodyMotion = {}
    self.shake = { x = 0, y = 0, mag = 0 }; self.flash = {}; self.deathFx = {}; self.dparts = {}
    if self.fx then self.fx:reset() end
  end
  for _, u in ipairs(self.arena.units) do
    if oldRigs and oldRigs[u] then self.rigs[u] = oldRigs[u] end
    if oldAnim and oldAnim[u] then self.anim[u] = oldAnim[u] end
    if oldDead and oldDead[u] then self.dead[u] = oldDead[u] end
    self:rigFor(u)
  end
end

function ArenaDraw:fxRand(salt)
  self.fxN = (self.fxN or 0) + 1
  return (self.fxN * (salt or PHI)) % 1
end

function ArenaDraw:emitRing(x, y, cause, r0, r1, life, layer, width)
  local col = causeColor(cause)
  self.hitRings[#self.hitRings + 1] = {
    x = x, y = y, r0 = r0 or 2, r1 = r1 or 14, age = 0, life = life or 18,
    col = col, layer = layer or "front", width = width or 1, phase = self:fxRand(0.421) * TAU,
  }
end

function ArenaDraw:emitPart(kind, x, y, vx, vy, opts)
  opts = opts or {}
  self.hitParts[#self.hitParts + 1] = {
    kind = kind or "spark", x = x, y = y, vx = vx or 0, vy = vy or 0, ay = opts.ay or 0,
    age = 0, life = opts.life or 20, col = opts.col or causeColor(opts.cause), size = opts.size or 1,
    layer = opts.layer or "front",
  }
end

function ArenaDraw:emitStreak(x1, y1, x2, y2, opts)
  opts = opts or {}
  self.hitStreaks[#self.hitStreaks + 1] = {
    x1 = x1, y1 = y1, x2 = x2, y2 = y2, vx = opts.vx or 0, vy = opts.vy or 0,
    age = 0, life = opts.life or 14, col = opts.col or causeColor(opts.cause),
    width = opts.width or 1, layer = opts.layer or "front",
  }
end

function ArenaDraw:emitBolt(vol, cause, layer, spin, lift)
  local pts = {}
  local a0 = self:fxRand(0.7548776662) * TAU + (spin or 0)
  local span = TAU * (0.58 + self:fxRand(0.5698402909) * 0.20)
  local steps = 8
  for i = 0, steps do
    local p = i / steps
    local a = a0 + span * p
    local jitter = (self:fxRand(0.43871) - 0.5) * 3
    pts[#pts + 1] = {
      x = vol.cx + math.cos(a) * (vol.rx + 3 + jitter),
      y = vol.cy + math.sin(a) * (vol.ry + (lift or 0)) + (self:fxRand(0.931) - 0.5) * 2,
    }
  end
  self.hitBolts[#self.hitBolts + 1] = {
    pts = pts, age = 0, life = 13 + self:fxRand(0.337) * 5,
    col = causeColor(cause), width = 1 + self:fxRand(0.673) * 0.8, layer = layer or "front",
  }
end

function ArenaDraw:emitBubble(x, y, opts)
  opts = opts or {}
  self.hitBubbles[#self.hitBubbles + 1] = {
    x = x, y = y, vx = opts.vx or 0, vy = opts.vy or -0.35, age = 0, life = opts.life or 28,
    r0 = opts.r0 or 1.5, r1 = opts.r1 or 5, col = opts.col or causeColor(opts.cause), layer = opts.layer or "front",
  }
end

function ArenaDraw:motionFor(u)
  if not u then return nil end
  local m = self.bodyMotion[u]
  if not m then m = {}; self.bodyMotion[u] = m end
  return m
end

function ArenaDraw:emitAttackMotion(u, target)
  if not u then return end
  local dir = 0
  if target then
    dir = (target.x >= u.x) and 1 or -1
  else
    dir = (u.facing or 1)
  end
  local m = self:motionFor(u)
  m.atk = {
    age = 0,
    life = 30,
    dir = dir,
    amp = 6.2,
    lift = 1.1,
  }
end

function ArenaDraw:emitHurtMotion(attacker, target)
  if not target then return end
  local dir
  if attacker then dir = (target.x >= attacker.x) and 1 or -1 else dir = -(target.facing or 1) end
  local m = self:motionFor(target)
  m.hurt = {
    age = 0,
    life = 24,
    dir = dir,
    amp = 4.6,
    squash = 0.12,
  }
end

function ArenaDraw:unitMotion(u)
  local m = self.bodyMotion[u]
  if not m then return 0, 0, 1, 1 end
  local ox, oy, sx, sy = 0, 0, 1, 1
  local atk = m.atk
  if atk then
    local p = math.max(0, math.min(1, atk.age / atk.life))
    local v
    if p < 0.22 then
      v = -1.35 * easeOutQuad(p / 0.22) -- anticipation : léger recul lisible avant la frappe
    elseif p < 0.52 then
      v = -1.35 + (atk.amp + 1.35) * easeOutCubic((p - 0.22) / 0.30)
      oy = oy - atk.lift * math.sin((p - 0.22) / 0.30 * math.pi)
    else
      v = atk.amp * (1 - easeOutQuad((p - 0.52) / 0.48))
    end
    ox = ox + (atk.dir or 1) * v
    sx = sx + 0.055 * math.sin(math.min(1, p / 0.40) * math.pi)
    sy = sy - 0.035 * math.sin(math.min(1, p / 0.40) * math.pi)
  end
  local hurt = m.hurt
  if hurt then
    local p = math.max(0, math.min(1, hurt.age / hurt.life))
    local recoil
    if p < 0.32 then
      recoil = hurt.amp * easeOutCubic(p / 0.32)
    else
      local q = (p - 0.32) / 0.68
      recoil = hurt.amp * (1 - easeOutQuad(q)) - 1.4 * math.sin(q * math.pi)
    end
    ox = ox + (hurt.dir or 1) * recoil
    oy = oy + math.sin(p * math.pi) * 1.0
    local squash = (hurt.squash or 0.1) * math.sin(math.min(1, p / 0.45) * math.pi)
    sx = sx + squash
    sy = sy - squash * 0.75
  end
  return ox, oy, sx, sy
end

function ArenaDraw:spawnDamageNumber(rec, amount)
  local target = rec and rec.target
  if not (target and amount and amount > 0) then return end
  local cause = rec.cause or "attack"
  local key = tostring(target) .. "|" .. cause
  for i = #self.dmgNumbers, 1, -1 do
    local d = self.dmgNumbers[i]
    if d.key == key and d.age < DMG_MERGE then
      local shown = d.displayVal or d.val
      d.val = d.val + amount
      d.fromVal = shown
      d.displayVal = shown
      d.countAge = 0
      d.countDur = isDotCause(cause) and 16 or 10
      d.age = 0
      d.pop = math.max(d.pop or 0, isDotCause(cause) and 0.46 or 0.58)
      d.heavy = math.max(d.heavy or 0, amount / 48)
      return
    end
  end

  self.fxN = (self.fxN or 0) + 1
  local vol = unitVolume(target)
  local heavy = math.min(1, amount / 48)
  self.dmgNumbers[#self.dmgNumbers + 1] = {
    order = self.fxN,
    key = key,
    target = target,
    source = rec.source,
    cause = cause,
    val = amount,
    displayVal = amount,
    fromVal = amount,
    countAge = 0,
    countDur = 0,
    x = vol.cx,
    y = vol.cy + 5,
    jitter = 0,
    rise = 0,
    age = 0,
    pop = 0.48 + 0.36 * heavy,
    popV = 0,
    heavy = heavy,
  }
end

function ArenaDraw:emitHitShape(vol, source, cause, amount)
  local sx = source and source.x or (vol.cx - 30)
  local sy = source and (source.y - 12) or vol.cy
  local dx, dy = vol.cx - sx, vol.cy - sy
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then dx, dy, len = 1, 0, 1 end
  dx, dy = dx / len, dy / len
  self.hitShapes[#self.hitShapes + 1] = {
    cause = cause or "attack",
    cx = vol.cx,
    cy = vol.cy - 1,
    dx = dx,
    dy = dy,
    age = 0,
    life = 18,
    val = amount or 1,
    seed = self:fxRand(0.318309886),
  }
end

-- Signature de dégâts : une petite grammaire VFX par famille. Les trajectoires sont déterministes mais variées
-- via fxRand (render-only) : lisible en replay, sans polluer la simulation.
function ArenaDraw:emitDamageFx(rec, amount)
  local target = rec and rec.target
  if not target then return end
  local cause = rec.cause or "attack"
  local source = rec.source
  local vol = unitVolume(target)
  local dir = (source and source.facing) or (target.team == "left" and -1 or 1)
  local hitX = vol.cx - dir * 8
  local hitY = vol.cy - 2 + (self:fxRand(0.271) - 0.5) * 8
  local heavy = (amount or 0) >= 8

  self:emitHitShape(vol, source, cause, amount)

  if cause == "bleed" then
    local blood, dark = Theme.c.bleed, causeDeep("bleed")
    self:emitRing(hitX, hitY, "bleed", 2, heavy and 18 or 13, 15, "front", 1.4)
    self:emitStreak(vol.cx - dir * 9, vol.cy - 10, vol.cx + dir * 11, vol.cy + 5,
      { col = blood, width = heavy and 2.2 or 1.5, life = 18, layer = "front" })
    for i = 1, heavy and 16 or 10 do
      local spread = -0.58 + self:fxRand(0.817) * 1.16
      local spd = 0.9 + self:fxRand(0.413) * (heavy and 2.2 or 1.45)
      local vx = dir * spd
      local vy = spread * 1.8 - 0.15
      self:emitPart("drop", vol.cx + dir * 5, vol.cy - 4 + self:fxRand(0.593) * 10, vx, vy,
        { col = (i % 3 == 0) and dark or blood, size = (i % 4 == 0) and 2 or 1, ay = 0.075, life = 17 + self:fxRand(0.711) * 13 })
    end
  elseif cause == "poison" then
    local col = Theme.c.poison
    self:emitRing(vol.cx, vol.cy, "poison", 4, heavy and 21 or 16, 20, "back", 1)
    for i = 1, heavy and 11 or 7 do
      local side = (self:fxRand(0.467) < 0.5) and -1 or 1
      local x = vol.cx + side * (3 + self:fxRand(0.389) * vol.rx)
      local y = vol.bottom - 4 - self:fxRand(0.721) * (vol.ry * 1.35)
      self:emitBubble(x, y, {
        cause = "poison", col = col, vx = (self:fxRand(0.631) - 0.5) * 0.34,
        vy = -0.22 - self:fxRand(0.543) * 0.52, r0 = 1, r1 = 3 + self:fxRand(0.421) * 3,
        life = 22 + self:fxRand(0.813) * 16, layer = (i % 3 == 0) and "back" or "front",
      })
    end
    for i = 1, heavy and 8 or 5 do
      self:emitPart("mote", vol.left + self:fxRand(0.283) * (vol.right - vol.left), vol.cy + self:fxRand(0.951) * 13 - 8,
        (self:fxRand(0.377) - 0.5) * 0.35, -0.18 - self:fxRand(0.459) * 0.28,
        { col = col, size = 1, life = 24 + self:fxRand(0.623) * 12, layer = "front" })
    end
  elseif cause == "shock" then
    self:emitRing(vol.cx, vol.cy, "shock", 4, heavy and 23 or 17, 12, "front", 1.5)
    self:emitBolt(vol, "shock", "back", 0.2, 0)
    self:emitBolt(vol, "shock", "front", 2.4, 1.5)
    if heavy then self:emitBolt(vol, "shock", "front", 4.1, -1) end
    for i = 1, heavy and 9 or 5 do
      local a = self:fxRand(0.619) * TAU
      self:emitPart("spark", vol.cx + math.cos(a) * vol.rx, vol.cy + math.sin(a) * vol.ry,
        math.cos(a) * (0.45 + self:fxRand(0.349) * 0.65), math.sin(a) * (0.35 + self:fxRand(0.437) * 0.45),
        { col = Theme.c.shock, size = 1, life = 10 + self:fxRand(0.587) * 8, layer = "front" })
    end
  elseif cause == "burn" then
    local col = Theme.c.burn
    self:emitRing(hitX, hitY, "burn", 2, heavy and 19 or 14, 15, "front", 1.2)
    for i = 1, heavy and 12 or 8 do
      local x = vol.left + self:fxRand(0.757) * (vol.right - vol.left)
      local y = vol.bottom - 5 - self:fxRand(0.641) * 10
      self:emitPart("ember", x, y, (self:fxRand(0.491) - 0.5) * 0.65, -0.55 - self:fxRand(0.733) * 0.8,
        { col = (i % 3 == 0) and Theme.c.ember or col, size = (i % 5 == 0) and 2 or 1, ay = -0.012, life = 16 + self:fxRand(0.829) * 13 })
    end
  elseif cause == "rot" then
    local col = Theme.c.rot
    self:emitRing(vol.cx, vol.cy, "rot", 3, heavy and 20 or 15, 22, "back", 1)
    for i = 1, heavy and 12 or 8 do
      local a = self:fxRand(0.531) * TAU
      local r = 2 + self:fxRand(0.691) * (heavy and 15 or 11)
      self:emitPart("ash", vol.cx + math.cos(a) * r, vol.cy + math.sin(a) * r,
        math.cos(a + 1.2) * 0.18, -0.1 + self:fxRand(0.977) * 0.35,
        { col = (i % 4 == 0) and causeDeep("rot") or col, size = 1, ay = 0.018, life = 20 + self:fxRand(0.743) * 18, layer = (i % 3 == 0) and "back" or "front" })
    end
  else
    local col = Theme.c.bloodL
    self:emitRing(hitX, hitY, "attack", 2, heavy and 18 or 12, 13, "front", heavy and 1.6 or 1.1)
    self:emitStreak(hitX - dir * 5, hitY - 5, hitX + dir * 9, hitY + 4,
      { col = Theme.c.ink, width = heavy and 1.6 or 1.0, life = 10, layer = "front" })
    for i = 1, heavy and 9 or 6 do
      local a = -dir * math.pi + (self:fxRand(0.877) - 0.5) * 1.5
      local spd = 0.6 + self:fxRand(0.337) * (heavy and 1.8 or 1.1)
      self:emitPart("spark", hitX, hitY, math.cos(a) * spd, math.sin(a) * spd - 0.15,
        { col = (i % 3 == 0) and Theme.c.brassS or col, size = 1, ay = 0.035, life = 11 + self:fxRand(0.569) * 9 })
    end
  end
end

function ArenaDraw:updateHitFx(frameDt)
  for i = #self.hitRings, 1, -1 do
    local r = self.hitRings[i]
    r.age = r.age + frameDt
    if r.age >= r.life then self.hitRings[i] = self.hitRings[#self.hitRings]; self.hitRings[#self.hitRings] = nil end
  end
  for i = #self.hitParts, 1, -1 do
    local p = self.hitParts[i]
    p.age = p.age + frameDt
    p.x = p.x + (p.vx or 0) * frameDt
    p.y = p.y + (p.vy or 0) * frameDt
    p.vy = (p.vy or 0) + (p.ay or 0) * frameDt
    if p.age >= p.life then self.hitParts[i] = self.hitParts[#self.hitParts]; self.hitParts[#self.hitParts] = nil end
  end
  for i = #self.hitStreaks, 1, -1 do
    local s = self.hitStreaks[i]
    s.age = s.age + frameDt
    local dx, dy = (s.vx or 0) * frameDt, (s.vy or 0) * frameDt
    s.x1, s.y1, s.x2, s.y2 = s.x1 + dx, s.y1 + dy, s.x2 + dx, s.y2 + dy
    if s.age >= s.life then self.hitStreaks[i] = self.hitStreaks[#self.hitStreaks]; self.hitStreaks[#self.hitStreaks] = nil end
  end
  for i = #self.hitBolts, 1, -1 do
    local b = self.hitBolts[i]
    b.age = b.age + frameDt
    if b.age >= b.life then self.hitBolts[i] = self.hitBolts[#self.hitBolts]; self.hitBolts[#self.hitBolts] = nil end
  end
  for i = #self.hitBubbles, 1, -1 do
    local b = self.hitBubbles[i]
    b.age = b.age + frameDt
    b.x = b.x + (b.vx or 0) * frameDt
    b.y = b.y + (b.vy or 0) * frameDt
    b.vy = (b.vy or 0) - 0.004 * frameDt
    if b.age >= b.life then self.hitBubbles[i] = self.hitBubbles[#self.hitBubbles]; self.hitBubbles[#self.hitBubbles] = nil end
  end
  for i = #self.hitShapes, 1, -1 do
    local s = self.hitShapes[i]
    s.age = s.age + frameDt
    if s.age >= s.life then self.hitShapes[i] = self.hitShapes[#self.hitShapes]; self.hitShapes[#self.hitShapes] = nil end
  end
end

function ArenaDraw:updateBodyMotion(frameDt)
  for u, m in pairs(self.bodyMotion) do
    if m.atk then
      m.atk.age = m.atk.age + frameDt
      if m.atk.age >= m.atk.life then m.atk = nil end
    end
    if m.hurt then
      m.hurt.age = m.hurt.age + frameDt
      if m.hurt.age >= m.hurt.life then m.hurt = nil end
    end
    if not m.atk and not m.hurt then self.bodyMotion[u] = nil end
  end
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

    -- B.1b — avance l'état d'anim critter (générés) : age += dt ; atk/hurt arrivés à terme retombent en idle,
    -- la mort RESTE figée (latch) à son âge max (ph plafonnée à 1 dans draw). Indépendant du fondu `dead`.
    local an = self.anim[u]
    if an and an.state ~= "idle" then
      an.age = an.age + frameDt
      if an.state == "atk" and an.age >= CR_ATK_DUR then an.state, an.age = "idle", 0
      elseif an.state == "hurt" and an.age >= CR_HURT_DUR then an.state, an.age = "idle", 0 end
    end
  end

  for i = #self.dmgNumbers, 1, -1 do
    local d = self.dmgNumbers[i]
    d.age = d.age + frameDt
    d.popV = (d.popV or 0) * DMG_POP_DAMP + (0 - (d.pop or 0)) * DMG_POP_K
    d.pop = (d.pop or 0) + d.popV * frameDt
    local riseLerp = 1 - math.exp(-frameDt / DMG_RISE_TAU)
    d.rise = (d.rise or 0) + (DMG_RISE_TARGET - (d.rise or 0)) * riseLerp
    if d.countAge and d.countDur and d.countDur > 0 and d.countAge < d.countDur then
      d.countAge = d.countAge + frameDt
      local q = math.min(1, d.countAge / d.countDur)
      local from = d.fromVal or d.val
      d.displayVal = math.floor(from + ((d.val or from) - from) * easeOutCubic(q) + 0.5)
    else
      d.displayVal = d.val
    end
    if d.age >= DMG_LIFE then table.remove(self.dmgNumbers, i) end
  end
  for i = #self.impacts, 1, -1 do
    local im = self.impacts[i]; im.age = im.age + frameDt
    if im.age >= 12 then table.remove(self.impacts, i) end
  end

  -- P2.2 — POIDS DU COUP : décroissance de l'amplitude de shake + recalcul d'un offset jitter (cosmétique,
  -- love.math) APPLIQUÉ dans draw. L'amplitude se résorbe en quelques frames -> secousse sèche, pas un roulis.
  local sk = self.shake
  if sk.mag > 0.05 then
    sk.mag = sk.mag - SHAKE_DECAY * frameDt
    if sk.mag < 0 then sk.mag = 0 end
    -- direction aléatoire par frame (love.math = cosmétique, hors SIM) -> tremblement, pas glissement.
    local ang = (love and love.math and love.math.random() or 0.5) * 6.2832
    sk.x = math.cos(ang) * sk.mag
    sk.y = math.sin(ang) * sk.mag * 0.7 -- un peu plus discret en vertical (le sol « tient »)
  else
    sk.mag, sk.x, sk.y = 0, 0, 0
  end

  -- P2.2 — flash blanc sur les rigs touchés (âge ; expiré -> retiré). Pairs OK : transient RENDER (pas la SIM).
  for u, age in pairs(self.flash) do
    local na = age + frameDt
    if na >= FLASH_DUR then self.flash[u] = nil else self.flash[u] = na end
  end

  -- P2.3 — flashs de case de mort (âge ; expiré -> retiré, backward swap-remove).
  for i = #self.deathFx, 1, -1 do
    local d = self.deathFx[i]; d.age = d.age + frameDt
    if d.age >= DEATH_CELL_DUR then table.remove(self.deathFx, i) end
  end
  -- P2.3 — particules de mort (intégration Euler + gravité), backward swap-remove (comme affliction_fx).
  local dp = self.dparts
  for i = #dp, 1, -1 do
    local p = dp[i]
    p.age = p.age + frameDt
    p.x = p.x + p.vx * frameDt
    p.vy = p.vy + p.ay * frameDt
    p.y = p.y + p.vy * frameDt
    if p.age >= p.life then dp[i] = dp[#dp]; dp[#dp] = nil end
  end

  self:updateHitFx(frameDt)
  self:updateBodyMotion(frameDt)
  self.fx:update(self.arena.units, frameDt, t) -- émission + intégration des particules d'affliction
end

-- SON (throttle 1/frame RÉELLE) : à appeler UNE fois par frame de la scène (PAS par pas de SIM ; en SKIP il y
-- a jusqu'à 240 pas/frame, mais on ne joue qu'UN accent + UN « thud » + UN cue de mort par frame). Les compteurs sont
-- agrégés dans les callbacks bus (damage/death) puis CONSOMMÉS ici. RENDER pur : SFX.play est no-op headless
-- (pas de device audio) -> aucune empreinte SIM/golden. Le pitch du thud descend pour les coups plus lourds
-- (registre Oniric grave : plus c'est gros, plus c'est profond), borné pour rester doux.
function ArenaDraw:flushAudio()
  if self.sndCause and self.sndCauseMag > 0 then
    local cause = self.sndCause
    local mag = self.sndCauseMag
    local heavy = math.min(1, math.max(0, (mag - 3) / 18))
    if cause == "bleed" then
      SFX.play("thud", { pitch = 0.92 - heavy * 0.08, volume = 0.82 })
    elseif cause == "poison" then
      SFX.play("tick", { pitch = 0.72 + heavy * 0.08, volume = 0.72 })
    elseif cause == "shock" then
      SFX.play("unlock", { pitch = 1.10 + heavy * 0.08, volume = 0.68 })
    elseif cause == "burn" then
      SFX.play("pop", { pitch = 0.82 + heavy * 0.10, volume = 0.70 })
    elseif cause == "rot" then
      SFX.play("drop", { pitch = 0.72 - heavy * 0.05, volume = 0.62 })
    end
    self.sndCause, self.sndCauseMag = nil, 0
  end
  if self.sndThud > 0 then
    -- coups 8..~30 PV -> pitch ~1.0 → 0.82 (plus grave = plus lourd). jitter par défaut du bank (anti-répétition).
    local heavy = math.min(1, (self.sndThud - 8) / 22)
    SFX.play("thud", { pitch = 1.0 - heavy * 0.18 })
    -- MOUVEMENT apparié au thud (game feel) : l'écran ENCAISSE le coup. trauma ∝ poids (modeste, calibrage
    -- grimdark) -> petits coups quasi-imperceptibles (trauma²), gros coups secs. Un gros coup (heavy > 0.45)
    -- ajoute un MICRO-GEL (hitstop ~50 ms) : le combat « s'arrête » l'espace d'un battement -> l'impact pèse.
    -- Throttlé 1/frame réelle (comme le son). RENDER pur : Juice ne lit/écrit jamais la SIM (golden intact).
    Juice.addTrauma(0.10 + heavy * 0.18)        -- 0.10 (8 PV) -> 0.28 (≈30 PV) : trauma² rend ça discret/punché
    if heavy > 0.45 then Juice.freeze(0.05) end -- HITSTOP bref sur un gros coup (le monde gèle, pas l'UI/Juice)
    self.sndThud = 0
  end
  if self.sndDeaths > 0 then
    -- une mort « compte » : cue grave et discret (drop pitché en bas). Une seule fois même si plusieurs morts/frame.
    SFX.play("drop", { pitch = 0.85 })
    -- MOUVEMENT apparié à la mort : trauma un peu PLUS fort qu'un coup (une chute « pèse » davantage) + un
    -- hitstop bref -> le moment de mort marque un temps. Plafonné par addTrauma (clamp 1) si plusieurs/frame.
    Juice.addTrauma(0.22)
    Juice.freeze(0.05)
    self.sndDeaths = 0
  end
end

-- GRILLE de combat : un SLOT sous chaque unité vivante, teinté par équipe (bleu = gauche/joueur, rouge =
-- droite/adverse) -> le placement de chaque grille reste lisible en permanence (et l'adversaire voit la
-- forme qu'il affronte). Reconstruit depuis la position de l'unité (zéro dépendance au plateau/sigil) : on
-- n'affiche que les cases OCCUPÉES — les cases VIDES du sigil demanderaient de router la shape jusqu'ici.
function ArenaDraw:drawGrid()
  local W, H = COMBAT_SLOT_W, COMBAT_SLOT_H
  love.graphics.setLineStyle("rough")
  love.graphics.setLineWidth(1)
  for _, u in ipairs(self.arena.units) do
    if u.alive and u.isCommander then
      -- C4 — LE COMMANDANT (refonte 2026-06, retour user : les bordures dorées 3-bandes étaient jugées « contours
      -- chelou ») : une case PLAIN, identique au panneau neutre des combattants côté joueur (teinte bleu très faible),
      -- SANS or, SANS halo. Il se présente par sa plaque « COMMANDER » (dessinée plus haut) + l'ABSENCE de barre de
      -- vie -> on comprend que c'est l'intouchable qui supervise, sans « contour chelou ».
      local x = math.floor(u.x - W / 2)
      local y = math.floor(u.y + 2 - H) -- la case ENCADRE le commandant, comme les combattants (cohérence)
      local r1, g1, b1, r2, g2, b2 = 0.06, 0.09, 0.14, 0.03, 0.05, 0.09 -- panneau neutre (= côté joueur)
      for i = 0, 2 do
        local t = i / 2
        love.graphics.setColor(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, 0.40)
        love.graphics.rectangle("fill", x, y + math.floor(i * H / 3), W, math.ceil(H / 3))
      end
      -- liseré MUET (fer teinté bleu, comme les combattants côté joueur) : aucune accentuation dorée.
      love.graphics.setColor(0.24, 0.29, 0.39, 0.50)
      love.graphics.rectangle("line", x, y, W, H)
      love.graphics.setColor(0.30, 0.38, 0.52, 0.55)
      love.graphics.line(x, y + H, x + W, y + H)
      love.graphics.setColor(1, 1, 1, 1)
    elseif u.alive then
      local left = (u.team == "left")
      local x = math.floor(u.x - W / 2)
      local y = math.floor(u.y + 2 - H) -- la carte ENCADRE le monstre (tête en haut, pieds en bas)
      -- CARTE de slot : panneau SOMBRE légèrement teinté équipe (détache la créature du biome chargé ->
      -- lisibilité constante, comme les tuiles du design) + liseré MUET. Fini le wireframe vif « debug ».
      -- Dégradé vertical 3 bandes (haut un peu plus clair = lumière du dessus) -> un panneau « assis », pas un aplat.
      local r1, g1, b1, r2, g2, b2
      if left then r1, g1, b1, r2, g2, b2 = 0.06, 0.09, 0.14, 0.03, 0.05, 0.09
      else r1, g1, b1, r2, g2, b2 = 0.12, 0.06, 0.07, 0.06, 0.03, 0.04 end
      for i = 0, 2 do
        local t = i / 2
        love.graphics.setColor(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, 0.40)
        love.graphics.rectangle("fill", x, y + math.floor(i * H / 3), W, math.ceil(H / 3))
      end
      -- liseré MUET (fer teinté équipe) ; ligne de base un chouïa plus marquée = pose l'unité au sol.
      if left then love.graphics.setColor(0.24, 0.29, 0.39, 0.50) else love.graphics.setColor(0.39, 0.23, 0.25, 0.50) end
      love.graphics.rectangle("line", x, y, W, H)
      if left then love.graphics.setColor(0.30, 0.38, 0.52, 0.55) else love.graphics.setColor(0.52, 0.28, 0.30, 0.55) end
      love.graphics.line(x, y + H, x + W, y + H)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- SCÈNE PARTAGÉE : sol de fosse + ligne de front, dessinés en ESPACE MONDE/VIRTUEL avec raw love.graphics
-- (MÊME convention que drawGrid : PAS sous Draw.begin) -> s'aligne sous les pieds des sprites (u.y). But :
-- les deux camps lisent comme une CONFRONTATION sur une scène commune, pas « 2 clusters dans le noir » :
--   · plateau elliptique sombre sous les deux équipes (centré ~160,118) + liseré laiton terni ;
--   · teinte de demi-sol gauche=bleu(bouclier)/droite=rouge(sang) très faible -> « mon côté / leur côté » ;
--   · couture verticale de ligne de front en x=160 (sang + colonne de lueur, alpha respirant via sin(t)).
-- RENDER PUR : ne lit que self.t (horloge cosmétique) ; ne touche jamais la SIM. RNG cosmétique = love.math.
function ArenaDraw:drawArena()
  local C = Theme.c
  local CX = 160 -- centre du plateau (canvas virtuel 320×180) = milieu des deux camps
  love.graphics.setLineStyle("rough")
  love.graphics.setLineWidth(1)

  -- 1) Plateau elliptique : disque de pierre sombre sous les deux équipes (les sort du vide noir).
  local floor = C.stone850
  love.graphics.setColor(floor[1], floor[2], floor[3], 0.6)
  love.graphics.ellipse("fill", CX, 118, 130, 34)
  -- Liseré laiton terni : ourle le plateau sans le faire briller.
  local rim = C.brassD
  love.graphics.setColor(rim[1], rim[2], rim[3], 0.4)
  love.graphics.ellipse("line", CX, 118, 130, 34)

  -- 2) Teinte de demi-sol (très faible) : moitié gauche bleu / moitié droite rouge -> « mon côté / leur côté ».
  -- Clippée à l'ellipse via une 2e ellipse de couleur par moitié (rectangle scissoré aurait un bord dur ;
  -- l'ellipse d'accent garde la forme du plateau). Alpha ~0.05 -> suggestion, jamais un aplat criard.
  local mine, theirs = C.shield, C.blood
  love.graphics.setColor(mine[1], mine[2], mine[3], 0.035)
  love.graphics.ellipse("fill", CX - 62, 118, 70, 32)
  love.graphics.setColor(theirs[1], theirs[2], theirs[3], 0.035)
  love.graphics.ellipse("fill", CX + 62, 118, 70, 32)

  -- 3) Couture de ligne de front en x=160 : SUGGÉRÉE (lueur qui RESPIRE), pas un trait franc -> on évite
  -- l'artefact « colonne rouge » qui faisait debug. Juste un soupçon de présence au milieu du champ.
  local breathe = 0.5 + 0.5 * math.sin((self.t or 0) * 0.04) -- 0..1
  local bl = C.blood
  love.graphics.setColor(bl[1], bl[2], bl[3], 0.022 + 0.018 * breathe)
  love.graphics.rectangle("fill", CX - 4, 62, 8, 84)

  love.graphics.setColor(1, 1, 1, 1)
end

-- P2.2 — FLASH BLANC du rig touché : on RE-TRACE le rig en additif blanc, intensité = `k` (1 au coup -> 0).
-- `Rig.draw` impose SA couleur ; on passe donc par son canal `anim.tint` (forcé blanc) + `anim.alpha`
-- (porte l'intensité du flash). On SAUVE/RESTAURE ces deux champs : ils sont recalculés à chaque update,
-- mais on reste propre dans la frame courante (aucune fuite). Blend additif -> « surbrillance », pas un aplat.
function ArenaDraw:drawRigFlash(rig, k)
  if k <= 0 or not rig.anim then return end
  local blend = love.graphics.setBlendMode
  local savedTint, savedAlpha = rig.anim.tint, rig.anim.alpha
  rig.anim.tint = { 1, 1, 1 }
  rig.anim.alpha = math.min(1, k) * 0.8 -- plafonné : un éclair, pas un blanchiment total du sprite
  if blend then blend("add") end
  Rig.draw(rig)
  if blend then blend("alpha") end
  rig.anim.tint, rig.anim.alpha = savedTint, savedAlpha
end

-- P2.3 — FLASH de CASE de mort : la case de l'unité tombée vire au ROUGE puis s'éteint (fondu) -> on VOIT
-- où un monstre vient de mourir. Même boîte que drawGrid (W,H/pas de Place) pour rester aligné aux slots.
function ArenaDraw:drawDeathFx()
  local C = Theme.c
  local W, H = COMBAT_SLOT_W, COMBAT_SLOT_H
  love.graphics.setLineStyle("rough")
  for _, d in ipairs(self.deathFx) do
    local p = d.age / DEATH_CELL_DUR
    local a = 1 - p
    local x = math.floor(d.x - W / 2)
    local y = math.floor(d.y + 2 - H)
    local bl = C.blood
    love.graphics.setColor(bl[1], bl[2], bl[3], a * 0.5)
    love.graphics.rectangle("fill", x, y, W, H)
    love.graphics.setColor(bl[1], bl[2], bl[3], a * 0.9)
    love.graphics.rectangle("line", x, y, W, H)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- P2.3 — ÉCLAT de mort (particules) : fragments sombres/sang éjectés du corps (additif léger -> chaud sans
-- laver). Rendu APRÈS les rigs pour rester au-dessus. Carrés 1-2px qui retombent (gravité intégrée en update).
function ArenaDraw:drawDeathParts()
  local blend = love.graphics.setBlendMode
  if blend then blend("add") end
  for _, p in ipairs(self.dparts) do
    local life = 1 - p.age / p.life
    local col = p.col or Theme.c.blood
    love.graphics.setColor(col[1], col[2], col[3], life)
    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
  end
  if blend then blend("alpha") end
  love.graphics.setColor(1, 1, 1, 1)
end

function ArenaDraw:drawHitShape(sh)
  local p = math.max(0, math.min(1, sh.age / sh.life))
  local k = 1 - p
  if k <= 0 then return end
  local grow = easeOutCubic(p)
  local dx, dy = sh.dx or 1, sh.dy or 0
  local ang = math.atan2(dy, dx)
  local cx, cy = sh.cx - dx * 2.5, sh.cy - dy * 1.5
  local col = causeColor(sh.cause)
  local heavy = math.min(1, (sh.val or 0) / 24)
  local blend = love.graphics.setBlendMode
  if blend then blend("add") end

  if sh.cause == "attack" then
    -- Coup physique : croissant large sang + liseré acier, directement SUR le côté touché.
    local r = 6.5 + (14 + heavy * 5) * grow
    local steps = 12
    local pts = {}
    local a0 = ang + math.pi * 0.58 + math.pi * 0.14 * k
    local a1 = ang - math.pi * 0.58 - math.pi * 0.14 * k
    for i = 0, steps do
      local a = a0 + (a1 - a0) * (i / steps)
      pts[#pts + 1] = cx + math.cos(a) * r
      pts[#pts + 1] = cy + math.sin(a) * r * 0.82
    end
    love.graphics.setLineWidth(1.4 + 2.2 * k + heavy * 0.8)
    love.graphics.setColor(col[1], col[2], col[3], 0.88 * k)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1 + 1.1 * k)
    love.graphics.setColor(Theme.c.steel[1], Theme.c.steel[2], Theme.c.steel[3], 0.70 * k)
    for i = 1, #pts, 2 do
      pts[i] = cx + (pts[i] - cx) * 0.72
      pts[i + 1] = cy + (pts[i + 1] - cy) * 0.72
    end
    love.graphics.line(pts)
  elseif sh.cause == "shock" then
    -- Choc : étoile de zigzags autour du volume, lisible comme une paralysie courte.
    love.graphics.setLineWidth(1.1 + 1.8 * k)
    love.graphics.setColor(col[1], col[2], col[3], 0.95 * k)
    for i = 0, 5 do
      local a = ang + (i / 6) * TAU
      local fwd = math.max(0, math.cos(a - ang))
      local len = (7 + 12 * grow) * (0.75 + 0.55 * fwd)
      local mx = cx + math.cos(a) * len * 0.52
      local my = cy + math.sin(a) * len * 0.76
      local za = a + (((i % 2) == 0) and 0.52 or -0.52)
      love.graphics.line(cx, cy, mx, my, cx + math.cos(za) * len, cy + math.sin(za) * len * 0.76)
    end
    love.graphics.setColor(1, 0.96, 0.72, 0.82 * k)
    love.graphics.rectangle("fill", math.floor(cx) - 1, math.floor(cy) - 1, 3, 3)
  elseif sh.cause == "burn" then
    -- Brûlure : langues de feu directionnelles qui montent, pas un disque de glow.
    local tongues = {
      { c = col, len = 9 + 14 * grow, w = 4.8, off = 0 },
      { c = Theme.c.ember, len = 7 + 11 * grow, w = 3.6, off = -0.45 },
      { c = { 1, 0.92, 0.70 }, len = 5 + 7 * grow, w = 2.2, off = 0.35 },
    }
    for _, tg in ipairs(tongues) do
      local a = ang + tg.off
      local tipX = cx + math.cos(a) * tg.len
      local tipY = cy + math.sin(a) * tg.len - tg.len * 0.55
      local nx, ny = -math.sin(a), math.cos(a)
      love.graphics.setColor(tg.c[1], tg.c[2], tg.c[3], 0.82 * k)
      love.graphics.polygon("fill", tipX, tipY, cx + nx * tg.w, cy + ny * tg.w, cx - nx * tg.w, cy - ny * tg.w)
    end
  else
    -- Saignement / poison / rot : splat organique étiré dans le sens du coup.
    local lobes = 9
    local pts = {}
    local base = 5 + (10 + heavy * 3) * grow
    for i = 0, lobes - 1 do
      local a = i / lobes * TAU
      local fwd = 0.62 + 0.75 * math.max(0, math.cos(a - ang))
      local irr = 0.72 + 0.28 * math.abs(math.sin(a * 2.0 + (sh.seed or 0) * TAU))
      local rr = base * fwd * irr
      pts[#pts + 1] = cx + math.cos(a) * rr
      pts[#pts + 1] = cy + math.sin(a) * rr * 0.82
    end
    love.graphics.setColor(col[1], col[2], col[3], 0.70 * k)
    love.graphics.polygon("fill", pts)
    love.graphics.setColor(1, 0.92, 0.78, (sh.cause == "bleed" and 0.18 or 0.08) * k)
    love.graphics.circle("fill", cx, cy, 1.5 + 1.8 * k)
  end

  if blend then blend("alpha") end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

function ArenaDraw:drawHitLayer(layer)
  love.graphics.setLineStyle("rough")

  if layer == "front" then
    for _, sh in ipairs(self.hitShapes) do self:drawHitShape(sh) end
  end

  for _, s in ipairs(self.hitStreaks) do
    if s.layer == layer then
      local k = 1 - s.age / s.life
      local col = s.col or Theme.c.bloodL
      love.graphics.setColor(col[1], col[2], col[3], k * 0.78)
      love.graphics.setLineWidth((s.width or 1) * (0.5 + k * 0.7))
      love.graphics.line(s.x1, s.y1, s.x2, s.y2)
    end
  end

  for _, p in ipairs(self.hitParts) do
    if p.layer == layer then
      local k = 1 - p.age / p.life
      local col = p.col or Theme.c.bloodL
      local sz = p.size or 1
      love.graphics.setColor(col[1], col[2], col[3], k * 0.85)
      if p.kind == "drop" then
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), sz + 1, sz)
      elseif p.kind == "ember" then
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), sz, sz + 1)
      elseif p.kind == "ash" then
        love.graphics.setColor(col[1], col[2], col[3], k * 0.55)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), sz, sz)
      elseif p.kind == "mote" then
        love.graphics.circle("fill", p.x, p.y, sz)
      else
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), sz, sz)
      end
    end
  end

  for _, b in ipairs(self.hitBubbles) do
    if b.layer == layer then
      local p = b.age / b.life
      local k = 1 - p
      local r = (b.r0 or 1) + ((b.r1 or 4) - (b.r0 or 1)) * easeOutCubic(p)
      local col = b.col or Theme.c.poison
      love.graphics.setColor(col[1], col[2], col[3], k * 0.18)
      love.graphics.circle("fill", b.x, b.y, r)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(col[1], col[2], col[3], k * 0.72)
      love.graphics.circle("line", b.x, b.y, r)
      love.graphics.setColor(Theme.c.ink[1], Theme.c.ink[2], Theme.c.ink[3], k * 0.28)
      love.graphics.rectangle("fill", math.floor(b.x - r * 0.25), math.floor(b.y - r * 0.28), 1, 1)
    end
  end

  local blend = love.graphics.setBlendMode
  if blend then blend("add") end
  for _, r in ipairs(self.hitRings) do
    if r.layer == layer then
      local p = r.age / r.life
      local k = 1 - p
      local rr = (r.r0 or 2) + ((r.r1 or 14) - (r.r0 or 2)) * easeOutCubic(p)
      local col = r.col or Theme.c.bloodL
      love.graphics.setLineWidth((r.width or 1) * (0.55 + k * 0.7))
      love.graphics.setColor(col[1], col[2], col[3], k * 0.74)
      local phase = r.phase or 0
      for i = 0, 11 do
        if i % 4 ~= 2 then
          local a1 = phase + (i / 12) * TAU
          local a2 = a1 + TAU / 12 * 0.62
          love.graphics.line(
            r.x + math.cos(a1) * rr, r.y + math.sin(a1) * rr * 0.72,
            r.x + math.cos(a2) * rr, r.y + math.sin(a2) * rr * 0.72
          )
        end
      end
      if k > 0.45 then
        love.graphics.setColor(Theme.c.ink[1], Theme.c.ink[2], Theme.c.ink[3], (k - 0.45) * 0.42)
        local ir = math.max(1, rr * 0.52)
        for i = 0, 7 do
          if i % 3 ~= 1 then
            local a1 = phase * 0.7 + (i / 8) * TAU
            local a2 = a1 + TAU / 8 * 0.45
            love.graphics.line(
              r.x + math.cos(a1) * ir, r.y + math.sin(a1) * ir * 0.68,
              r.x + math.cos(a2) * ir, r.y + math.sin(a2) * ir * 0.68
            )
          end
        end
      end
    end
  end
  for _, b in ipairs(self.hitBolts) do
    if b.layer == layer then
      local k = 1 - b.age / b.life
      local col = b.col or Theme.c.shock
      love.graphics.setLineWidth((b.width or 1) * (0.7 + k * 0.75))
      love.graphics.setColor(col[1], col[2], col[3], k * 0.90)
      for i = 1, #b.pts - 1 do
        local a, bb = b.pts[i], b.pts[i + 1]
        love.graphics.line(a.x, a.y, bb.x, bb.y)
      end
      love.graphics.setLineWidth(1)
      love.graphics.setColor(1, 0.96, 0.72, k * 0.55)
      for i = 2, #b.pts - 1, 3 do
        love.graphics.rectangle("fill", math.floor(b.pts[i].x), math.floor(b.pts[i].y), 1, 1)
      end
    end
  end
  if blend then blend("alpha") end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

-- B.1b — RENDU d'une créature GÉNÉRÉE via critter (vivant). Construit `opts` depuis l'état d'anim render-local
-- (`self.anim[u]`) : résout le kind (atk/hurt/death) une fois par unité (mémoïsé sur le rig — constant par id),
-- calcule la phase ph = age/DUR (clampée à 1 ; la mort reste figée à 1 après DEATH_DUR), et le fondu alpha (réutilise
-- `rig.alpha`, déjà calculé en update). `shadow=false` : l'ombre du sol est DÉJÀ dessinée plus haut (pas de double).
-- `death.noFx=true` : la gerbe interne de critter est coupée — `self.dparts` (burst de sang au thème) fait déjà le job.
-- PAS de flash blanc additif ici (critter n'a pas de teinte uniforme ; le brief interdit la teinte rouge interne) :
-- le hurt DÉFORMÉ + l'impact + le shake portent déjà le feedback du coup reçu pour les générés.
function ArenaDraw:drawCritter(u, rig)
  -- descripteurs de réaction résolus UNE fois (constants par id : forme/famille fixes) -> évite un lookup/frame.
  if rig.crAtk == nil then
    rig.crAtk = Critter.atkFor(u.id) or false
    rig.crHurt = Critter.hurtFor(u.id) or "recoil"
    rig.crDeath = Critter.deathFor(u.id) or "gib"
  end
  local an = self.anim[u]
  local opts
  if an and an.state ~= "idle" then
    if an.state == "atk" then
      local d = rig.crAtk or nil
      if d then opts = { shadow = false, atk = { k = d.k, pr = d, ph = math.min(1, an.age / CR_ATK_DUR) } } end
    elseif an.state == "hurt" then
      opts = { shadow = false, hurt = { k = rig.crHurt, ph = math.min(1, an.age / CR_HURT_DUR) } }
    elseif an.state == "death" then
      -- La DÉSAGRÉGATION (deathPix) éteint elle-même chaque cellule sur DEATH_DUR (alpha par cellule -> 0 à ph=1) :
      -- on garde alpha GLOBAL=1 pour la laisser s'exprimer EN ENTIER (le fade `rig.alpha` 40f la tronquerait).
      opts = { shadow = false, death = { k = rig.crDeath, ph = math.min(1, an.age / CR_DEATH_DUR), noFx = true },
        alpha = 1 }
    end
  end
  if not opts then opts = { shadow = false } end -- idle
  -- Idle/atk/hurt : applique le fondu de mort `rig.alpha` (une unité tombée AVANT d'avoir reçu l'event death, ou
  -- dont l'anim death est retombée, s'efface). En death, alpha=1 est déjà posé ci-dessus (désagrégation autonome).
  if opts.alpha == nil then opts.alpha = rig.alpha or 1 end
  -- ANCRAGE : pieds (grille 32,57) sur (u.x, u.y), scale aligne sur la taille du board build.
  -- t en SECONDES (self.t est en frames @60fps -> /60) pour l'idle/yeux de critter. facing = SENS D'ÉQUIPE (wantDir :
  -- joueur=+1 regarde à droite / adverse=-1 regarde à gauche) NORMALISÉ par le sens inhérent de la créature
  -- (facingFor) -> tout le monde se fait face quel que soit le faceDir natif de l'unité.
  Critter.drawAt(nil, u.id, u.x, u.y, COMBAT_UNIT_SCALE, (self.t or 0) / 60, Critter.facingFor(u.id, u.facing or 1), opts)
end

function ArenaDraw:drawUnitWithMotion(u, drawFn)
  local ox, oy, sx, sy = self:unitMotion(u)
  if ox == 0 and oy == 0 and sx == 1 and sy == 1 then
    drawFn()
    return
  end
  love.graphics.push()
  love.graphics.translate(u.x + ox, u.y + oy)
  love.graphics.scale(sx, sy)
  love.graphics.translate(-u.x, -u.y)
  drawFn()
  love.graphics.pop()
end

-- ───────────────────────── Rendu monde (canvas virtuel) ─────────────────────────
function ArenaDraw:draw(showBones)
  local units = self.arena.units

  -- P2.2 — POIDS DU COUP : tout le monde rendu sous un OFFSET de shake render-local (push/translate/pop).
  -- Offset purement cosmétique (calculé en update depuis les events damage), JAMAIS écrit dans la SIM ;
  -- appliqué ici et retiré en fin de draw -> aucune dérive d'état. La scène de fond (drawArena) reste FIXE
  -- pour ancrer l'œil (seuls les combattants + leurs fx tremblent).
  self:drawArena() -- scène partagée (sol de fosse + ligne de front), tout au fond — NON secouée

  local sk = self.shake
  love.graphics.push()
  love.graphics.translate(sk.x or 0, sk.y or 0)

  self:drawGrid() -- repères de slots (derrière ombres + unités)
  self:drawDeathFx() -- P2.3 : flashs de case de mort, sur le sol, sous les rigs survivants
  self:drawHitLayer("back") -- VFX qui doivent passer derrière le volume de la créature (gaz, arcs arrière)

  for _, u in ipairs(units) do
    local c = self.rigs[u]
    local a = u.alive and 0.5 or 0.5 * ((c and c.alpha) or 1)
    local ox = self:unitMotion(u)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.ellipse("fill", u.x + (ox or 0) * 0.35, u.y + 2, 8, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for _, u in ipairs(units) do
    local rig = self:rigFor(u)
    if Critter.has(u.id) then
      -- B.1b — CRÉATURE GÉNÉRÉE : rendu VIVANT (critter). Même ancrage que le Rig (pieds à u.x/u.y, scale
      -- WORLD_FIT, espace virtuel) -> bascule sans déplacement. L'état d'anim render-local fournit la phase.
      self:drawUnitWithMotion(u, function() self:drawCritter(u, rig) end)
    else
      -- 6 créatures DESSINÉES-MAIN : chemin Rig baké INCHANGÉ + flash blanc additif (re-tracé du rig touché).
      self:drawUnitWithMotion(u, function()
        love.graphics.push()
        love.graphics.translate(u.x, u.y)
        love.graphics.scale(COMBAT_RIG_SCALE, COMBAT_RIG_SCALE)
        love.graphics.translate(-u.x, -u.y)
        Rig.draw(rig)
        local fa = self.flash[u]
        if fa then self:drawRigFlash(rig, 1 - fa / FLASH_DUR) end
        love.graphics.pop()
      end)
    end
  end

  -- Afflictions : matière (sang/spores/bulles/mouches) sur les rigs, puis glow additif (flammes/chaleur).
  self.fx:drawBody(units, self.t)
  self.fx:drawGlow(units, self.t)
  self:drawDeathParts() -- P2.3 : éclat de sang/débris de mort (additif léger), au-dessus des rigs
  self:drawHitLayer("front") -- VFX d'impact lisibles au-dessus du sprite (coupe, arc avant, bulles)

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

  love.graphics.pop() -- P2.2 : fin de l'offset de shake render-local (le transform revient à l'identique)

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

function ArenaDraw:damageNumberMetrics(d)
  local p = d.age / DMG_LIFE
  local alpha = (p < 0.55) and 1 or math.max(0, 1 - (p - 0.55) / 0.45)
  if alpha <= 0 then return nil end
  local shownVal = d.displayVal or d.val
  local px = damageFontSize(shownVal, d.crit)
  local font = Theme.read(px)
  local str = "-" .. tostring(shownVal)
  local w = font and font:getWidth(str) or #str * px * 0.48
  local h = font and font:getHeight() or px
  local baseX = (d.x or 0) * 4 + (d.jitter or 0)
  local baseY = (d.y or 0) * 4 + (d.rise or 0)
  local s = math.max(0.78, 1 + (d.pop or 0))
  local icon = (d.cause ~= "attack") and HealthBar.icon(d.cause) or nil
  local iconScale = icon and math.max(3, math.floor(px / 10 + 0.5)) or 0
  local iconW = icon and icon.w * iconScale or 0
  local iconH = icon and icon.h * iconScale or 0
  local gap = icon and 8 or 0
  local totalW = iconW + gap + w
  local outline = (px >= 34 or d.crit) and 4 or 3
  local boxW = (totalW + outline * 2 + 8) * s
  local boxH = (math.max(h, iconH) + outline * 2 + 8) * s
  return {
    alpha = alpha, px = px, font = font, str = str, w = w, h = h,
    baseX = baseX, baseY = baseY,
    cx = d.layoutX or baseX, cy = d.layoutY or baseY,
    s = s, icon = icon, iconScale = iconScale, iconW = iconW, iconH = iconH,
    gap = gap, totalW = totalW, outline = outline, boxW = boxW, boxH = boxH,
  }
end

function ArenaDraw:layoutDamageNumbers()
  local groups, order = {}, {}
  for _, d in ipairs(self.dmgNumbers) do
    local m = self:damageNumberMetrics(d)
    if m then
      local key = tostring(d.target or d.key or d)
      local g = groups[key]
      if not g then
        g = {}
        groups[key] = g
        order[#order + 1] = key
      end
      g[#g + 1] = { d = d, m = m }
    end
  end

  local screenW, screenH = Draw.W or 1280, Draw.H or 720
  local items = {}
  for _, key in ipairs(order) do
    local g = groups[key]
    table.sort(g, function(a, b)
      local la, lb = damageLane(a.d.cause), damageLane(b.d.cause)
      if la ~= lb then return la < lb end
      if a.d.age == b.d.age then return (a.d.order or 0) > (b.d.order or 0) end
      return a.d.age < b.d.age
    end)
    local anchorX = g[1] and g[1].m.baseX or 0
    local anchorY = g[1] and g[1].m.baseY or 0
    for i, it in ipairs(g) do
      local d, m = it.d, it.m
      local row = i - 1
      local cx = anchorX
      local cy = anchorY - row * DMG_ROW_H
      cx = math.max(m.boxW / 2 + 16, math.min(screenW - m.boxW / 2 - 16, cx))
      cy = math.max(m.boxH / 2 + 58, math.min(screenH - m.boxH / 2 - 40, cy))
      d.layoutX, d.layoutY, d.layoutRow = cx, cy, row
      it.m.cx, it.m.cy = cx, cy
      items[#items + 1] = it
    end
  end
  table.sort(items, function(a, b)
    if a.d.age == b.d.age then return (a.d.order or 0) < (b.d.order or 0) end
    return a.d.age > b.d.age -- plus vieux dessinés d'abord ; les récents restent au-dessus
  end)
  return items
end

function ArenaDraw:drawDamageNumber(d)
  local m = self:damageNumberMetrics(d)
  if not m then return end
  local alpha = m.alpha
  local col = damageTextColor(d.cause)
  local font = m.font
  local str = m.str
  local w = m.w
  local h = m.h
  local cx, cy = m.cx, m.cy
  local s = m.s
  local icon = m.icon
  local iconScale = m.iconScale
  local iconW = m.iconW
  local iconH = m.iconH
  local gap = m.gap
  local totalW = m.totalW
  local main = (d.cause == "attack" or d.cause == "cleave") and mixCol(col, Theme.c.ink, 0.05, alpha)
    or mixCol(col, Theme.c.ink, 0.12, alpha)
  local shine = mixCol(main, Theme.c.gold, (d.crit or d.heavy and d.heavy > 0.55) and 0.34 or 0.13, alpha)
  local outline = m.outline

  love.graphics.push()
  love.graphics.translate(math.floor(cx + 0.5), math.floor(cy + 0.5))
  love.graphics.scale(s, s)

  local left = -totalW / 2
  if icon then
    love.graphics.setColor(1, 1, 1, alpha)
    -- +2 design px : aligne le centre visuel de l'icône avec OPER, qui a une chasse haute.
    love.graphics.draw(icon.image, math.floor(left), math.floor(-iconH / 2 + 2), 0, iconScale, iconScale)
    love.graphics.setColor(1, 1, 1, 1)
    left = left + iconW + gap
  end

  drawTextOutline(str, left, -h / 2, font, outline, { 0.018, 0.006, 0.010 }, 0.95 * alpha)
  drawTextOutline(str, left, -h / 2, font, 1, mixCol(col, Theme.c.blood, 0.46), 0.82 * alpha)
  love.graphics.setBlendMode("add")
  Draw.text(str, left - 1, -h / 2, { col[1], col[2], col[3], 0.26 * alpha }, font)
  Draw.text(str, left + 1, -h / 2, { Theme.c.gold[1], Theme.c.gold[2], Theme.c.gold[3], 0.12 * alpha }, font)
  love.graphics.setBlendMode("alpha")
  Draw.text(str, left, -h / 2, main, font)
  Draw.text(str, left, -h / 2 - 1, { shine[1], shine[2], shine[3], 0.45 * alpha }, font)
  if d.crit then
    Draw.text("!", left + w + 3, -h / 2, { Theme.c.brassS[1], Theme.c.brassS[2], Theme.c.brassS[3], alpha }, font)
  end
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

-- ───────────────────────── Overlay (espace design, texte net) ─────────────────────────
-- Gère sa PROPRE transform (appelée entre deux blocs Draw de la scène combat). Coords sim (u.x,u.y)
-- en virtuel -> ×4 design.
function ArenaDraw:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- Nom de l'unité (+ BADGE DE RÔLE optionnel) : juste AU-DESSUS de l'encadré de vie. Avec un rôle, on dessine
  -- la pile « [RÔLE] Nom » groupée et CENTRÉE sur l'unité -> le danger de ciblage se lit avant le nom.
  local nameFont = Theme.ui(9)
  local nameH = nameFont and nameFont:getHeight() or 9
  local roleFont = Theme.value(8)
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      local ny = (u.y + (HealthBar.BAR_DY or -34)) * 4 - nameH - 1
      local name = (u.spec and u.spec.displayName) or (Units[u.id] and T("unit." .. u.id .. ".name")) or u.id
      if u.isCommander then
        -- C4 — LE COMMANDANT (« général ») : visiblement distinct, JAMAIS de barre de vie ni de rôle. Une plaque
        -- « COMMANDER » (sa caste en doré, son nom dessous) prend la place de l'encadré de vie -> il se présente
        -- comme l'intouchable qui supervise, pas comme un combattant à abattre. (Sa CASE est dorée, cf. drawGrid.)
        local tag = T("ui.commander_tag")
        local pw = (roleFont and roleFont:getWidth(tag) or #tag * 5) + 10
        local nw = nameFont:getWidth(name)
        local startX = u.x * 4 - (pw + 5 + nw) / 2
        if roleFont then
          Draw.rect(startX, ny - 1, pw, nameH + 2, { 0.08, 0.06, 0.02, 0.92 }, c.brass, 1)
          Draw.textC(tag, startX + pw / 2, ny - 1 + (nameH + 2 - roleFont:getHeight()) / 2, c.gold, roleFont)
          Draw.text(name, startX + pw + 5, ny, c.brassL, nameFont)
        else
          Draw.textC(name, u.x * 4, ny, c.brassL, nameFont)
        end
      else
        local role = roleOf(u)
        if role and roleFont then
          local pw = roleFont:getWidth(role.label) + 8
          local nw = nameFont:getWidth(name)
          local startX = u.x * 4 - (pw + 5 + nw) / 2
          Draw.rect(startX, ny - 1, pw, nameH + 2, role.fill, role.border, 1)
          Draw.textC(role.label, startX + pw / 2, ny - 1 + (nameH + 2 - roleFont:getHeight()) / 2, role.col, roleFont)
          Draw.text(name, startX + pw + 5, ny, c.faint, nameFont)
        else
          Draw.textC(name, u.x * 4, ny, c.faint, nameFont)
        end
      end
    end
  end

  -- Barres de vie (encadré runique + segments + icônes) en espace design, grille fine ×2 -> finition d'UI.
  -- Dessinées AVANT les nombres flottants pour que ces derniers restent au-dessus. LE COMMANDANT (intouchable,
  -- damage()=0) N'A PAS de barre de vie : il ne se lit jamais comme une cible à entamer (demande user).
  for _, u in ipairs(self.arena.units) do
    if u.alive and not u.isCommander then HealthBar.draw(u, 2) end
  end

  -- Nombres flottants : couche Feel Lab transplantée + layout anti-collision.
  local dmgItems = self:layoutDamageNumbers()
  for _, it in ipairs(dmgItems) do self:drawDamageNumber(it.d) end

  Draw.finish()
end

return ArenaDraw
