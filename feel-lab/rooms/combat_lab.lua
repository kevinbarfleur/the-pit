-- feel-lab/rooms/combat_lab.lua
-- ╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  COMBAT LAB — substrat pour refondre (1) les CHIFFRES DE DÉGÂTS et (2) les VFX D'ATTAQUE par type.  ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝
--
-- Cette room fait tourner un VRAI combat avec de VRAIES créatures (le code de src/ recopié dans feel-lab/src/),
-- et offre des points de branchement PROPRES où game-feel-engineer (chiffres + mouvement) et pixel-art-master
-- (sprites d'attaque) viendront greffer plusieurs propositions. Elle ne DESIGNE pas les chiffres/VFX finaux :
-- elle fournit la SCÈNE, les INTERFACES (rooms/dmgnumbers.lua + rooms/attackvfx.lua) et une baseline.
--
-- ── CE QUI TOURNE ICI ──────────────────────────────────────────────────────────────────────────────────
--   • SIM PURE & SEEDÉE : src.combat.arena (Arena.new{left,right,seed}) -> replay identique (déterministe).
--   • Compo CURATÉE 4v4 qui exerce TOUS les types de dégâts (vérifié headless, cf. RAPPORT) :
--       gauche  : marauder(attack) · emberling(burn) · stormcaller(shock) · witch(poison)
--       droite  : razorkin(bleed)  · rot_hound(rot)  · bandit(attack)     · skeleton(attack+thorns)
--   • RENDU CRÉATURES : src.render.critter (déplacement par pixel : idle/atk/hurt/death), anims pilotées par
--     le BUS de l'arène (attack->atk, hit->hurt, death->death ; priorité death>hurt>atk). MÊME ancrage/échelle
--     que le jeu (place.pos pour x,y ; WORLD_FIT). On NE dessine PAS les chiffres/VFX du jeu ici : ils sont
--     remplacés par les deux couches SWAPPABLES (le coeur du chantier).
--   • Deux couches branchées sur le bus ET sur le banc manuel :
--       self.dmg  (rooms.dmgnumbers) reçoit un `spawn{x,y,val,cause,source,target}` à chaque event `damage`.
--       self.vfx  (rooms.attackvfx)  reçoit un `emit{fromX,fromY,toX,toY,cause,connectAt}` à chaque `attack`.
--
-- ── FIREWALL ───────────────────────────────────────────────────────────────────────────────────────────
--   SIM = src.* (zéro love.graphics). RENDER = critter + les 2 couches + cette room. La room ne MUTE jamais
--   la sim ; elle LIT arena.units (x/y/alive/hp) et ÉCOUTE le bus. Combat avancé à pas FIXE (frameDt=1, t++).

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")
local Juice   = require("lib.juice")
local SFX     = require("lib.sfx")

-- SIM + RENDER réels (copie isolée dans feel-lab/src/ — l'original src/ reste intact)
local Arena   = require("src.combat.arena")
local Units   = require("src.data.units")
local Place   = require("src.combat.place")
local Critter = require("src.render.critter")
local WORLD_FIT = require("src.gen.primgen").WORLD_FIT

-- les deux INTERFACES DE BRANCHEMENT (substrat du chantier)
local DmgNumbers = require("rooms.dmgnumbers")
local AttackVFX  = require("rooms.attackvfx")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720

-- ── Constantes de timing de la sim (alignées sur src/combat/arena.lua) ─────────────────────────────────
-- La frappe CONNECTE à mi-swing : SWING_DUR=35 frames, CONNECT_AT=0.5 -> 17.5 frames -> ~0.29 s @60fps.
-- On passe cet instant à attackvfx via `connectAt` (en SECONDES) pour caler l'impact sur le coup réel.
local CONNECT_AT_S = (35 * 0.5) / 60

-- Compo curatée : ids RÉELS (vérifiés dans src/data/units.lua) + une CASE (col,row) sur la grille 3×3 du jeu,
-- EXACTEMENT comme src/data/encounters.lua (col 0..2 : 2 = FRONT, proche du centre ; row 0..2 : haut→bas).
-- FORMATION 2×2 LISIBLE par équipe : ligne de FRONT (col 2, bruisers) + ligne ARRIÈRE (col 1, carries/DoT),
-- rows {0,2} -> deux camps nets qui se font face (mêmes conventions que le vrai board, cf. Place.pos/bounds).
--   gauche : marauder(attack, front) · skeleton(attack+thorns, front) ‖ stormcaller(shock) · witch(poison)
--   droite : razorkin(bleed, front) · bandit(attack, front) ‖ emberling(burn) · rot_hound(rot)
-- ⟹ couvre attack/burn/shock/poison/bleed/rot, et chaque équipe a un MUR devant + des lanceurs derrière.
local LEFT_COMP = {
  { id = "marauder",   col = 2, row = 0 }, { id = "skeleton", col = 2, row = 2 }, -- FRONT (mur)
  { id = "stormcaller",col = 1, row = 0 }, { id = "witch",    col = 1, row = 2 }, -- ARRIÈRE (shock / poison)
}
local RIGHT_COMP = {
  { id = "razorkin",   col = 2, row = 0 }, { id = "bandit",   col = 2, row = 2 }, -- FRONT (mur)
  { id = "emberling",  col = 1, row = 0 }, { id = "rot_hound",col = 1, row = 2 }, -- ARRIÈRE (burn / rot)
}
local SEED = 0xC0FFEE  -- seed FIXE du combat -> replay identique au reset

-- Banc manuel : un bouton par TYPE de dégât. Valeur d'exemple par type (lisible, pas un vrai calcul de sim).
local BENCH_TYPES = {
  { cause = "attack", label = "PHYS",  val = 12 },
  { cause = "burn",   label = "FIRE",  val = 8  },
  { cause = "shock",  label = "BOLT",  val = 9  },
  { cause = "poison", label = "POISON",val = 6  },
  { cause = "bleed",  label = "BLEED", val = 5  },
  { cause = "rot",    label = "ROT",   val = 7  },
}

-- ── Construction de l'arène (réutilisée par reset/replay) — MIROIR EXACT du vrai jeu ───────────────────
-- `entries` = liste {id, col, row}. On reproduit FIDÈLEMENT src/scenes/build.lua:1703-1735 :
--   · bounds calculés sur TOUTE la liste (étalement adaptatif x ET y) ;
--   · x,y MONDE via Place.pos(col,row,side,b) (front = plus grand col, proche du centre x=160) ;
--   · depth = b.maxC - col (0 = front) -> exposition portée par la forme, ciblage déterministe correct ;
--   · facing = side (-1 = équipe gauche regarde à DROITE / +1 = droite regarde à GAUCHE) -> elles se font face.
local function buildComp(entries, side)
  local b = Place.bounds(entries)
  local out = {}
  for i, e in ipairs(entries) do
    local u = Units[e.id]
    local x, y = Place.pos(e.col, e.row, side, b)
    out[i] = {
      id = e.id, hp = u.hp, dmg = u.dmg, cd = u.cd, shield = u.shield or 0,
      aggro = u.aggro, taunt = u.taunt, effects = u.effects,
      depth = b.maxC - e.col, row = e.row, x = x, y = y, facing = side,
    }
  end
  return out
end

function Room.new(app)
  local self = setmetatable({
    app = app, mx = -1, my = -1, click = nil, t = 0,
    timeScale = 1,        -- multiplicateur de vitesse de combat (0 = pause)
    paused = false,
    stepOnce = false,     -- demande d'avancer d'UN pas (mode pause)
    -- état d'anim RENDER-local par unité : { state="idle"|"atk"|"hurt"|"death", age } (cf. arena_draw.setAnim)
    anim = {},
    dead = {},            -- [unit] = age (fondu de mort, géré côté render)
    -- deux JETONS du banc manuel (émetteur factice -> receveur factice), en coords MONDE virtuel. Posés dans
    -- une LANE LIBRE et ENCADRÉE en haut-gauche (sous le transport, à GAUCHE de l'arène) -> on voit le trajet
    -- FROM->TO en ISOLATION, à l'écart total du combat et du bandeau de banc en bas. (design ×4 : ~(96,300)->(232,300).)
    benchFrom = { x = 24, y = 75 },
    benchTo   = { x = 58, y = 75 },
  }, Room)
  -- couches swappables (variante A par défaut). game-feel/pixel-art ajoutent B/C dans leurs modules.
  self.dmg = DmgNumbers.new("A")
  self.vfx = AttackVFX.new("A")
  self:resetCombat()
  return self
end

function Room:enter() self.title = "Combat Lab" end

-- (Re)crée l'arène SEEDÉE + recâble les abonnements bus -> RENDER. Appelé au démarrage et au Replay/Reset.
function Room:resetCombat()
  self.anim, self.dead = {}, {}
  self.dmg:clear(); self.vfx:clear()
  self.simT = 0
  self.arena = Arena.new({
    left = buildComp(LEFT_COMP, -1), right = buildComp(RIGHT_COMP, 1),
    seed = SEED, autoReset = false,
  })
  local bus = self.arena.bus

  -- attack : arme l'anim d'attaque ET pose un VFX d'attaque (émetteur=attaquant -> sa cible courante).
  bus:on("attack", function(u)
    self:setAnim(u, "atk")
    local tgt = self:targetOf(u)
    if tgt then
      self.vfx:emit({
        fromX = u.x, fromY = u.y - 12, toX = tgt.x, toY = tgt.y - 12,
        cause = "attack", connectAt = CONNECT_AT_S, val = u.dmg or 8, -- val -> dose le jus d'impact du VFX
      })
    end
  end)

  -- hit : la cible encaisse (anim hurt). (L'impact visuel est porté par le VFX d'attaque à connectAt.)
  bus:on("hit", function(a, target) self:setAnim(target, "hurt") end)

  -- damage : la voie MAÎTRESSE -> un CHIFFRE de la bonne cause sur la cible (uniquement la part qui mord les PV).
  bus:on("damage", function(rec)
    local n = rec.hp
    if not (n and n > 0) then return end
    local tgt = rec.target
    self.dmg:spawn({
      x = (tgt and tgt.x) or 160, y = ((tgt and tgt.y) or 96) - 26,
      val = n, cause = rec.cause or "attack", source = rec.source, target = tgt,
    })
    -- ANTI-SHAKE (retour user : screen-shake CATASTROPHIQUE en 4v4) : on NE secoue PLUS l'écran par coup ici
    -- (le trauma ∝ val s'empilait sur les frappes simultanées). Le « poids » du coup est désormais 100% LOCAL,
    -- porté par la couche VFX (impactJuice : squash du rig cible + secousse CAPPÉE réservée aux gros crits).
  end)

  -- death : latch l'anim de mort (la créature se désagrège, priorité absolue).
  bus:on("death", function(u) if u then self:setAnim(u, "death") end end)
end

-- ── Ciblage : on relit la cible déterministe de la sim pour orienter le VFX d'attaque (LECTURE seule). ──
function Room:targetOf(u)
  if self.arena.chooseTarget then
    local ok, t = pcall(self.arena.chooseTarget, self.arena, u)
    if ok and t then return t end
  end
  -- repli : l'ennemi vivant le plus proche en x (jamais utilisé en pratique, chooseTarget répond).
  local best, bd
  for _, e in ipairs(self.arena.units) do
    if e.alive and e.team ~= u.team then
      local d = math.abs(e.x - u.x)
      if not bd or d < bd then best, bd = e, d end
    end
  end
  return best
end

-- ── Commutation d'état d'anim RENDER-local (port direct de arena_draw.setAnim) ─────────────────────────
local ANIM_PRIO = { idle = 0, atk = 1, hurt = 2, death = 3 }
local CR_ATK_DUR, CR_HURT_DUR, CR_DEATH_DUR = 63, 27, 72 -- frames (1.05 / 0.45 / 1.2 s @60, cf. arena_draw)
function Room:setAnim(u, state)
  if not (u and Critter.has and Critter.has(u.id)) then return end
  local a = self.anim[u]
  if not a then a = { state = "idle", age = 0 }; self.anim[u] = a end
  if a.state == "death" then return end -- mort = définitif (latch)
  if state == "atk" and a.state == "hurt" and a.age < CR_HURT_DUR then return end -- le coup reçu prime
  if ANIM_PRIO[state] >= ANIM_PRIO[a.state] or a.state == "idle" then a.state, a.age = state, 0 end
end

-- ─────────────────────────────────────────── UPDATE ───────────────────────────────────────────────────
function Room:update(dt)
  self.t = self.t + (dt or 0)

  -- AVANCE DE LA SIM : pas FIXE (frameDt=1, t++). On dérive le nombre de pas du timeScale (slow-mo / 2× / pause).
  -- En pause, on n'avance QUE si stepOnce a été demandé (un seul pas). En slow-mo, on n'avance qu'une fraction
  -- du temps (accumulateur) -> mouvement ralenti SANS désynchroniser la sim (qui reste à pas entier).
  local steps = 0
  if self.arena.over then
    steps = 1 -- continue d'avancer 1 pas (anims de mort) une fois conclu
  elseif self.paused then
    if self.stepOnce then steps = 1; self.stepOnce = false end
  else
    self._acc = (self._acc or 0) + (self.timeScale or 1)
    steps = math.floor(self._acc)
    self._acc = self._acc - steps
  end
  for _ = 1, steps do
    self.simT = self.simT + 1
    self.arena:update(1, self.simT) -- SIM (émet attack/hit/damage/death sur le bus -> nos couches réagissent)
    if self.arena.over then break end
  end

  -- frameDt RENDER : pour les anims de créatures + les couches, on avance au RYTHME de la sim (ralenti compris).
  -- En pause sans step, frameDt=0 -> tout gèle (lisibilité). 1 pas de sim = 1 frame d'anim.
  local frameDt = steps

  -- avance l'état d'anim de chaque créature (atk/hurt retombent en idle ; death reste figée à son âge max).
  for _, u in ipairs(self.arena.units) do
    local an = self.anim[u]
    if an and an.state ~= "idle" then
      an.age = an.age + frameDt
      if an.state == "atk" and an.age >= CR_ATK_DUR then an.state, an.age = "idle", 0
      elseif an.state == "hurt" and an.age >= CR_HURT_DUR then an.state, an.age = "idle", 0 end
    end
    -- fondu de mort (état purement visuel) : une unité tombée s'efface en ~40 frames.
    if not u.alive then self.dead[u] = (self.dead[u] or 0) + frameDt end
  end

  -- couches swappables : avancées au rythme sim aussi (cohérence du ralenti). Le banc manuel les nourrit
  -- indépendamment du combat -> on les fait vivre AUSSI en temps réel (sinon le banc gèle en pause de combat).
  local layerDt = math.max(frameDt, (dt or 0) * 60 * 0.0) -- en pratique = frameDt ; seam si on veut découpler.
  self.dmg:update(frameDt > 0 and frameDt or 0)
  self.vfx:update(frameDt > 0 and frameDt or 0)
  -- les instances du banc manuel doivent vivre même combat en pause -> on rejoue un petit dt réel quand gelé.
  if frameDt == 0 then
    local rt = math.min(2, (dt or 0) * 60)
    self.dmg:update(rt); self.vfx:update(rt)
  end

  -- (les boutons gèrent leur survol via l'input passé au draw — rien à pré-armer ici.)

  -- BANC MANUEL : les chiffres programmés apparaissent à l'IMPACT (= connectAt), pas à l'emit -> on décompte
  -- leur délai en TEMPS RÉEL (secondes), indépendamment de la pause du combat (le banc doit toujours répondre).
  if self._pendingNums and #self._pendingNums > 0 then
    for i = #self._pendingNums, 1, -1 do
      local p = self._pendingNums[i]
      p.at = p.at - (dt or 0)
      if p.at <= 0 then
        self.dmg:spawn({ x = p.x, y = p.y, val = p.val, cause = p.cause, source = nil, target = nil })
        table.remove(self._pendingNums, i)
      end
    end
  end
end

-- ─────────────────────────────────────────── DRAW ─────────────────────────────────────────────────────
function Room:draw(view)
  -- 1) MONDE (combat) en transform ×4 : sol + créatures + couches. On reste sous Draw.begin pour rester
  --    cohérent avec le pipeline du lab (texte net), puis on scale ×4 pour l'espace MONDE virtuel 320×180.
  Draw.begin(view)
  love.graphics.push()
  love.graphics.scale(4, 4) -- espace MONDE virtuel (u.x,u.y) -> design (cohérent avec les couches qui font ×4)
  self:drawFloor()
  self:drawCreatures()
  love.graphics.pop()
  Draw.finish()

  -- 1b) NOMS d'unité (espace DESIGN, texte net) — au-dessus de chaque créature : on lit QUI est qui / qui
  --     attaque. Port allégé de arena_draw.drawOverlay (sans barres de vie : le lab se concentre sur dmg/vfx).
  Draw.begin(view)
  self:drawNames()
  Draw.finish()

  -- 2) COUCHES SWAPPABLES (gèrent elles-mêmes leur Draw.begin + ×4) — au-dessus des créatures.
  self.vfx:draw(view) -- VFX d'attaque (trajet + impact)
  self.dmg:draw(view) -- chiffres de dégâts

  -- 3) UI de contrôle (espace DESIGN, texte net) PAR-DESSUS.
  Draw.begin(view)
  self:drawBenchLabels()
  self:drawControls(view)
  Draw.finish()
  self.click = nil
end

-- Sol de fosse minimal (repère de scène, NON secoué) — version épurée de arena_draw.drawArena.
function Room:drawFloor()
  local CX = 160
  love.graphics.setLineStyle("rough"); love.graphics.setLineWidth(1)
  local fl = c.stone850
  love.graphics.setColor(fl[1], fl[2], fl[3], 0.6); love.graphics.ellipse("fill", CX, 118, 130, 34)
  local rim = c.brassD
  love.graphics.setColor(rim[1], rim[2], rim[3], 0.4); love.graphics.ellipse("line", CX, 118, 130, 34)
  -- couture de ligne de front (respire), pure ambiance.
  local breathe = 0.5 + 0.5 * math.sin(self.t * 2.2)
  local bl = c.blood
  love.graphics.setColor(bl[1], bl[2], bl[3], 0.022 + 0.018 * breathe)
  love.graphics.rectangle("fill", CX - 4, 62, 8, 84)
  love.graphics.setColor(1, 1, 1, 1)
end

-- CARTES D'ÉQUIPE (port de arena_draw.drawGrid) : un panneau SOMBRE teinté équipe (bleu=gauche / rouge=droite)
-- ENCADRE chaque unité vivante -> on lit d'un coup d'œil les deux formations qui se font face (c'est l'élément
-- clé qui fait « ressembler au vrai jeu »). Dessiné SOUS les créatures. Mêmes dimensions que le jeu (W,H = pas
-- de Place=30) -> les cartes se jointoient en grille propre par équipe.
function Room:drawTeamCards()
  local CW, CH = 28, 30
  love.graphics.setLineStyle("rough"); love.graphics.setLineWidth(1)
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      local left = (u.team == "left")
      local x = math.floor(u.x - CW / 2)
      local y = math.floor(u.y + 2 - CH) -- la carte ENCADRE le monstre (tête en haut, pieds en bas)
      local r1, g1, b1, r2, g2, b2
      if left then r1, g1, b1, r2, g2, b2 = 0.06, 0.09, 0.14, 0.03, 0.05, 0.09  -- bleu (joueur)
      else r1, g1, b1, r2, g2, b2 = 0.12, 0.06, 0.07, 0.06, 0.03, 0.04 end       -- rouge (adverse)
      for i = 0, 2 do
        local t = i / 2
        love.graphics.setColor(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, 0.40)
        love.graphics.rectangle("fill", x, y + math.floor(i * CH / 3), CW, math.ceil(CH / 3))
      end
      -- liseré MUET (fer teinté équipe) + ligne de base un peu plus marquée (pose l'unité au sol).
      if left then love.graphics.setColor(0.24, 0.29, 0.39, 0.50) else love.graphics.setColor(0.39, 0.23, 0.25, 0.50) end
      love.graphics.rectangle("line", x, y, CW, CH)
      if left then love.graphics.setColor(0.30, 0.38, 0.52, 0.55) else love.graphics.setColor(0.52, 0.28, 0.30, 0.55) end
      love.graphics.line(x, y + CH, x + CW, y + CH)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- NOM affiché lisible depuis l'id (le lab n'embarque pas l'i18n du jeu) : « rot_hound » -> « Rot Hound ».
local function prettyName(id)
  return (id:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

-- Noms d'unité au-dessus des créatures vivantes (DESIGN ×4, texte net), teintés par équipe. Réutilise les
-- coords MONDE u.x,u.y comme arena_draw.drawOverlay (×4 -> design). Discret : ne couvre pas les chiffres.
function Room:drawNames()
  local font = Theme.labelSmall(9)
  local fh = font and font:getHeight() or 9
  for _, u in ipairs(self.arena.units) do
    if u.alive then
      local col = (u.team == "left") and c.shield or c.bloodL
      local ny = (u.y - 33) * 4 - fh - 1 -- au-dessus de la carte d'équipe (haut de carte ≈ u.y-28 ; marge de respiration)
      Draw.textC(prettyName(u.id), u.x * 4, ny, { col[1], col[2], col[3], 0.85 }, font)
    end
  end
end

-- Créatures vivantes via Critter (idle/atk/hurt/death) + ombre au sol + le banc manuel (2 jetons).
function Room:drawCreatures()
  self:drawTeamCards() -- repères de slots par équipe (derrière ombres + unités) — donne les 2 formations lisibles

  -- ombres au sol (ancre la baseline ; les flottants laissent leur ombre au sol)
  for _, u in ipairs(self.arena.units) do
    local a = u.alive and 0.5 or 0.5 * math.max(0, 1 - (self.dead[u] or 0) / 40)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.ellipse("fill", u.x, u.y + 2, 8, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)

  local ts = (self.simT or 0) / 60 -- horloge d'idle/yeux de critter en SECONDES
  for _, u in ipairs(self.arena.units) do
    local opts = self:critterOpts(u)
    Critter.drawAt(nil, u.id, u.x, u.y, WORLD_FIT, ts, Critter.facingFor(u.id, u.facing or 1), opts)
  end

  -- BANC MANUEL : deux jetons « émetteur » / « receveur » (cibles factices pour itérer un effet isolé).
  self:drawBenchTokens()
end

-- Construit les opts Critter depuis l'état d'anim render-local (port de arena_draw.drawCritter, sans le rig baké).
function Room:critterOpts(u)
  local rig = (self._crCache or {})[u.id]
  if not rig then
    self._crCache = self._crCache or {}
    rig = { atk = Critter.atkFor(u.id) or false, hurt = Critter.hurtFor(u.id) or "recoil", death = Critter.deathFor(u.id) or "gib" }
    self._crCache[u.id] = rig
  end
  local an = self.anim[u]
  local opts
  if an and an.state ~= "idle" then
    if an.state == "atk" and rig.atk then
      opts = { shadow = false, atk = { k = rig.atk.k, pr = rig.atk, ph = math.min(1, an.age / CR_ATK_DUR) } }
    elseif an.state == "hurt" then
      opts = { shadow = false, hurt = { k = rig.hurt, ph = math.min(1, an.age / CR_HURT_DUR) } }
    elseif an.state == "death" then
      opts = { shadow = false, death = { k = rig.death, ph = math.min(1, an.age / CR_DEATH_DUR), noFx = true }, alpha = 1 }
    end
  end
  if not opts then opts = { shadow = false } end
  if opts.alpha == nil then opts.alpha = u.alive and 1 or math.max(0, 1 - (self.dead[u] or 0) / 40) end
  return opts
end

-- SANDBOX du banc, dessinée en MONDE (le trait du VFX d'attaque relie FROM->TO). Cadre discret + flèche
-- directionnelle évidente -> on comprend d'un coup le SENS de l'effet (émetteur -> receveur), à l'écart du combat.
function Room:drawBenchTokens()
  local f, t = self.benchFrom, self.benchTo
  -- cadre de la lane (encadre les 2 jetons + un peu de marge) -> « zone d'essai isolée », pas un orphelin.
  local x0, y0, x1 = f.x - 12, f.y - 16, t.x + 12
  love.graphics.setColor(c.stone850[1], c.stone850[2], c.stone850[3], 0.55)
  love.graphics.rectangle("fill", x0, y0, x1 - x0, 34)
  love.graphics.setColor(c.brassD[1], c.brassD[2], c.brassD[3], 0.7)
  love.graphics.setLineWidth(1); love.graphics.rectangle("line", x0, y0, x1 - x0, 34)
  -- FLÈCHE FROM->TO (sens évident) : trait + pointe.
  love.graphics.setColor(c.ink3[1], c.ink3[2], c.ink3[3], 0.8)
  love.graphics.line(f.x + 6, f.y, t.x - 6, t.y)
  love.graphics.polygon("fill", t.x - 6, t.y - 3, t.x - 6, t.y + 3, t.x - 1, t.y) -- pointe vers TO
  -- jetons : FROM (bleu, émetteur) / TO (rouge, receveur).
  for _, tok in ipairs({ { f, c.shield }, { t, c.blood } }) do
    local p, col = tok[1], tok[2]
    love.graphics.setColor(col[1], col[2], col[3], 0.25); love.graphics.circle("fill", p.x, p.y, 5)
    love.graphics.setColor(col[1], col[2], col[3], 0.9); love.graphics.circle("line", p.x, p.y, 5)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- libellés FROM/TO du banc, en DESIGN (×4) pour rester nets. Au-DESSUS de la lane (la lane est en haut-gauche).
function Room:drawBenchLabels()
  Draw.textC("EMITTER -> TARGET (bench)", (self.benchFrom.x + self.benchTo.x) / 2 * 4, self.benchFrom.y * 4 - 26, c.ink4, Theme.label(10))
  Draw.textC("FROM", self.benchFrom.x * 4, self.benchFrom.y * 4 + 8, c.shield, Theme.labelSmall(9))
  Draw.textC("TO",   self.benchTo.x   * 4, self.benchTo.y   * 4 + 8, c.blood,  Theme.labelSmall(9))
end

-- ─────────────────────────────────────────── CONTRÔLES (UI) ───────────────────────────────────────────
-- Layout statique (espace DESIGN). Bandeau gauche = transport (replay/pause/step/slow-mo/2×) ; bandeau bas =
-- BANC MANUEL (1 bouton/type) ; bandeau droit = SÉLECTEURS de proposition (chiffres + VFX).
function Room:rects()
  local R = {}
  -- transport (haut-gauche)
  R.replay = { x = 24,  y = 64,  w = 120, h = 38 }
  R.pause  = { x = 152, y = 64,  w = 90,  h = 38 }
  R.step   = { x = 250, y = 64,  w = 90,  h = 38 }
  R.slow   = { x = 24,  y = 110, w = 100, h = 34 }
  R.norm   = { x = 132, y = 110, w = 100, h = 34 }
  R.fast   = { x = 240, y = 110, w = 100, h = 34 }
  -- banc manuel (bas) : 6 boutons de type
  local bw, bh, gap = 150, 44, 12
  local total = bw * #BENCH_TYPES + gap * (#BENCH_TYPES - 1)
  local x0 = W / 2 - total / 2
  for i = 1, #BENCH_TYPES do R["bench" .. i] = { x = x0 + (i - 1) * (bw + gap), y = H - 84, w = bw, h = bh } end
  return R
end

-- variantes : on calcule leurs rects à part (rangées) pour rester lisible
function Room:variantRects()
  local dn, av = {}, {}
  local bw, bh, gap = 104, 30, 8
  local x = W - 24 - (bw * 3 + gap * 2)
  for i, v in ipairs(DmgNumbers.VARIANTS) do dn[i] = { id = v.id, name = v.name, r = { x = x + (i - 1) * (bw + gap), y = 80,  w = bw, h = bh } } end
  for i, v in ipairs(AttackVFX.VARIANTS)  do av[i] = { id = v.id, name = v.name, r = { x = x + (i - 1) * (bw + gap), y = 140, w = bw, h = bh } } end
  return dn, av, x
end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

function Room:drawControls(view)
  local R = self:rects()

  -- ── TRANSPORT ────────────────────────────────────────────────────────────────────────────────────────
  Draw.textTrackedL("TRANSPORT", 24, 46, c.gold, Theme.subhead(13), 2)
  Widgets.button("cl_replay", R.replay, { label = "Replay", tone = "cta", font = Theme.title(15),
    onClick = function() self:resetCombat(); SFX.play("whoosh") end }, self:input(R.replay))
  Widgets.button("cl_pause", R.pause, { label = self.paused and "Resume" or "Pause", tone = "default", font = Theme.title(14),
    onClick = function() self.paused = not self.paused end }, self:input(R.pause))
  Widgets.button("cl_step", R.step, { label = "Step", tone = self.paused and "default" or "ghost", font = Theme.title(14),
    enabled = self.paused, onClick = function() self.stepOnce = true end }, self:input(R.step))
  -- vitesses : slow-mo (0.25×) / normal (1×) / 2× — l'actif est en CTA.
  local function spdBtn(id, r, label, val)
    local sel = math.abs((self.timeScale or 1) - val) < 0.01 and not self.paused
    Widgets.button(id, r, { label = label, tone = sel and "cta" or "default", font = Theme.label(13),
      onClick = function() self.timeScale = val; self.paused = false end }, self:input(r))
  end
  spdBtn("cl_slow", R.slow, "Slow 0.25x", 0.25)
  spdBtn("cl_norm", R.norm, "1x", 1)
  spdBtn("cl_fast", R.fast, "2x", 2)

  -- état du combat
  local status = self.arena.over and ("WINNER: " .. tostring(self.arena.win)) or
    string.format("t=%d  %s", self.simT or 0, self.paused and "PAUSED" or string.format("%.2gx", self.timeScale))
  Draw.text(status, 24, 152, c.ink3, Theme.label(12))

  -- ── SÉLECTEURS DE PROPOSITION ────────────────────────────────────────────────────────────────────────
  local dn, av, selX = self:variantRects()
  Draw.textTrackedL("DMG NUMBERS", selX, 64, c.gold, Theme.subhead(13), 2)
  for _, v in ipairs(dn) do
    local sel = (self.dmg:variantName() == v.id)
    Widgets.button("cl_dn_" .. v.id, v.r, { label = v.id, tone = sel and "cta" or "ghost", font = Theme.title(15),
      onClick = function() self.dmg:setVariant(v.id) end }, self:input(v.r))
  end
  Draw.textR("active: " .. self.dmg:variantName(), W - 24, 114, c.ink4, Theme.label(11))

  Draw.textTrackedL("ATTACK VFX", selX, 124, c.gold, Theme.subhead(13), 2)
  for _, v in ipairs(av) do
    local sel = (self.vfx:variantName() == v.id)
    Widgets.button("cl_av_" .. v.id, v.r, { label = v.id, tone = sel and "cta" or "ghost", font = Theme.title(15),
      onClick = function() self.vfx:setVariant(v.id) end }, self:input(v.r))
  end
  Draw.textR("active: " .. self.vfx:variantName(), W - 24, 174, c.ink4, Theme.label(11))

  -- ── BANC MANUEL ──────────────────────────────────────────────────────────────────────────────────────
  Draw.textTrackedC("MANUAL TRIGGER BENCH  ·  fire one isolated effect per type (emitter -> receiver)",
    W / 2, H - 108, c.gold, Theme.subhead(13), 1)
  for i, bt in ipairs(BENCH_TYPES) do
    local r = R["bench" .. i]
    local col = ({ attack = c.blood, burn = c.burn, shock = c.shock, poison = c.poison, bleed = c.bleed, rot = c.rot })[bt.cause]
    -- bouton coloré par type (ghost + liseré de la cause) ; au clic -> émet 1 VFX + 1 chiffre du type.
    local over = B.hit(r, self.mx, self.my)
    Draw.rrect(r.x, r.y, r.w, r.h, 7, over and c.stone700 or c.stone800, col, 2)
    Draw.textTrackedC(bt.label, r.x + r.w / 2, r.y + r.h / 2 - Theme.title(15):getHeight() / 2, col, Theme.title(15), 2)
    Draw.text("-" .. bt.val, r.x + 8, r.y + 5, c.ink4, Theme.label(10))
  end
  Draw.reset()
end

-- ── Banc manuel : tirer une instance isolée (1 VFX d'attaque + 1 chiffre) du type demandé. ──────────────
function Room:fireBench(bt)
  local f, t = self.benchFrom, self.benchTo
  -- val transmis au VFX -> dose le jus d'impact (squash/shake/particules) ET la taille cappée du chiffre.
  self.vfx:emit({ fromX = f.x, fromY = f.y, toX = t.x, toY = t.y, cause = bt.cause, connectAt = CONNECT_AT_S, val = bt.val })
  -- le chiffre apparaît à l'impact -> on programme un petit délai = connectAt (sinon il devance le VFX).
  self._pendingNums = self._pendingNums or {}
  self._pendingNums[#self._pendingNums + 1] = { at = CONNECT_AT_S, cause = bt.cause, val = bt.val, x = t.x, y = t.y - 14 }
  SFX.play("thud", { pitch = 0.9 + (bt.cause == "shock" and 0.2 or 0) })
  -- le shake d'impact est désormais porté par le VFX (impactJuice ∝ val) -> on n'empile plus un trauma fixe ici.
end

-- [TEMP CAPTURE] : peuple les deux couches dans (dnVariant, vfxVariant) avec un éventail de causes/montants,
-- échelonnés vers la même cible -> on JUGE le look des variantes au screenshot (pas de clic manuel requis).
-- Tire des chiffres directement (variés en cause/montant) + des VFX émetteur->cible. Retiré après revue.
function Room:demoFill(dnVariant, vfxVariant)
  self.dmg:setVariant(dnVariant); self.vfx:setVariant(vfxVariant)
  self.paused = true
  -- impacts répartis sur 6 positions cibles distinctes (un type chacun), émetteurs à GAUCHE -> on voit le BIAIS
  -- directionnel de chaque impact + l'identité par type. attack en 1re classe (crit, gros). connectAt court ->
  -- on avance jusqu'à l'éclosion pour figer l'impact mi-bloom au screenshot.
  local rows = {
    { cause = "attack", val = 15, crit = true, tx = 235, ty = 70 },
    { cause = "burn",   val = 9,            tx = 250, ty = 96 },
    { cause = "shock",  val = 12,           tx = 235, ty = 122 },
    { cause = "poison", val = 6,            tx = 150, ty = 70 },
    { cause = "bleed",  val = 4,            tx = 150, ty = 122 },
    { cause = "rot",    val = 8,            tx = 200, ty = 150 },
  }
  for i, r in ipairs(rows) do
    local fromX, fromY = 70, 110 -- émetteur commun à gauche -> biais directionnel lisible
    self.dmg:spawn({ x = r.tx, y = r.ty - 16, val = r.val, cause = r.cause, crit = r.crit,
      source = { x = fromX, y = fromY }, target = { id = "demo" .. i } })
    if r.cause == "burn" or r.cause == "poison" then -- 2e tic -> agrégation (variante A)
      self.dmg:spawn({ x = r.tx, y = r.ty - 16, val = 2, cause = r.cause, target = { id = "demo" .. i } })
    end
    self.vfx:emit({ fromX = fromX, fromY = fromY, toX = r.tx, toY = r.ty, cause = r.cause, crit = r.crit, connectAt = 0.08, val = r.val })
  end
  -- avance jusqu'à l'éclosion des impacts (connectAt 0.08 s ≈ 5 frames) + 2 frames de bloom (impact frais).
  for _ = 1, 7 do self.dmg:update(1); self.vfx:update(1) end
end

-- ── Entrée souris ──────────────────────────────────────────────────────────────────────────────────────
function Room:mousemoved(mx, my) self.mx, self.my = mx, my end
function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my; self.click = { x = mx, y = my }
  if button ~= 1 then return end
  -- banc manuel : test des 6 boutons (le draw consomme self.click pour les Widgets ; les bench sont dessinés à la main).
  local R = self:rects()
  for i, bt in ipairs(BENCH_TYPES) do
    if B.hit(R["bench" .. i], mx, my) then self:fireBench(bt); return end
  end
end

return Room
