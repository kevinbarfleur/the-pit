-- src/ui/panel.lua
-- SURFACE PROPRE du design system (.dc.html) — le pendant LÖVE des panneaux/cartes CSS du designer :
-- fond en DÉGRADÉ vertical sombre + liseré 1px `iron` net + (option) un éclat 1px en haut (laiton très bas
-- alpha = le `inset 0 1px 0 rgba(216,182,94,.16)` du .dc.html). RIEN de gritty : pas de rivets, pas de biseau
-- métal, pas d'œil — c'est la base « nette » qu'on grit ENSUITE au shader. Couleurs via Theme uniquement.
--
-- RENDER pur, headless-safe (love.graphics stubbé sous le mock -> no-op). Dessine en ESPACE DESIGN sous
-- Draw.begin(view) ; le texte/bords héritent de la netteté résolution-indépendante de Draw.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local PostFX = require("src.render.postfx") -- COLLECTEUR de rects : la distorsion onirique se confine aux BORDURES des box
local C = Theme.c

local Panel = {}

-- Dégradé vertical (2 stops) en bandes horizontales. Cap de bandes (<=24) -> assez lisse, peu coûteux.
-- top/bottom = couleurs {r,g,b,a}. À utiliser sous Draw.begin (espace design).
function Panel.vgrad(x, y, w, h, top, bottom)
  if not (love and love.graphics) then return end
  local n = math.max(2, math.min(24, math.floor(h)))
  local bh = h / n
  for i = 0, n - 1 do
    local t = i / (n - 1)
    love.graphics.setColor(
      top[1] + (bottom[1] - top[1]) * t,
      top[2] + (bottom[2] - top[2]) * t,
      top[3] + (bottom[3] - top[3]) * t,
      (top[4] or 1) + ((bottom[4] or 1) - (top[4] or 1)) * t)
    love.graphics.rectangle("fill", x, y + i * bh, w, bh + 1)
  end
  Draw.reset()
end

-- Panneau propre. opts = {
--   fill1, fill2 : couleurs du dégradé (def stone800 -> stone900) ; fill (uni) court-circuite le dégradé
--   border       : liseré (def iron) ; hi : éclat haut (def true) ; accent : liseré interne (rareté/héros)
-- } -> renvoie le rect INTÉRIEUR (ix, iy, iw, ih) pour ancrer le contenu.
function Panel.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
  -- opts.solid : panneau OPAQUE flottant (fiche au survol / modal) -> EFFACE le masque sous lui (net, sans bave de
  -- bordure des cartes derrière). Sinon : anneau de distorsion sur le périmètre (comportement normal des cartes).
  if opts.solid then PostFX.markSolid(x, y, w, h) else PostFX.markBox(x, y, w, h) end
  if opts.fill then
    Draw.rect(x, y, w, h, opts.fill)
  else
    Panel.vgrad(x, y, w, h, opts.fill1 or C.stone800, opts.fill2 or C.stone900)
  end
  if opts.hi ~= false then
    Draw.setColor(C.brassS, 0.12)
    if love and love.graphics then love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 1) end
    Draw.reset()
  end
  if opts.accent then Draw.rect(x + 1, y + 1, w - 2, h - 2, nil, opts.accent, 1) end
  -- NOTE : le « tangage onirique » des bordures n'est PLUS dessiné ici (ancienne polyligne ondulée retirée —
  -- elle se lisait comme une ligne superposée). Il est désormais porté par un VRAI shader de distorsion d'UV
  -- dans src/render/postfx.lua (les vrais pixels du bord ondulent ; centre net via masque radial). opts.nightmare
  -- est ignoré (conservé pour compat ; aucun effet local).
  Draw.rect(x, y, w, h, nil, opts.border or C.iron, 1)
  return x + 1, y + 1, w - 2, h - 2
end

-- Niche à sprite (hachures diagonales + liseré) — le placeholder « sprite procédural » du .dc.html.
function Panel.niche(x, y, w, h)
  Draw.rect(x, y, w, h, C.stone900, C.iron, 1)
  if not (love and love.graphics) then return end
  Draw.setColor(C.stone800, 0.6)
  local step = 6
  for i = -h, w, step do
    love.graphics.line(x + i, y + h, x + i + h, y)
  end
  Draw.reset()
  Draw.rect(x, y, w, h, nil, C.iron, 1)
end

return Panel
