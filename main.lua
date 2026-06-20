-- main.lua — point d'entrée LÖVE (11.5).
--
-- Pipeline de rendu :
--   monde -> Canvas virtuel basse résolution (320x180) -> blit en SCALE ENTIER, letterbox.
-- C'est le pattern pixel-perfect recommandé : chaque pixel source = bloc N×N à l'écran.
--
-- Boucle : love.run est surchargée en bas du fichier avec un PAS DE TEMPS FIXE
-- (accumulateur), prérequis d'un combat déterministe pour un autobattler.

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")
local Combat = require("src.scenes.combat")
local Runover = require("src.scenes.runover")
local RunState = require("src.run.state")

local VW, VH = 320, 180           -- résolution virtuelle (×4 = 1280×720 pile)
local FRAME = 60                  -- conversion dt(s) -> "frames" pour l'horloge des anims
local canvas
local view = { scale = 1, ox = 0, oy = 0 }

-- Mini state-machine : build <-> combat, enrobée par la méta de RUN (host.run). Une scène demande
-- une transition via host.goto(name, payload). La phase build est PERSISTANTE sur tout le run (le
-- plateau est conservé de round en round) ; combat et runover sont recréés à chaque entrée.
local host = { scene = nil, name = nil, build = nil, run = nil }

function host.goto(name, payload)
  if name == "combat" then
    host.scene = Combat.new(Palette, VW, VH, host, payload)
  elseif name == "runover" then
    host.scene = Runover.new(Palette, VW, VH, host, payload)
  else
    host.scene = host.build
  end
  host.name = name
end

-- Fin d'un combat : la méta de run résout l'issue (vies/victoires/streaks), puis ouvre le round
-- suivant (retour build, plateau PERSISTANT) — ou l'écran de fin de run si le run est conclu.
function host.finishCombat(win)
  host.run:resolve(win)
  local over = host.run:isOver()
  if over then
    host.goto("runover", { result = over, run = host.run })
  else
    host.run:startRound()
    host.goto("build")
  end
end

-- Démarre une run neuve : nouvel état seedé (boutique/seeds de combat dérivés) + plateau remis à zéro.
function host.newRun()
  host.run = RunState.new(love.math.random(1, 2147483647))
  host.build = Build.new(Palette, VW, VH, host)
  host.goto("build")
end

local function drawHud(scene)
  love.graphics.setColor(0.78, 0.72, 0.60, 0.9)
  love.graphics.print("THE PIT  —  " .. (scene.title or ""), 16, 12)
  love.graphics.setColor(0.40, 0.34, 0.30, 1)
  love.graphics.print("FPS " .. love.timer.getFPS(), 16, 30)
  love.graphics.print((scene.hint or "") .. "   ·   [echap] quitter", 16, 46)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Pixels fenêtre -> espace virtuel (inverse exact du blit en scale entier).
local function toVirtual(x, y)
  if view.scale <= 0 then return x, y end
  return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest") -- AVANT toute création d'Image/Canvas
  love.graphics.setLineStyle("rough")
  love.graphics.setBackgroundColor(0.024, 0.016, 0.039)

  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest", "nearest")

  host.newRun() -- crée host.run (état seedé) + host.build, puis entre en phase build
end

function love.update(dt)
  host.scene:update(dt * FRAME) -- ~1.0 par tick au pas fixe 1/60
end

function love.draw()
  local scene = host.scene
  -- 1. Monde -> canvas virtuel.
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.024, 0.016, 0.039, 1)
  scene:drawWorld()
  love.graphics.setCanvas()

  -- 2. Blit en scale ENTIER, centré (letterbox).
  local sw, sh = love.graphics.getDimensions()
  local scale = math.max(1, math.floor(math.min(sw / VW, sh / VH)))
  view.scale = scale
  view.ox = math.floor((sw - VW * scale) / 2)
  view.oy = math.floor((sh - VH * scale) / 2)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, view.ox, view.oy, 0, scale, scale)

  -- 3. Overlays en résolution native (texte net).
  scene:drawOverlay(view)
  drawHud(scene)
end

function love.keypressed(key)
  if key == "escape" then love.event.quit(); return end
  if host.scene.keypressed then host.scene:keypressed(key) end
end

function love.mousepressed(x, y, button)
  if not host.scene.mousepressed then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
  if not host.scene.mousereleased then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y)
  if not host.scene.mousemoved then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousemoved(vx, vy)
end

-- ───────────────────────── Boucle à pas de temps fixe ─────────────────────────
-- love.update est toujours appelée avec dt = TICK (déterministe) ; love.draw tourne
-- une fois par frame. MAX_SKIP borne le rattrapage pour éviter la "spirale de la mort".
-- Réf : https://love2d.org/wiki/love.run · https://gafferongames.com/post/fix_your_timestep/
local TICK = 1 / 60
local MAX_SKIP = 25

function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end
  local lag = 0.0

  return function()
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end

    if love.timer then lag = math.min(lag + love.timer.step(), TICK * MAX_SKIP) end
    while lag >= TICK do
      if love.update then love.update(TICK) end
      lag = lag - TICK
    end

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end
