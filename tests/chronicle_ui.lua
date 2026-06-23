-- tests/chronicle_ui.lua
-- Couvre le RENDU de La Chronique (sinon non testé) : le panneau (chronicle_draw) et l'overlay modal
-- (chronicle_overlay, carrousel de round) se chargent, se dessinent et se naviguent sous mock LÖVE.

love = require("tests.mock_love") -- SET le global love (Draw/Theme l'utilisent)
local Theme = require("src.ui.theme")
Theme.load() -- polices (mock) : Theme.read/ui doivent retourner des fonts
local Draw = require("src.ui.draw")
Draw.W, Draw.H = 1280, 720 -- dimensions design (settées par le resize ; large comme l'overlay réel)

local Chronicle = require("src.render.chronicle")
local ChronicleDraw = require("src.render.chronicle_draw")
local Overlay = require("src.render.chronicle_overlay")

local view = { scale = 4, ox = 0, oy = 0 }
local entries = {
  { tick = 30, kind = "affliction", family = "poison", actorId = "witch", actorTeam = "left",
    targetId = "demon", targetTeam = "right", dps = 2, dur = 180, total = 10 },
  { tick = 60, kind = "strike", cause = "attack", actorId = "marauder", actorTeam = "left",
    targetId = "demon", targetTeam = "right", amount = 12 },
  { tick = 90, kind = "death", targetId = "demon", targetTeam = "right", actorTeam = "right" },
}
local model = Chronicle.fromEntries(entries)

-- 1) Panneau seul : draw + scroll + clic filtre (no-crash + état cohérent).
local cd = ChronicleDraw.new(model)
cd:draw(view, 8, 8, 600, 400)
cd:wheelmoved(0, -1)
assert(cd:mousepressed(cd._frects.strike.x + 1, cd._frects.strike.y + 1) == true, "clic sur la puce Strikes = consommé")
assert(cd.fkinds.strike == false, "la puce Strikes bascule")
assert(cd:mousepressed(cd._teamRect.x + 1, cd._teamRect.y + 1) == true, "clic équipe = consommé")
assert(cd.fstate == 1, "le sélecteur d'équipe avance (Tout -> Toi)")

-- 2) Overlay : courant + historique = sélecteur de round (carrousel).
local run = { chronicles = {
  { round = 1, win = true, entries = entries },
  { round = 2, win = false, entries = {} },
} }
local ov = Overlay.new(run, model)
assert(#ov.sources == 3, "courant + 2 archives = 3 sources, vu " .. #ov.sources)
ov:draw(view) -- settle les rects du carrousel
ov:keypressed("right"); assert(ov.sel == 2, "[>] round suivant")
ov:keypressed("right"); assert(ov.sel == 3, "[>] encore")
ov:keypressed("left"); assert(ov.sel == 2, "[<] round précédent")
ov:wheelmoved(0, -2)
ov:mousepressed(ov._prev.x + 1, ov._prev.y + 1); assert(ov.sel == 1, "clic [<] -> 1er")
ov:draw(view) -- re-draw après navigation : no-crash

print("=> CHRONICLE-UI OK : panneau + overlay (carrousel de round) se dessinent et naviguent (headless).")
