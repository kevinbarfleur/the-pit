-- src/scenes/animsheet.lua
-- PLANCHE DE CONTACT des animations de RÉACTION (attack / hurt / death), pour la revue au SCREENSHOT.
-- DEV / RENDER pur — montée uniquement par les fabriques d'export (--shoot=anim_attack/anim_death/anim_hurt),
-- jamais en jeu ni en headless. Affiche une grille de créatures choisies pour COUVRIR des kinds DIVERS, toutes
-- figées à une PHASE constante de leur évènement (ph) -> on juge la déformation au pic, kind par kind.
--
-- Pourquoi une planche STATIQUE et pas un loop : `Critter` est STATELESS (dessine à une phase donnée). On fixe
-- donc `ph` par la scène (pas par le temps) ; `t` ne pilote que l'idle (respiration/yeux) sous la réaction.
-- Interface scène (cf. src/core/export.lua) : update / drawWorld / drawOverlay(view) + flag nativeWorld.

local Background = require("src.fx.background")
local Critter = require("src.render.critter")
local Units = require("src.data.units")
local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")

local AnimSheet = {}
AnimSheet.__index = AnimSheet

-- Roster de revue : 16 unités RÉELLES choisies pour étaler les 18 kinds d'attaque (et donc des familles variées
-- -> hurt/death variés aussi). 4 colonnes × 4 rangées. Le `kind` affiché est résolu à chaud (Critter.atkFor) pour
-- coller à la VRAIE forme tirée par hash (pas une supposition). Couvre : lunge/bite/swing/claw/lash/slam/gaze/cast/
-- shard/multi/skitter/engulf + pounce/phase/surge/smite (extras lisibles).
local ROSTER = {
  "mire_thing",     -- gelatine/blobmonster -> lunge
  "demon",          -- abyssal/anglerfish   -> bite
  "oath_keeper",    -- templier/paladin     -> swing
  "marauder",       -- crustace/crab        -> claw
  "corruptor",      -- kraken/kraken        -> lash
  "kiln_warden",    -- colosse/ogre         -> slam
  "stormcaller",    -- oeil/eyecluster      -> gaze
  "bellows_priest", -- culte/cultist        -> cast
  "stormlord",      -- cristal/crystalcluster-> shard
  "soot_acolyte",   -- chimere/chimera      -> multi (5 sous-attaques)
  "web_recluse",    -- arachnide/spider     -> skitter
  "wither_bloom",   -- ombre/voidmaw        -> engulf
  "razorkin",       -- bete/direcat         -> pounce
  "wailing_shade",  -- spectre/wraith       -> phase
  "galvanizer",     -- rongeur/ratking      -> surge
  "templar",        -- seraphin/throne      -> smite
}

local COLS = 4
local CELL_W, CELL_H = 78, 40 -- en px VIRTUELS (320×180) : 4 colonnes ~= 312px, 4 rangées ~= 160px
local GX0, GY0 = 4, 16        -- marge gauche / sous le titre

-- mode : "attack" | "death" | "hurt". phase = pic visuel de chaque évènement (réglé par la fabrique).
function AnimSheet.new(palette, vw, vh, host, opts)
  opts = opts or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    nativeWorld = true,                 -- créatures rendues en RÉSOLUTION NATIVE (sprites primgen nets)
    bg = Background.new(palette, vw, vh),
    mode = opts.mode or "attack",
    phase = opts.phase or 0.42,         -- ph de frappe par défaut (override par fabrique : death 0.5, hurt 0.10)
    items = {},
  }, AnimSheet)
  for _, id in ipairs(ROSTER) do
    if Units[id] then
      self.items[#self.items + 1] = {
        id = id,
        atk = Critter.atkFor(id),        -- descripteur {k,...} (sert de `pr` ET de `.k`)
        hurtK = Critter.hurtFor(id),
        deathK = Critter.deathFor(id),
      }
    end
  end
  return self
end

-- Centre x / baseline pieds y (px virtuels) d'une case d'index 1-based.
local function cellPos(idx)
  local i = idx - 1
  local c = i % COLS
  local r = math.floor(i / COLS)
  local cx = GX0 + c * CELL_W + CELL_W * 0.5
  local cy = GY0 + r * CELL_H + CELL_H - 6 -- pieds ~en bas de la case (marge pour le label)
  return cx, cy
end

function AnimSheet:update(frameDt)
  self.t = self.t + frameDt
  self.bg:update(frameDt, self.t)
end

function AnimSheet:drawWorld()
  self.bg:draw()
  local ts = self.t / 60 -- horloge idle en SECONDES (Critter attend des secondes)
  for i, it in ipairs(self.items) do
    local cx, cy = cellPos(i)
    -- cadre léger de case (lisibilité de la grille)
    love.graphics.setColor(0.16, 0.13, 0.18, 0.4)
    love.graphics.rectangle("line", cx - CELL_W / 2 + 1, cy - CELL_H + 3, CELL_W - 2, CELL_H - 1)
    love.graphics.setColor(1, 1, 1, 1)
    -- descripteur de réaction à la PHASE fixée (selon le mode de la planche).
    local ropts
    if self.mode == "attack" then
      ropts = { atk = { k = it.atk.k, pr = it.atk, ph = self.phase }, shadow = true }
    elseif self.mode == "death" then
      ropts = { death = { k = it.deathK, ph = self.phase }, shadow = true }
    elseif self.mode == "hurt" then
      ropts = { hurt = { k = it.hurtK, ph = self.phase }, shadow = true }
    end
    -- échelle ~hauteur de case (cadre natif 64). Pieds calés sur (cx,cy).
    local scale = (CELL_H - 6) / 64 * 1.5
    Critter.drawAt(nil, it.id, cx, cy, scale, ts, 1, ropts)
  end
end

function AnimSheet:drawOverlay(view)
  Draw.begin(view)
  -- titre de la planche (haut-gauche).
  local title = ({ attack = "ATTACK", death = "DEATH", hurt = "HURT" })[self.mode] or "REACTION"
  Draw.text("ANIM SHEET — " .. title .. " (ph " .. string.format("%.2f", self.phase) .. ")",
    GX0 * 4, 2 * 4, Theme.c.ink, Theme.label(11))
  -- label sous chaque créature : NOM + kind effectif (résolu).
  for i, it in ipairs(self.items) do
    local cx, cy = cellPos(i)
    local kind = (self.mode == "attack" and it.atk.k) or (self.mode == "death" and it.deathK) or it.hurtK
    local labY = (cy + 3) * 4
    Draw.textC(it.id, cx * 4, labY, Theme.c.ink2, Theme.labelSmall(9))
    Draw.textC(kind, cx * 4, labY + 11, Theme.c.brassS, Theme.labelSmall(9))
  end
  Draw.finish()
end

return AnimSheet
