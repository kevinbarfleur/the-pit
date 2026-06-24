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

local ArenaDraw = {}
ArenaDraw.__index = ArenaDraw

function ArenaDraw.new(arena, palette)
  local self = setmetatable({
    arena = arena, palette = palette,
    rigs = {},       -- [unit] = char (rig)
    dead = {},       -- [unit] = age (fondu de mort, géré côté render)
    dmgNumbers = {}, -- nombres flottants
    impacts = {},    -- étincelles d'impact
    shake = { x = 0, y = 0, mag = 0 }, -- P2.2 : offset render-local du transform monde (décroît dans update)
    flash = {},      -- P2.2 : [unit] = age (flash blanc bref du rig touché)
    deathFx = {},    -- P2.3 : { x, y, age } flashs de case de mort (rouge -> fondu)
    dparts = {},     -- P2.3 : particules de mort (sang/débris sombres) {x,y,vx,vy,ay,age,life,col,size}
    fxN = 0,         -- compteur Weyl (dispersion cosmétique déterministe)
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
    -- P2.2 — POIDS DU COUP : un coup qui mord les PV secoue le monde (∝ dégât, clampé) + flashe la cible en
    -- blanc. Seuls les coups un peu lourds (>=3 PV) déclenchent le shake -> les tics de DoT ne font pas trembler.
    if n >= 3 then
      local mag = math.min(SHAKE_MAX, n * SHAKE_PER_HP)
      if mag > self.shake.mag then self.shake.mag = mag end -- garde le plus gros choc en cours
    end
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
      local spec = Units[u.id] or {}
      def = CreatureGen.cached({ id = u.id, type = spec.type, family = spec.family, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
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
  love.graphics.setColor(mine[1], mine[2], mine[3], 0.05)
  love.graphics.ellipse("fill", CX - 62, 118, 70, 32)
  love.graphics.setColor(theirs[1], theirs[2], theirs[3], 0.05)
  love.graphics.ellipse("fill", CX + 62, 118, 70, 32)

  -- 3) Couture verticale de ligne de front en x=160 (y≈55..150) : trait de sang + colonne de lueur qui
  -- RESPIRE (alpha via sin(t)) -> l'œil va à la frontière où les camps s'affrontent.
  local breathe = 0.5 + 0.5 * math.sin((self.t or 0) * 0.04) -- 0..1
  local bl = C.blood
  -- Colonne de lueur (large, douce) : pulse de présence au milieu du champ.
  love.graphics.setColor(bl[1], bl[2], bl[3], 0.06 + 0.05 * breathe)
  love.graphics.rectangle("fill", CX - 6, 55, 12, 95)
  -- Trait franc de la couture.
  love.graphics.setColor(bl[1], bl[2], bl[3], 0.18)
  love.graphics.rectangle("fill", CX, 55, 1, 95)

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
    Rig.draw(rig)
    -- P2.2 — flash blanc bref : on RE-TRACE le rig en blanc additif (tint render-local restauré juste après).
    -- `Rig.draw` impose sa propre couleur -> on passe par son canal `anim.tint`/`char.alpha` (recalculés à
    -- chaque update, donc cette mutation transitoire DANS draw est sans incidence sur la frame suivante).
    local fa = self.flash[u]
    if fa then self:drawRigFlash(rig, 1 - fa / FLASH_DUR) end
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
