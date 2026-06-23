-- src/ui/screenframe.lua
-- L'ENROBAGE D'ÉCRAN partagé (spec §A.9) : cadre de pierre gravée (Reliquary) plein écran + onglet de nom
-- centré sur le bord haut + inset de contenu. UN appel par scène -> TOUS les écrans portent le même cadre
-- signature (« l'or encadre le jeu, pas chaque bouton »). RENDER pur, headless-safe (Reliquary no-op sous mock).
--
-- Usage (sous Draw.begin(view), en OVERLAY, APRÈS le contenu) :
--   ScreenFrame.draw(T("scene.x"):upper())            -- cadre + onglet « X »
--   local ix, iy, iw, ih = ScreenFrame.inset()        -- aire de contenu intérieure (à respecter)
-- Le centre du cadre est TRANSPARENT : le contenu (inset) se dessine d'abord, le cadre borde la marge.

local Reliquary = require("src.ui.reliquary")
local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")

local ScreenFrame = {}

local FT = 8 -- épaisseur d'art de la bande (×4 = ~32px design) — uniforme sur tous les écrans
local C = Theme.c

-- Onglet de nom : pilier de pierre centré sur le bord HAUT du cadre, portant le nom de l'écran (Cinzel tracké
-- en encre tarnie). Métal sombre + liseré iron + éclat laiton haut. nil -> aucun onglet.
function ScreenFrame.nameTab(label)
  if not label then return end
  local f = Theme.heading(12)
  local tracking = 4
  local tw = Draw.textWidth(label, f) + tracking * math.max(0, #label - 1)
  local w, h, y = tw + 44, 24, 6
  local x = math.floor(Draw.W / 2 - w / 2)
  Draw.rect(x, y, w, h, Theme.hex(0x0e0a14), C.iron, 1)
  if love and love.graphics then -- éclat laiton haut (biseau)
    Draw.setColor(C.brassS, 0.18); love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 1); Draw.reset()
  end
  Draw.textTrackedC(label, Draw.W / 2, y + (h - (f and f:getHeight() or 12)) / 2, Theme.hex(0xcdbca0), f, tracking)
end

-- Cadre reliquaire plein écran + onglet de nom. opts.ft = épaisseur (def FT). À appeler en overlay.
function ScreenFrame.draw(label, opts)
  opts = opts or {}
  Reliquary.draw(0, 0, Draw.W, Draw.H, { ft = opts.ft or FT })
  ScreenFrame.nameTab(label)
end

-- Aire de contenu intérieure au cadre (inset) -> (ix, iy, iw, ih) en espace design. pad = marge
-- supplémentaire pierre/contenu (def 2 art px). Le contenu de la scène doit tenir DANS ce rect.
function ScreenFrame.inset(opts)
  opts = opts or {}
  return Reliquary.inset(0, 0, Draw.W, Draw.H, { ft = opts.ft or FT, pad = opts.pad or 2 })
end

ScreenFrame.FT = FT
return ScreenFrame
