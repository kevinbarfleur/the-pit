-- src/scenes/combat.lua
-- Phase de COMBAT : on rejoue automatiquement la bataille entre l'équipe du joueur (gauche,
-- construite dans la phase build) et une équipe adverse (droite, IA de seed). Spectateur :
-- aucune entrée pendant le combat. À la fin -> bandeau VICTOIRE/DEFAITE puis retour au build.
--
-- Sépare SIM et RENDER : `arena` (src/combat) résout la bataille (déterministe, seedée) et émet
-- des événements ; `renderer` (src/render) les consomme pour l'animation. La scène orchestre.
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mousepressed.

local Background = require("src.fx.background")
local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")

local Combat = {}
Combat.__index = Combat

function Combat.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local arena = Arena.new({ left = payload.left, right = payload.right, autoReset = false, seed = payload.seed })
  return setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette, payload = payload,
    title = "combat",
    hint = "combat automatique en cours...",
    enemyName = payload.enemyName or "ADVERSAIRE",
    bg = Background.new(palette, vw, vh),
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
  self.bg:update(frameDt, self.t)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
  if self.arena.over then
    self.hint = "[clic] retour au build   [r] rejouer"
  end
end

function Combat:drawWorld()
  self.bg:draw()
  self.renderer:draw(false)
end

function Combat:drawOverlay(view)
  -- Étiquette de l'adversaire en haut.
  love.graphics.setColor(0.55, 0.30, 0.30, 0.9)
  love.graphics.printf("vs  " .. self.enemyName, 0, view.oy + 8, love.graphics.getWidth(), "center")

  self.renderer:drawOverlay(view)

  if self.arena.over and self.arena.overAge >= 20 then
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, sh / 2 - 34, sw, 64)
    if self.arena.win then
      love.graphics.setColor(0.72, 0.64, 0.30, 1)
      love.graphics.printf("VICTOIRE", 0, sh / 2 - 24, sw, "center")
    else
      love.graphics.setColor(0.70, 0.22, 0.20, 1)
      love.graphics.printf("DEFAITE", 0, sh / 2 - 24, sw, "center")
    end
    love.graphics.setColor(0.70, 0.66, 0.58, 0.95)
    love.graphics.printf("clic: retour au build      [r] rejouer", 0, sh / 2 + 2, sw, "center")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Combat:keypressed(key)
  if key == "r" then self:restart() end
end

function Combat:mousepressed(vx, vy, button)
  if button == 1 and self.arena.over then
    -- Route via le host (méta de run : résout l'issue, met à jour vies/victoires, ouvre le round
    -- suivant OU l'écran de fin de run). Fallback goto("build") pour les contextes sans run (tests).
    if self.host.finishCombat then self.host.finishCombat(self.arena.win)
    else self.host.goto("build") end
  end
end

return Combat
