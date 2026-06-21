-- src/scenes/combat.lua
-- Phase de COMBAT : on rejoue automatiquement la bataille entre l'équipe du joueur (gauche,
-- construite dans la phase build) et une équipe adverse (droite, IA de seed). Spectateur :
-- aucune entrée pendant le combat. À la fin -> bandeau VICTOIRE/DEFAITE puis retour au build.
--
-- Sépare SIM et RENDER : `arena` (src/combat) résout la bataille (déterministe, seedée) et émet
-- des événements ; `renderer` (src/render) les consomme pour l'animation. La scène orchestre.
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mousepressed.

local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local Ambient = require("src.fx.ambient")
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local T = require("src.core.i18n").t

local Combat = {}
Combat.__index = Combat

function Combat.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local arena = Arena.new({ left = payload.left, right = payload.right, autoReset = false, seed = payload.seed })
  return setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette, payload = payload,
    daChrome = true, -- chrome DA portée par la scène
    titleKey = "scene.combat",
    hintKey = "ui.hint_combat",
    enemyKey = payload.enemyKey,
    ambient = Ambient.new(payload.seed or 11), -- atmosphère "combat" (gueule du puits + braises)
    arena = arena,
    renderer = ArenaDraw.new(arena, palette),
  }, Combat)
end

function Combat:restart()
  -- Même seed -> bataille rejouée À L'IDENTIQUE (c'est déjà un replay déterministe).
  self.arena = Arena.new(
    { left = self.payload.left, right = self.payload.right, autoReset = false, seed = self.payload.seed })
  self.renderer = ArenaDraw.new(self.arena, self.palette)
end

function Combat:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
  if self.arena.over then
    self.hintKey = "ui.hint_combat_end"
  end
end

-- Atmosphère "combat" native (gueule du puits + braises), derrière les combattants pixel.
function Combat:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("combat")
  Draw.finish()
end

function Combat:drawWorld()
  self.renderer:draw(false)
end

function Combat:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)
  -- Chrome debug + adversaire (centré haut, "vs" éteint + nom en sang).
  Draw.text(T("ui.title") .. "  -  " .. T("scene.combat"):upper(), 16, 14, c.faint, Theme.ui(11))
  Draw.text(T(self.hintKey), 16, 32, c.ghost, Theme.ui(9))
  local font = Theme.ui(13)
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  love.graphics.setFont(font)
  local x = Draw.W / 2 - (font:getWidth("vs ") + font:getWidth(name)) / 2
  Draw.text("vs ", x, 18, c.faint, font)
  Draw.text(name, x + font:getWidth("vs "), 18, c.bloodBright, font)
  Draw.finish()

  self.renderer:drawOverlay(view) -- noms d'unités + nombres flottants (gère sa propre transform)

  -- Bandeau VICTORY / DEFEAT (logotype gothique = mot court iconique).
  if self.arena.over and self.arena.overAge >= 20 then
    local won = self.arena.win
    Draw.begin(view)
    Draw.rect(0, Draw.H / 2 - 92, Draw.W, 184, { 0.02, 0.012, 0.03, 0.66 })
    Draw.textC(won and T("result.victory") or T("result.defeat"), Draw.W / 2, Draw.H / 2 - 72,
      won and c.gold or c.bloodBright, Theme.display(104))
    Draw.textC(T("ui.hint_combat_end"), Draw.W / 2, Draw.H / 2 + 58, c.muted, Theme.ui(12))
    Draw.finish()
  end
end

function Combat:keypressed(key)
  if key == "r" then self:restart() end
end

function Combat:mousepressed(vx, vy, button)
  if button == 1 and self.arena.over then
    -- EXHIBITION (banc d'essai) : payload.onFinish prend la main -> retour au Proving Ground, SANS
    -- toucher la méta de run. Sinon route normale via le host (résout vies/victoires, round suivant ou
    -- fin de run). Fallback goto("build") pour les contextes sans run (tests).
    if self.payload.onFinish then self.payload.onFinish(self.arena.win, self.arena)
    elseif self.host.finishCombat then self.host.finishCombat(self.arena.win)
    else self.host.goto("build") end
  end
end

return Combat
