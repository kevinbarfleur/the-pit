-- feel-lab/conf.lua — config du MINI-PROJET d'expérimentation (isolé du jeu principal).
-- Lancement : `love feel-lab` depuis la racine du dépôt. Réf : https://love2d.org/wiki/Config_Files
function love.conf(t)
  t.identity = "the-pit-feel-lab"   -- dossier de sauvegarde séparé (n'écrase rien du jeu)
  t.version  = "11.5"
  t.console  = false

  t.window.title     = "The Pit — FEEL LAB"
  t.window.width     = 1280
  t.window.height    = 720
  t.window.resizable = true
  t.window.minwidth  = 320
  t.window.minheight = 180
  t.window.vsync     = 1
  t.window.msaa      = 0
  t.window.highdpi   = true

  -- on n'a besoin d'aucune physique/joystick ; on garde l'audio (SFX procéduraux).
  t.modules.physics  = false
  t.modules.joystick = false
  t.modules.touch    = false
end
