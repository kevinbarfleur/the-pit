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

-- Durées des RÉACTIONS critter, en FRAMES (l'horloge de combat = frames @60fps ; le proto les donne en SECONDES :
-- ATK 1.05s / HURT 0.45s / DEATH 1.2s + DEAD_HOLD 0.7s — cf. docs/generation/generateur-bestiaire.html l.930).
-- La PHASE ph = age/DUR ∈ [0,1] (clampée). Après DEATH_DUR, la mort RESTE figée à ph=1 (corps désagrégé, alpha
-- déjà retombé) le temps du DEAD_HOLD : on laisse le fondu `self.dead` finir d'éteindre le sprite.
local CR_ATK_DUR = 63   -- 1.05 s × 60
local CR_HURT_DUR = 27  -- 0.45 s × 60
local CR_DEATH_DUR = 72 -- 1.2 s × 60

-- Nombres de dégâts flottants : trajectoire « feu d'artifice » (éjection vers le haut + dérive latérale +
-- gravité) et REGROUPEMENT des tics par (cible, auteur, cause) -> ils s'additionnent au lieu de s'empiler.
local DMG_LIFE = 55    -- durée de vie (frames)
local DMG_MERGE = 20   -- fenêtre de regroupement (frames) : un tic récent de même cible/auteur/cause s'ajoute
local DMG_VY0 = -1.35  -- vitesse verticale initiale (négatif = vers le haut)
local DMG_G = 0.05     -- gravité (le nombre retombe -> arc)

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
    shake = { x = 0, y = 0, mag = 0 }, -- P2.2 : offset render-local du transform monde (décroît dans update)
    flash = {},      -- P2.2 : [unit] = age (flash blanc bref du rig touché)
    deathFx = {},    -- P2.3 : { x, y, age } flashs de case de mort (rouge -> fondu)
    dparts = {},     -- P2.3 : particules de mort (sang/débris sombres) {x,y,vx,vy,ay,age,life,col,size}
    fxN = 0,         -- compteur Weyl (dispersion cosmétique déterministe)
    t = 0,           -- horloge de combat (mémorisée en update -> lue en draw pour les anims VFX)
    -- SON (RENDER pur, no-op headless) : on AGRÈGE l'intention de cue pendant les events bus (qui peuvent
    -- arriver par centaines/frame en SKIP) puis on joue AU PLUS UN « thud » + UN « death » par frame RENDER
    -- (throttle dans update). Évite le spam ET garde le coût audio borné. cf. firewall (audio = RENDER only).
    sndThud = 0,     -- plus grosse magnitude de coup vue cette frame (>0 -> on jouera 1 thud, pitch ∝ poids)
    sndDeaths = 0,   -- nb de morts vues cette frame (>0 -> on jouera 1 cue de mort, throttlé)
  }, ArenaDraw)
  self.fx = AfflictionFx.new() -- couche d'afflictions (créée avant rebuild, qui peut la reset)
  self:rebuild()
  -- Abonnements au bus de l'arène (la sim émet, le render réagit). Chaque évènement pilote À LA FOIS le Rig
  -- baké (6 main) ET l'état d'anim critter (générés) — un seul est ensuite dessiné par unité selon Critter.has.
  arena.bus:on("spawned", function() self:rebuild() end)
  arena.bus:on("attack", function(u)
    Rig.trigger(self:rigFor(u), "attack")
    self:setAnim(u, "atk") -- B.1b : armé seulement si pas déjà en hurt/death (priorité ; cf. setAnim)
  end)
  arena.bus:on("hit", function(a, target)
    Rig.trigger(self:rigFor(target), "hurt")
    self:setAnim(target, "hurt") -- B.1b : le coup reçu interrompt l'attaque, mais jamais la mort
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
    -- SON : seuls les coups un peu LOURDS « thud » (>= 8 PV) -> les tics de DoT ne sonnent jamais. On ne fait
    -- qu'AGRÉGER l'intention (la plus grosse magnitude de la frame) ; le cue réel est joué dans update (throttle
    -- 1/frame). Aucun appel love.* ici autre que via SFX (no-op headless). RENDER pur -> golden inchangé.
    if n >= 8 and n > self.sndThud then self.sndThud = n end
    if rec.target then self.flash[rec.target] = 0 end -- (re)arme le flash blanc sur la cible
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
function ArenaDraw:rebuild()
  self.rigs = {}; self.anim = {}; self.dead = {}; self.dmgNumbers = {}; self.impacts = {}
  self.shake = { x = 0, y = 0, mag = 0 }; self.flash = {}; self.deathFx = {}; self.dparts = {}
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
    d.x = d.x + (d.vx or 0) * frameDt              -- dérive latérale
    d.vy = (d.vy or 0) + DMG_G * frameDt           -- gravité
    d.y = d.y + d.vy * frameDt                     -- arc (monte puis retombe)
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

  self.fx:update(self.arena.units, frameDt, t) -- émission + intégration des particules d'affliction
end

-- SON (throttle 1/frame RÉELLE) : à appeler UNE fois par frame de la scène (PAS par pas de SIM ; en SKIP il y
-- a jusqu'à 240 pas/frame, mais on ne joue qu'UN « thud » + UN cue de mort par frame). Les compteurs sont
-- agrégés dans les callbacks bus (damage/death) puis CONSOMMÉS ici. RENDER pur : SFX.play est no-op headless
-- (pas de device audio) -> aucune empreinte SIM/golden. Le pitch du thud descend pour les coups plus lourds
-- (registre Oniric grave : plus c'est gros, plus c'est profond), borné pour rester doux.
function ArenaDraw:flushAudio()
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
  local W, H = 28, 30 -- ~ pas de la grille (Place CELL=30) -> les cases se jointoient en grille lisible
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
  local W, H = 28, 30
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
  -- ANCRAGE : pieds (grille 32,57) sur (u.x, u.y), échelle WORLD_FIT = MÊME empreinte que le Rig baké (pivot 32,58).
  -- t en SECONDES (self.t est en frames @60fps -> /60) pour l'idle/yeux de critter. facing = SENS D'ÉQUIPE (wantDir :
  -- joueur=+1 regarde à droite / adverse=-1 regarde à gauche) NORMALISÉ par le sens inhérent de la créature
  -- (facingFor) -> tout le monde se fait face quel que soit le faceDir natif de l'unité.
  Critter.drawAt(nil, u.id, u.x, u.y, WORLD_FIT, (self.t or 0) / 60, Critter.facingFor(u.id, u.facing or 1), opts)
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

  for _, u in ipairs(units) do
    local c = self.rigs[u]
    local a = u.alive and 0.5 or 0.5 * ((c and c.alpha) or 1)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.ellipse("fill", u.x, u.y + 2, 8, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for _, u in ipairs(units) do
    local rig = self:rigFor(u)
    if Critter.has(u.id) then
      -- B.1b — CRÉATURE GÉNÉRÉE : rendu VIVANT (critter). Même ancrage que le Rig (pieds à u.x/u.y, scale
      -- WORLD_FIT, espace virtuel) -> bascule sans déplacement. L'état d'anim render-local fournit la phase.
      self:drawCritter(u, rig)
    else
      -- 6 créatures DESSINÉES-MAIN : chemin Rig baké INCHANGÉ + flash blanc additif (re-tracé du rig touché).
      Rig.draw(rig)
      local fa = self.flash[u]
      if fa then self:drawRigFlash(rig, 1 - fa / FLASH_DUR) end
    end
  end

  -- Afflictions : matière (sang/spores/bulles/mouches) sur les rigs, puis glow additif (flammes/chaleur).
  self.fx:drawBody(units, self.t)
  self.fx:drawGlow(units, self.t)
  self:drawDeathParts() -- P2.3 : éclat de sang/débris de mort (additif léger), au-dessus des rigs

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
      local name = (Units[u.id] and T("unit." .. u.id .. ".name")) or u.id
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
