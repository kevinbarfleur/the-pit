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

-- Statuts (DoT/altérations) — caps d'anti-dégénérescence (placeholders, cf. effects-design.md §4).
local WEAKEN_CAP = 0.40    -- malus de valeur max (poison)
local VOLT_PER_STACK = 3    -- CHOC : dégâts libérés PAR STACK à la décharge (instance cause="shock")
local SHOCK_STACK_CAP = 8   -- CHOC : plafond DUR de stacks (anti-explosion ; clamp comme les autres familles)
local AGGRO_STD = 10       -- aggro par défaut (standard) ; tank ~40, bruiser ~15, carry ~5 (porté par la data)

-- FATIGUE (enrage ~17 s) : passé FATIGUE_START ticks, une USURE globale croissante frappe toutes les
-- unités (ignore le bouclier) jusqu'à conclusion — aucun combat ne stagne (murs tank/regen, échanges de
-- DoT/soin). GATED sur les vraies batailles (autoReset=false) ; la démo en boucle n'est JAMAIS fatiguée.
-- DÉTERMINISTE (zéro RNG). `cause="fatigue"` ∉ STATUS_CAUSES (tools/sim.lua) -> ne fausse pas la part DoT.
-- Le golden conclut bien avant le seuil -> empreinte inchangée (cf. tests/golden.lua, ~105 events << 1020).
local FATIGUE_START = 1020 -- ~17 s @ 60 fps (1 tick = 1/60 s)
local FATIGUE_BASE  = 1    -- dps d'usure au déclenchement
local FATIGUE_RAMP  = 0.01 -- +dps par tick au-delà du seuil (l'usure s'accélère -> conclusion garantie)

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
  self.fatigue = opts.fatigue -- override optionnel { start?, base?, ramp? } (le lab peut balayer ; sinon constantes)
  self.ctx = {} -- contexte d'effets RÉUTILISÉ (aucune allocation par hook)
  self.deathCtx = {} -- ctx DÉDIÉ au broadcast on_death (n'écrase pas self.ctx pendant hit/tick)
  self.deaths = {}   -- file des morts de la frame : on_death résolu APRÈS la boucle (hors réentrance)
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
  local unit = {
    spec = spec, team = team, slot = spec.slot, x = spec.x, y = spec.y, facing = spec.facing,
    id = spec.id,
    maxHp = spec.hp, hp = spec.hp, dmg = spec.dmg, cd = spec.cd,
    -- effets : du spec si fourni (build résolu avec reliques, plus tard), sinon la base.
    effects = spec.effects or (u and u.effects),
    -- ciblage déterministe : depth (0 = colonne avant), row (tie-break haut->bas),
    -- aggro (ACTIVÉE : tank ~40 tire le focus / carry ~5 protégé ; défaut standard), taunt (override dur).
    depth = spec.depth or 0, row = spec.row or 0,
    aggro = spec.aggro or (u and u.aggro) or AGGRO_STD,
    taunt = spec.taunt or (u and u.taunt) or false,
    shield = spec.shield or 0, maxShield = spec.shield or 0,
    poisonInc = spec.poisonInc, burnInc = spec.burnInc, -- ampli d'aura (increased) lu par la pose de DoT (resolve+cap)
    atkTimer = self.rng:random() * spec.cd, -- décalage seedé -> pas de swings synchronisés
    firstHit = true,
    -- Statuts : poison = LISTE de stacks (axe « nombre ») ; burn/bleed/rot/shock = instances uniques.
    dots = { poison = {} },
    weaken = 0,    -- malus de valeur (poison) : réduit les valeurs PRODUITES par l'unité
    atkSlow = 0,   -- slow de cadence (bleed) : rallonge le rechargement du timer d'attaque
    regen = 0, regenAcc = 0, -- contre-DoT : soin au fil du temps
    swinging = false, swingAge = 0, swingHit = false,
    shieldReflect = 0, -- bouclier réfléchissant (posé par un shield_caster « miroir »)
    alive = true, target = nil,
  }
  if spec.shieldCaster then -- COPIE par combat : le spec est réutilisé sur N matchs (sim) -> ne JAMAIS le muter
    local sc = spec.shieldCaster
    unit.shieldCaster = { value = sc.value, cd = sc.cd, reflect = sc.reflect or 0,
      overcharge = sc.overcharge or false, targetSlots = sc.targetSlots, cdLeft = 0 }
  end
  return unit
end

function Arena:spawn()
  self.units = {}
  self.resetTimer = nil
  self.deaths = {}
  self.over = false
  self.win = nil
  self.overAge = 0
  self.teamFlags = { left = {}, right = {} } -- drapeaux d'équipe (grant_team T3) posés à combat_start
  for _, spec in ipairs(self.leftComp or demoComp("left")) do
    table.insert(self.units, self:makeUnit(spec, "left"))
  end
  for _, spec in ipairs(self.rightComp or demoComp("right")) do
    table.insert(self.units, self:makeUnit(spec, "right"))
  end
  -- combat_start : arme les effets qui s'initialisent au début (ex. regen). shield_aura (résolu au
  -- BUILD) n'a pas d'op combat -> ignoré gracieusement ici. ctx réutilisé.
  for _, u in ipairs(self.units) do
    self.ctx.arena, self.ctx.source, self.ctx.victim = self, u, u
    Effects.run(u, "combat_start", self.ctx)
  end
  -- BOUCLIERS PÉRIODIQUES : résout les cibles (slots figés au build) en réfs d'unités de la MÊME équipe.
  for _, u in ipairs(self.units) do
    local sc = u.shieldCaster
    if sc and sc.targetSlots then
      sc.targets = {}
      for _, w in ipairs(self.units) do
        if w.team == u.team and w.alive then
          for _, s in ipairs(sc.targetSlots) do
            if w.slot == s then sc.targets[#sc.targets + 1] = w; break end
          end
        end
      end
    end
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

-- Voisins au COMBAT = proximité du CHAMP DE BATAILLE (depth/row de l'arène), PAS le graphe du sigil.
-- DÉCISION D'ARCHI : l'arène reste SIM AUTONOME (zéro couplage au plateau). Les synergies de BUILD (auras)
-- utilisent le graphe du sigil (buildComp) ; la PROPAGATION en COMBAT (contagion, mort) utilise la
-- proximité. 8-voisinage (Chebyshev <= 1 ; epsilon pour les depth fractionnaires de certains sigils).
-- Pure fonction de l'état (zéro RNG), ordre des units -> déterministe, mirror-safe.
function Arena:neighborsOf(u)
  local out = {}
  for _, w in ipairs(self.units) do
    if w ~= u and w.alive and w.team == u.team then
      local dd, dr = w.depth - u.depth, w.row - u.row
      if dd < 0 then dd = -dd end
      if dr < 0 then dr = -dr end
      if dd <= 1.01 and dr <= 1.01 then out[#out + 1] = w end
    end
  end
  return out
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
  -- RÉFLEXION de bouclier (framework payoff §3.2c) : un coup ABSORBÉ mord l'attaquant (frac ≤ 0.60, cappé au
  -- build). Seulement sur une FRAPPE (pas les DoT) et cause="reflect" -> jamais de réflexion-de-réflexion.
  if absorbed > 0 and (target.shieldReflect or 0) > 0 and opts.cause == "attack" and opts.source and opts.source.alive then
    local refl = math.floor(absorbed * target.shieldReflect)
    if refl > 0 then
      self.bus:emit("reflect", { from = opts.source, by = target, amount = refl })
      self:damage(opts.source, refl, { ignoreShield = true, cause = "reflect", source = target })
    end
  end
  -- POURRITURE : ampute une fraction des PV MAX (perte permanente au combat). Min 1 ; re-clamp les PV.
  if opts.amputate and opts.amputate > 0 and target.maxHp > 1 then
    local cut = math.floor(raw * opts.amputate + 0.5)
    if cut > 0 then
      target.maxHp = math.max(1, target.maxHp - cut)
      if target.hp > target.maxHp then target.hp = target.maxHp end
      opts._amputated = cut -- lu par le tick rot pour Hollow-Gut (amputateHealsMe) ; inerte sinon
    end
  end
  if died then
    self.bus:emit("death", target)
    self.deaths[#self.deaths + 1] = target -- on_death résolu en fin de frame (différé, hors réentrance)
  end
  return dealt
end

-- Une frappe passe par les HOOKS du système d'effets. ctx réutilisé : aucune allocation par coup.
function Arena:hit(a, target)
  local ctx = self.ctx
  ctx.arena, ctx.source, ctx.victim = self, a, target
  ctx.amount, ctx.dealt = a.dmg, 0
  Effects.run(a, "on_attack", ctx) -- peut modifier ctx.amount (ex. bonus 1re frappe)
  -- Malus de VALEUR (poison) : une unité empoisonnée produit moins (dégâts réduits ici).
  if a.weaken > 0 then ctx.amount = math.max(0, math.floor(ctx.amount * (1 - a.weaken))) end

  local dealt = self:damage(target, ctx.amount, { source = a, cause = "attack" })
  ctx.dealt = dealt
  self.bus:emit("hit", a, target) -- le render déclenche l'anim "hurt" + l'impact

  Effects.run(a, "on_hit", ctx) -- ex. vol de vie (soigne a), poison (applique a la victime), pose de choc

  if target.alive then self:dischargeShock(a, target) end -- CHOC : libère le condensateur de la cible

  if target.alive then
    ctx.source, ctx.victim = target, a -- le defenseur reagit
    Effects.run(target, "on_attacked", ctx) -- ex. epines (renvoie a l'attaquant)
  end
end

-- DÉCHARGE DU CONDENSATEUR (choc) — appelée par hit() APRÈS le coup. La charge stockée (stacks × volt)
-- part d'un coup en une instance SÉPARÉE cause="shock" (visible / attribuée à l'event-log), IGNORE le
-- bouclier (décharge électrique), puis le condensateur est vidé (consume total). Crédit au poseur s'il vit,
-- sinon à l'attaquant. Déterministe (zéro RNG). Peut tuer -> self.deaths alimenté (on_death en fin de frame).
function Arena:dischargeShock(a, target)
  local sh = target.dots.shock
  if not sh or (sh.stacks or 0) <= 0 then return end
  local volt = sh.volt or VOLT_PER_STACK
  local burst = sh.stacks * volt
  local src = (sh.source and sh.source.alive) and sh.source or a
  if burst > 0 then
    self:damage(target, burst, { ignoreShield = true, cause = "shock", source = src })
  end
  -- CHAIN (modificateur rare) : l'arc saute à N ennemis proches pour 60% de la décharge (sparks auto).
  if sh.chain and sh.chain > 0 and burst > 0 then
    local arc = math.floor(burst * 0.6)
    if arc > 0 then
      local n = 0
      for _, nb in ipairs(self:neighborsOf(target)) do
        if nb.alive then
          self:damage(nb, arc, { ignoreShield = true, cause = "shock", source = src })
          n = n + 1; if n >= sh.chain then break end
        end
      end
    end
  end
  -- TRANSFER (modificateur rare) : une fraction des stacks SAUTE sur un voisin (profondeur 1 : sans modifs).
  if sh.transfer and sh.transfer > 0 then
    local moved = math.floor(sh.stacks * sh.transfer)
    if moved > 0 then
      for _, nb in ipairs(self:neighborsOf(target)) do
        if nb.alive then
          local ns = nb.dots.shock
          if not ns then
            nb.dots.shock = { stacks = math.min(SHOCK_STACK_CAP, moved), remaining = sh.remaining,
              cap = SHOCK_STACK_CAP, volt = volt, source = src }
          else
            ns.stacks = math.min(ns.cap, ns.stacks + moved)
            if volt > (ns.volt or 0) then ns.volt = volt end
          end
          self.bus:emit("spread", { from = target, to = nb, family = "shock", magnitude = moved, capped = false })
          break -- un seul voisin
        end
      end
    end
  end
  -- PERSIST (modificateur rare) : la charge ne se consume PAS entièrement (garde une fraction des stacks).
  if sh.persist and math.floor(sh.stacks * sh.persist) >= 1 then
    sh.stacks = math.floor(sh.stacks * sh.persist)
  else
    target.dots.shock = nil -- défaut : consume TOTAL (la charge se libère d'un seul coup)
  end
end

-- ── Tick des statuts (DoT / altérations) ──────────────────────────────────────────────────────
-- Le SEUL bloc « ouvert » qui connaît les familles (la boucle de combat, elle, reste fermée). Ordre
-- FIXE burn -> bleed -> poison -> rot -> choc -> regen (déterminisme). Accumulation ENTIÈRE (jamais de
-- float infligé) -> reproductible à l'octet. Ajouter une famille = +1 bloc ICI + 1 op de pose.
-- cf. docs/research/effects-design.md §1.B, effects-dot-families.md.
function Arena:tickDots(u, frameDt)
  local d = u.dots

  -- BRÛLURE : intensité qui DÉCROÎT ; n'IGNORE PAS le bouclier (le feu lèche l'enveloppe d'abord).
  local b = d.burn
  if b then
    b.remaining = b.remaining - frameDt
    local btf = b.source and self.teamFlags and self.teamFlags[b.source.team]
    if b.decayEvery and not (btf and btf.burnNoDecay) then -- ASH-MAW : les feux de l'equipe ne decroissent plus
      b.decayAcc = b.decayAcc + frameDt
      if b.decayAcc >= b.decayEvery then
        b.decayAcc = b.decayAcc - b.decayEvery
        b.dps = math.floor(b.dps * (1 - b.decayPct))
      end
    end
    b.acc = b.acc + b.dps * (frameDt / 60)
    if b.acc >= 1 then local n = math.floor(b.acc); b.acc = b.acc - n
      self:damage(u, n, { cause = "burn", source = b.source }) end
    if b.remaining <= 0 or b.dps <= 0 then d.burn = nil end
  end

  -- SAIGNEMENT : bas DPS, ignore le bouclier ; le slow de cadence (u.atkSlow) est posé à l'application.
  local bl = d.bleed
  if bl then
    bl.remaining = bl.remaining - frameDt
    bl.acc = bl.acc + bl.dps * (frameDt / 60)
    if bl.acc >= 1 then local n = math.floor(bl.acc); bl.acc = bl.acc - n
      self:damage(u, n, { ignoreShield = true, cause = "bleed", source = bl.source }) end
    if bl.slowScalesMissingHp then -- TENDON-RENDER : le slow ENFLE avec les PV manquants (recalculé/tick)
      local bonus = bl.slowPct * (1 - u.hp / u.maxHp)
      u.atkSlow = math.max(0, u.atkSlow + bonus - (bl.dynBonus or 0))
      bl.dynBonus = bonus
    end
    if bl.remaining <= 0 then
      u.atkSlow = math.max(0, u.atkSlow - bl.slowPct - (bl.dynBonus or 0))
      d.bleed = nil
    end
  end

  -- POISON : N stacks indépendants (axe « nombre »), ignore le bouclier ; recompute le malus de valeur.
  local stacks = d.poison
  if #stacks > 0 then
    local weaken = 0
    local i = 1
    while i <= #stacks do
      local s = stacks[i]
      s.remaining = s.remaining - frameDt
      s.acc = s.acc + s.dps * (frameDt / 60)
      if s.acc >= 1 then local n = math.floor(s.acc); s.acc = s.acc - n
        self:damage(u, n, { ignoreShield = true, poison = true, cause = "poison", source = s.source }) end
      if s.remaining <= 0 then
        stacks[i] = stacks[#stacks]; stacks[#stacks] = nil -- swap-remove (jamais table.remove au milieu)
      else
        weaken = weaken + (s.weaken or 0)
        i = i + 1
      end
    end
    u.weaken = math.min(WEAKEN_CAP, weaken)
    if u.igniteAt and #stacks >= u.igniteAt and not u.ignited then -- VENOM-CENSER : seuil atteint -> detonation (poison->burn)
      u.ignited = true
      local cur = u.dots.burn
      local dps = u.igniteDps or 8
      if not cur or dps > cur.dps then
        u.dots.burn = { dps = dps, remaining = u.igniteDur or 120, acc = 0,
          decayEvery = 60, decayAcc = 0, decayPct = 0.30, source = u.igniteSrc }
      end
    end
  end

  -- POURRITURE : durée qui enfle ; ampute les PV max ; ignore le bouclier.
  local r = d.rot
  if r then
    r.remaining = r.remaining - frameDt
    if r.passiveRamp then -- PATIENT-WORM : enfle même SANS frappe (ramp/seconde, borné par capDps)
      r.rampAcc = (r.rampAcc or 0) + r.passiveRamp * (frameDt / 60)
      if r.rampAcc >= 1 then local g = math.floor(r.rampAcc); r.rampAcc = r.rampAcc - g
        r.dps = math.min(r.capDps or r.dps, r.dps + g) end
    end
    r.acc = r.acc + r.dps * (frameDt / 60)
    if r.acc >= 1 then local n = math.floor(r.acc); r.acc = r.acc - n
      local o = { ignoreShield = true, cause = "rot", amputate = r.maxHpFrac, source = r.source }
      self:damage(u, n, o)
      if r.amputateHealsMe and r.source and r.source.alive and o._amputated then -- HOLLOW-GUT : l'amputation NOURRIT
        local heal = math.floor(o._amputated * r.amputateHealsMe + 0.5)
        if heal > 0 then r.source.hp = math.min(r.source.maxHp, r.source.hp + heal) end
      end
    end
    if r.remaining <= 0 then d.rot = nil end
  end

  -- CHOC : condensateur. Le tick n'inflige RIEN ; la DÉCHARGE (stacks × volt) se fait à la frappe
  -- (Arena:dischargeShock). Ici on n'écoule que la durée : non-déchargée à temps -> la charge se dissipe.
  local sh = d.shock
  if sh then
    sh.remaining = sh.remaining - frameDt
    if sh.remaining <= 0 then d.shock = nil end
  end

  -- REGEN (contre-DoT) : soin au fil du temps, accumulation entière.
  if u.regen > 0 and u.hp < u.maxHp then
    u.regenAcc = u.regenAcc + u.regen * (frameDt / 60)
    if u.regenAcc >= 1 then local n = math.floor(u.regenAcc); u.regenAcc = u.regenAcc - n
      u.hp = math.min(u.maxHp, u.hp + n) end
  end
end

-- BOUCLIER PÉRIODIQUE (framework payoff §3) : le porteur re-blinde ses cibles (figées au build) toutes les
-- `cd` frames. value cappée ×3 + cd planché 2 s AU BUILD ; SURCHARGE = cumul jusqu'à 2× (sinon refresh max) ;
-- RÉFLEXION posée sur la cible (mordue dans damage). Émet "shield_cast" (RENDER, golden-safe). Ordre ipairs.
function Arena:tickShieldCaster(u, frameDt)
  local sc = u.shieldCaster
  if not sc.targets then return end
  sc.cdLeft = sc.cdLeft - frameDt
  if sc.cdLeft > 0 then return end
  sc.cdLeft = sc.cd
  local cast = {}
  for _, w in ipairs(sc.targets) do
    if w.alive then
      if sc.overcharge then w.shield = math.min(sc.value * 2, w.shield + sc.value) -- SURCHARGE : s'accumule (cap 2×)
      else w.shield = math.max(w.shield, sc.value) end                              -- sinon : rafraîchit
      if w.shield > (w.maxShield or 0) then w.maxShield = w.shield end
      if sc.reflect > 0 then w.shieldReflect = sc.reflect end
      cast[#cast + 1] = w
    end
  end
  self.bus:emit("shield_cast", { caster = u, targets = cast, value = sc.value, overcharge = sc.overcharge })
end

function Arena:update(frameDt, t)
  self.t = t

  for _, u in ipairs(self.units) do
    if u.alive then
      self:tickDots(u, frameDt) -- statuts (burn/bleed/poison/rot/choc/regen) + recompute des malus
      if u.shieldCaster then self:tickShieldCaster(u, frameDt) end -- bouclier périodique (framework payoff)
    end

    if u.alive then
      if not (u.target and u.target.alive) then u.target = self:chooseTarget(u) end

      -- Le timer s'écoule en continu : le cooldown EST l'intervalle entre deux frappes.
      u.atkTimer = u.atkTimer - frameDt
      if not u.swinging and u.target and u.atkTimer <= 0 then
        u.swinging = true; u.swingAge = 0; u.swingHit = false
        u.atkTimer = u.cd * (1 + u.atkSlow) -- bleed ralentit la cadence
        u.target = self:chooseTarget(u)
        self.bus:emit("attack", u) -- le render joue l'anim d'attaque
        local blz = u.dots.bleed -- BLOODLETTER : le saignement ÉCLATE quand la cible agit (aggravate)
        if blz and blz.aggravateMult then
          local burst = math.floor((blz.dps or 0) * blz.aggravateMult + 0.5)
          if burst > 0 then self:damage(u, burst, { ignoreShield = true, cause = "bleed", source = blz.source }) end
        end
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

  -- FATIGUE (enrage) : usure globale croissante passé le seuil, jusqu'à conclusion. Gated sur les vraies
  -- batailles (la démo en boucle s'arrête à 0 via resetTimer, jamais fatiguée). Résolue APRÈS les frappes
  -- et AVANT le broadcast on_death -> les morts d'usure sont traitées dans la même frame. `silent` : pas de
  -- nombre flottant ni de record "damage" (l'usure n'entre pas dans les stats de dégâts) ; la mort, elle,
  -- est émise normalement (l'unité s'effondre à l'écran). Déterministe.
  if not self.autoReset then
    local ft = self.fatigue
    local start = (ft and ft.start) or FATIGUE_START
    if self.t >= start then
      local dps = ((ft and ft.base) or FATIGUE_BASE) + ((ft and ft.ramp) or FATIGUE_RAMP) * (self.t - start)
      for _, u in ipairs(self.units) do
        if u.alive then
          u.fatigueAcc = (u.fatigueAcc or 0) + dps * (frameDt / 60)
          if u.fatigueAcc >= 1 then
            local n = math.floor(u.fatigueAcc); u.fatigueAcc = u.fatigueAcc - n
            self:damage(u, n, { ignoreShield = true, silent = true, cause = "fatigue" })
          end
        end
      end
    end
  end

  -- on_death : broadcast DIFFÉRÉ (hors du chemin réentrant hit/tick), ctx dédié. Les ops de propagation
  -- ne posent que des DoT (jamais de dégât immédiat) -> aucune cascade de mort pendant le drain.
  if #self.deaths > 0 then
    local dctx = self.deathCtx
    for di = 1, #self.deaths do
      local dead = self.deaths[di]
      dctx.arena, dctx.victim = self, dead
      for _, w in ipairs(self.units) do
        if w.alive and w.team ~= dead.team and w.effects then
          dctx.source = w
          Effects.run(w, "on_death", dctx)
        end
      end
    end
    for di = #self.deaths, 1, -1 do self.deaths[di] = nil end
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

-- Constante exposée (lecture seule) : les tests/le lab s'y réfèrent (seuil de déclenchement de la Fatigue).
Arena.FATIGUE_START = FATIGUE_START

return Arena
