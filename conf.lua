-- conf.lua — exécuté AVANT le chargement des modules (doit vivre ici, pas dans main.lua).
-- Réf : https://love2d.org/wiki/Config_Files
function love.conf(t)
  t.identity = "the-pit"          -- dossier de sauvegarde
  t.version = "11.5"              -- version LÖVE ciblée (string "X.Y")
  t.console = false

  t.window.title = "The Pit — Playground"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 320
  t.window.minheight = 180
  t.window.vsync = 1              -- 11.x : NOMBRE (-1 adaptatif, 0 off, 1 on)
  t.window.msaa = 0              -- 0 = bords nets pour le pixel art
  t.window.highdpi = true         -- rendu PLEINE DENSITÉ sur écrans Retina/HiDPI : love.graphics travaille en
                                  -- PIXELS réels (texte/UI nets, plus d'upscale flou par l'OS). NB : les events
                                  -- souris restent en UNITÉS FENÊTRE -> main.lua convertit via love.window.toPixels.

  -- Modules inutiles désactivés (démarrage + mémoire). On écrit le combat à la main.
  t.modules.physics = false
  t.modules.joystick = false
  t.modules.touch = false
end
