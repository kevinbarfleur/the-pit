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
local MiniRig = require("src.render.minirig")       -- frimousse figée devant chaque nom (J3)
local MonsterCard = require("src.render.monstercard") -- fiche TCG flottante au survol d'un nom (J4)

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
ov:draw(view) -- settle les rects du carrousel + des boutons propres (Button.icon)
ov:keypressed("right"); assert(ov.sel == 2, "[>] round suivant")
ov:keypressed("right"); assert(ov.sel == 3, "[>] encore")
ov:keypressed("left"); assert(ov.sel == 2, "[<] round précédent")
ov:wheelmoved(0, -2)
-- Les INPUTS arrivent en espace VIRTUEL (main.lua:toVirtual) ; l'overlay convertit ×4 vers DESIGN en interne
-- (ses rects sont en design). Le test reflète donc le vrai flux : on passe rect_design / 4.
local function toV(px, py) return px / 4, py / 4 end
-- boutons-icône propres (Button.icon) : clic sur la flèche précédente (centre) -> round précédent.
ov:mousemoved(toV(ov._prev.x + ov._prev.w / 2, ov._prev.y + ov._prev.h / 2)) -- survol (hover des boutons propres)
ov:mousepressed(toV(ov._prev.x + ov._prev.w / 2, ov._prev.y + ov._prev.h / 2)); assert(ov.sel == 1, "clic [<] -> 1er")
-- bouton X (close) : renvoie "close" (main.lua referme l'overlay).
assert(ov._close, "l'overlay pose le rect du bouton de fermeture")
assert(ov:mousepressed(toV(ov._close.x + 1, ov._close.y + 1)) == "close", "clic sur X -> 'close'")
ov:draw(view) -- re-draw après navigation : no-crash

-- 3) MINI-RIG (J3) : require + draw headless (fallback bounds sous mock, no-crash) ; le panneau peuple
-- _nameRects (hit-boxes des noms pour le survol) à chaque draw -> au moins 1 nom par fragment actor/target.
MiniRig.draw(view, "marauder", nil, 10, 10, 16, 16)
local bnd = MiniRig.bounds("marauder")
assert(bnd and bnd.w and bnd.h, "minirig bounds renvoie une boîte (fallback sous mock)")
local cd2 = ChronicleDraw.new(model)
cd2:draw(view, 8, 8, 600, 400)
assert(cd2._nameRects and #cd2._nameRects >= 1, "le panneau enregistre des rects de noms (survol), vu " ..
  (cd2._nameRects and #cd2._nameRects or "nil"))
for _, nr in ipairs(cd2._nameRects) do
  assert(nr.id and nr.x and nr.y and nr.w and nr.h, "rect de nom complet (id + géométrie)")
end

-- 4) MONSTER-CARD (J4A) : require + draw headless (no-crash), id inconnu -> nil, helpers purs corrects.
assert(MonsterCard.draw(view, nil, "no_such_unit", 10, 10, 0) == nil, "id inconnu -> nil (pas de carte)")
local mcBox = MonsterCard.draw(view, nil, "witch", 200, 200, 0.5)
assert(mcBox and mcBox.w and mcBox.h, "MonsterCard.draw renvoie une boîte posée")
assert(MonsterCard.afflValue({ dps = 6, dur = 180 }) == "6 dps 3s", "MonsterCard.afflValue conserve le format")
assert(#MonsterCard.tokenizeValues("takes +5% (up to 5).") >= 1, "MonsterCard.tokenizeValues découpe la ligne")

-- 5) HOVER de nom (J4B) : on pointe le 1er rect de nom de la frame -> hoveredName() renvoie son id ; un point
-- HORS liste -> nil. Le panel reçoit les coords en DESIGN (l'overlay a déjà converti). Test au niveau panel.
local cd3 = ChronicleDraw.new(model)
cd3:draw(view, 8, 8, 600, 400)
local nr1 = cd3._nameRects[1]
assert(nr1, "au moins un rect de nom à survoler")
cd3:mousemoved(nr1.x + nr1.w / 2, nr1.y + nr1.h / 2) -- pointe le centre du 1er nom
cd3:draw(view, 8, 8, 600, 400)                        -- re-draw : le hover est résolu en fin de draw
local hid = cd3:hoveredName()
assert(hid == nr1.id, "survol d'un nom -> hoveredName() = son id (" .. tostring(hid) .. " vs " .. tostring(nr1.id) .. ")")
cd3:mousemoved(5000, 5000); cd3:draw(view, 8, 8, 600, 400) -- très hors liste
assert(cd3:hoveredName() == nil, "hors de la liste -> aucun nom survolé")

-- 6) BOUT-EN-BOUT overlay (J4B) : survol d'un nom DANS l'overlay -> draw dessine la carte sans crash. On vise
-- la zone de liste de l'overlay (panel à design 24,92..) en passant des coords VIRTUELLES (÷4).
local ov2 = Overlay.new(run, model)
ov2:draw(view) -- 1er draw : settle les _nameRects du panel
local prn = ov2.panel._nameRects[1]
if prn then
  ov2:mousemoved(toV(prn.x + prn.w / 2, prn.y + prn.h / 2))
  ov2:draw(view) -- re-draw : carte au survol dessinée par-dessus (no-crash)
  assert(ov2.panel:hoveredName() ~= nil, "overlay : survol d'un nom détecté par le panel")
end

print("=> CHRONICLE-UI OK : panneau + overlay (Button.icon + X) + frimousses + fiche au survol (headless).")
