-- src/scenes/runover.lua
-- Écran de FIN DE RUN (DA) : affiché quand le run se conclut (10 victoires = ASCENSION, ou 0 vie =
-- THE PIT KEEPS YOU). Récapitule la run sur fond d'atmosphère, puis attend un clic / [r] pour relancer.
--
-- Couche scène (love.graphics) : atmosphère native en drawBack, texte en overlay design. daChrome=true.
-- Interface scène : update / drawBack / drawWorld / drawOverlay(view) / keypressed / mousepressed.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local T = require("src.core.i18n").t

local Runover = {}
Runover.__index = Runover

function Runover.new(palette, vw, vh, host, payload)
  payload = payload or {}
  return setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.runover",
    hintKey = "ui.hint_runover",
    result = payload.result or "lose", -- "win" | "lose"
    run = payload.run,
    ambient = Ambient.new(21),
  }, Runover)
end

function Runover:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
end

function Runover:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("runover")
  Draw.finish()
end

function Runover:drawWorld() end

function Runover:drawOverlay(view)
  local c = Theme.c
  local r = self.run
  local won = self.result == "win"
  local cx, cy = Draw.W / 2, Draw.H / 2

  Draw.begin(view)
  -- Voile pour détacher le récap de l'atmosphère.
  Draw.rect(0, cy - 150, Draw.W, 300, { 0.02, 0.012, 0.03, 0.5 })

  -- Kicker (saveur, serif romain) + verdict (logotype gothique = mot de résultat).
  Draw.textC(T(won and "runover.kicker_win" or "runover.kicker_lose"), cx, cy - 132, c.faint, Theme.loreRoman(18))
  Draw.textC(T(won and "runover.win" or "runover.lose"), cx, cy - 104, won and c.gold or c.bloodBright, Theme.display(92))
  Draw.divider(cx, cy + 14, 280, c.fainter, 1)

  -- Récap (lisible : Silkscreen).
  if r then
    Draw.textC(T("runover.score", { wins = r.wins, losses = r.losses }), cx, cy + 30, c.title, Theme.ui(14))
    Draw.textC(T("runover.progress", { rounds = r.round, level = r.level }), cx, cy + 52, c.faint, Theme.ui(12))
  end
  Draw.textC(T("runover.again"), cx, cy + 96, c.muted, Theme.ui(12))

  Draw.finish()
end

function Runover:keypressed(key)
  if key == "r" then self.host.newRun() end
end

function Runover:mousepressed(vx, vy, button)
  if button == 1 then self.host.newRun() end
end

return Runover
