-- src/ui/nightmare.lua
-- SURCOUCHE ONIRIQUE — DÉSACTIVÉE (le tangage des bordures est désormais un VRAI SHADER DE DISPLACEMENT).
--
-- HISTORIQUE / DÉCISION (retour user) : l'ancienne implémentation dessinait le bord en POLYLIGNE ondulée
-- (déplacement perpendiculaire par sinus) -> ça se lisait comme une LIGNE SUPERPOSÉE par-dessus le liseré
-- net, PAS comme une distorsion de la vraie bordure, et c'était trop violent. La méthode RECONNUE pour ce
-- genre d'effet est un SHADER DE DISTORSION D'UV (on décale les coordonnées de texture AVANT d'échantillonner,
-- `Texel(tex, uv + offset)`, avec un champ de sinus/bruit qui s'écoule) -> ça DÉFORME LES VRAIS PIXELS : la
-- vraie bordure ondule. Cet effet vit maintenant dans le pipeline post-fx EXISTANT (`src/render/postfx.lua`,
-- où toute la frame est déjà rendue dans un canvas natif) avec un masque radial qui garde le CENTRE net.
--
-- Ce module est conservé en NO-OP pour ne pas casser les call-sites (`Panel`, `Button`, scènes) ni les tests :
--   · Nightmare.border(...) ne dessine PLUS rien (zéro polyligne superposée).
--   · Nightmare.update(...) reste inerte (avance une horloge locale au cas où, sans effet visuel).
-- API inchangée (mêmes signatures, headless-safe) -> on peut retirer les appels tranquillement, ou les laisser.

local Nightmare = {}

-- Horloge conservée (inerte) : Nightmare.update reste un point d'entrée valide pour les scènes qui l'appellent
-- encore, mais elle ne pilote plus aucun rendu (la distorsion est portée par l'horloge murale du post-fx).
local clock = 0
function Nightmare.update(dtFrames)
  local dt = (dtFrames or 1) / 60
  if dt < 0 then dt = 0 end
  clock = clock + dt
end

-- NO-OP : on ne dessine plus de bordure ondulée à la main. La vraie distorsion (displacement UV) est appliquée
-- globalement par src/render/postfx.lua. Signature/arguments conservés -> les appelants n'ont rien à changer.
function Nightmare.border(_x, _y, _w, _h, _opts) -- luacheck: ignore
  return
end

return Nightmare
