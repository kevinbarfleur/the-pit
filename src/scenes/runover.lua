-- src/scenes/runover.lua
-- Écran de FIN DE RUN : affiché quand le run se conclut (10 victoires = ascension, ou 0 vie = chute).
-- Récapitule la run puis attend un clic / [r] pour en relancer une nouvelle (host.newRun()).
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mousepressed.

local Background = require("src.fx.background")
local T = require("src.core.i18n").t

local Runover = {}
Runover.__index = Runover

function Runover.new(palette, vw, vh, host, payload)
  payload = payload or {}
  return setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    titleKey = "scene.runover",
    hintKey = "ui.hint_runover",
    result = payload.result or "lose", -- "win" | "lose"
    run = payload.run,
    bg = Background.new(palette, vw, vh),
  }, Runover)
end

function Runover:update(frameDt)
  self.t = self.t + frameDt
  self.bg:update(frameDt, self.t)
end

function Runover:drawWorld()
  self.bg:draw()
end

function Runover:drawOverlay(view)
  local sw, sh = love.graphics.getDimensions()
  local r = self.run
  local won = self.result == "win"

  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, sh / 2 - 54, sw, 108)

  if won then
    love.graphics.setColor(0.78, 0.68, 0.32, 1)
    love.graphics.printf(T("runover.win"), 0, sh / 2 - 44, sw, "center")
  else
    love.graphics.setColor(0.70, 0.22, 0.20, 1)
    love.graphics.printf(T("runover.lose"), 0, sh / 2 - 44, sw, "center")
  end

  if r then
    love.graphics.setColor(0.72, 0.68, 0.60, 0.95)
    love.graphics.printf(
      T("runover.stats", { wins = r.wins, losses = r.losses, rounds = r.round, level = r.level }),
      0, sh / 2 - 16, sw, "center")
  end

  love.graphics.setColor(0.66, 0.62, 0.56, 0.95)
  love.graphics.printf(T("ui.hint_runover"), 0, sh / 2 + 14, sw, "center")
  love.graphics.setColor(1, 1, 1, 1)
end

function Runover:keypressed(key)
  if key == "r" then self.host.newRun() end
end

function Runover:mousepressed(vx, vy, button)
  if button == 1 then self.host.newRun() end
end

return Runover
