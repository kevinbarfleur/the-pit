-- src/ui/nav.lua
-- RÈGLE DE NAVIGATION (brique design-system) : un bouton RETOUR homogène « ‹ LABEL », même look sur TOUS les
-- écrans (coin haut-droit par défaut, style secondary net). On circule par BOUTONS — plus par raccourcis
-- affichés en plein écran. Les touches (esc / g / …) restent des accélérateurs SILENCIEUX, jamais le seul moyen.
--
-- RENDER pur, ESPACE DESIGN. À appeler DANS un bloc Draw.begin (comme Button) — la scène gère sa transform.
-- Renvoie son rect pour le hit-test du caller (-> host.goto). Headless-safe (Button/Feel le sont).
--   self.backRect = Nav.back(view, T("scene.back_label"), { mx=self.mx, my=self.my, id="x.back" })
--   if Nav.hit(self.backRect, dx, dy) then self.host.goto("menu") end

local Draw = require("src.ui.draw")
local Button = require("src.ui.button")
local Feel = require("src.ui.feel")

local Nav = {}
local BW, BH, PAD = 132, 34, 22

local function ptIn(mx, my, x, y, w, h)
  return mx ~= nil and mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Dessine le bouton retour ; renvoie son rect { id, x, y, w, h }. opts : { x, y, w, variant, mx, my, id }.
function Nav.back(view, label, opts)
  opts = opts or {}
  local w = opts.w or BW
  local x = opts.x or (Draw.W - w - PAD)
  local y = opts.y or PAD
  local id = opts.id or "nav.back"
  local hover = ptIn(opts.mx, opts.my, x, y, w, BH)
  Feel.hover(id, hover) -- alimente le lissage du juice (survol) -> la scène n'a pas à pré-câbler le Feel du retour
  Button.draw(x, y, w, BH, opts.variant or "secondary", "‹  " .. (label or "BACK"),
    { hover = hover, feel = Feel.state(id), id = id })
  return { id = id, x = x, y = y, w = w, h = BH }
end

-- Hit-test pratique du rect renvoyé par Nav.back.
function Nav.hit(rect, mx, my)
  return rect ~= nil and ptIn(mx, my, rect.x, rect.y, rect.w, rect.h)
end

return Nav
