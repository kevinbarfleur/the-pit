-- tests/designsystem.lua
-- Couvre le RENDU de l'écran DESIGN SYSTEM (storybook in-engine) : la scène se construit, se dessine
-- (drawBack + drawOverlay) et se navigue (sidebar / molette / clavier) sous mock LÖVE. Vérifie aussi que
-- chaque entrée du catalogue déclare une hauteur ET que son render renvoie une hauteur > 0 (no-crash).

love = require("tests.mock_love") -- SET le global love (Draw/Theme/Forge l'utilisent)
local Theme = require("src.ui.theme")
Theme.load()
local Draw = require("src.ui.draw")
Draw.W, Draw.H = 1280, 720 -- dimensions design (settées par le resize en vrai)
local Palette = require("src.core.palette")
local DesignSystem = require("src.scenes.designsystem")

local view = { scale = 4, ox = 0, oy = 0 }
local jumped = nil
-- host.goto est appelé en NOTATION POINT (self.host.goto("menu")) -> 1er arg = name (pas de self).
local host = { goto = function(name) jumped = name end }
local s = DesignSystem.new(Palette, 320, 180, host)

-- 1) Structure du catalogue (data).
assert(s.sections and #s.sections >= 2, "au moins 2 niveaux (TOKENS + ATOMS)")
assert(s.items and #s.items > 0, "items de page aplatis")
assert(s.contentH and s.contentH > 0, "hauteur de contenu > 0")
assert(s.nav and #s.nav > 0, "sidebar peuplée")
for _, sec in ipairs(s.sections) do
  for _, e in ipairs(sec.entries) do
    assert(e.h and e.h > 0, "entrée " .. tostring(e.id) .. " : hauteur déclarée")
    assert(type(e.draw) == "function", "entrée " .. tostring(e.id) .. " : render présent")
  end
end

-- 2) Cycle de vie : update + draw (no-crash headless).
s:update(1)
s:drawBack(view)
s:drawOverlay(view) -- settle self._view + self.navRects

-- 3) Chaque render renvoie une hauteur > 0 (appel direct ; _view déjà posé par le draw ci-dessus).
for _, sec in ipairs(s.sections) do
  for _, e in ipairs(sec.entries) do
    local h = e.draw(s, 250, 120, 980)
    assert(type(h) == "number" and h > 0, "render " .. e.id .. " -> hauteur > 0 (vu " .. tostring(h) .. ")")
  end
end

-- 4) Défilement borné (molette ; dy<0 = vers le bas, dy>0 = vers le haut, idiome grimoire).
s:wheelmoved(0, -3); assert(s.scroll > 0, "la molette (dy<0) défile vers le bas")
s:wheelmoved(0, -999); assert(s.scroll == s:maxScroll() and s.scroll > 0, "scroll borné au maximum")
s:wheelmoved(0, 999); assert(s.scroll == 0, "scroll borné à 0 en haut")

-- 5) Sidebar : clic sur une entrée -> saut (le scroll change). Coords VIRTUELLES (la scène convertit ×4).
s:drawOverlay(view) -- repeuple navRects à la frame courante
local last = s.navRects[#s.navRects]
assert(last, "des rects de nav existent après un draw")
s:mousepressed((last.x + last.w / 2) / 4, (last.y + last.h / 2) / 4, 1)
assert(s.scroll > 0, "clic sur la dernière entrée de sidebar saute vers le bas")

-- 6) Souris : mousemoved convertit en espace DESIGN (×4) + détecte le hover de nav.
s:mousemoved(70 / 4, (last.y + 1) / 4)
assert(s.mx == 70 and s.my == last.y + 1, "souris convertie en design (×4)")
assert(s.hoverNav ~= nil, "le survol d'une entrée de sidebar est détecté")

-- 7) Bouton LIVE : JUICE différé (bible §4). drawButtons (appelé en 3) a posé self.liveRect. Un press DESSUS
-- arme le feedback (Feel) ; l'action différée est un no-op -> on vérifie surtout que ça ne plante pas et que
-- l'état Feel s'anime (squash/flash > 0 juste après le press, puis retombe après une grosse frame).
local Feel = require("src.ui.feel")
assert(s.liveRect, "designsystem : le bouton LIVE a un rect (posé au draw)")
local lr = s.liveRect
s:mousepressed((lr.x + lr.w / 2) / 4, (lr.y + lr.h / 2) / 4, 1)
local flashed = Feel.state("ds.live").flash
assert(flashed and flashed > 0, "designsystem : press LIVE -> flash immédiat (feedback)")
s:update(60) -- mûrit l'action différée (no-op) + retombe le flash, sans crash
s:drawOverlay(view)

-- 8) [esc] -> retour menu (routé via host.goto).
s:keypressed("escape")
assert(jumped == "menu", "[esc] -> retour menu")

print("=> DESIGNSYSTEM-UI OK : scène + sidebar + page scrollable + tokens/atomes + LIVE juice (headless).")
