-- src/ui/viewport.lua
-- Calcul pur de viewport : contenu 16:9 en "contain" + fond en "cover".
-- Aucun love.* ici : testable headless, partageable entre main.lua et les exports.

local Viewport = {}

function Viewport.update(view, vw, vh, sw, sh)
  view = view or {}
  vw, vh = vw or 320, vh or 180
  sw, sh = sw or vw, sh or vh

  -- Le contenu jouable reste non déformé dans le repère historique.
  local contain = math.max(1, math.min(sw / vw, sh / vh))
  view.scale = contain
  view.ox = math.floor((sw - vw * contain) / 2)
  view.oy = math.floor((sh - vh * contain) / 2)
  view.screenW, view.screenH = sw, sh
  view.safeW, view.safeH = vw * contain, vh * contain
  view.designScale = contain / 4
  view.aspect = sh > 0 and (sw / sh) or (vw / vh)
  view.layout = (view.aspect > 2.05 and "wide")
      or (view.aspect < 1.55 and "tall")
      or "standard"
  view.extra = {
    l = math.max(0, view.ox), r = math.max(0, sw - view.ox - view.safeW),
    t = math.max(0, view.oy), b = math.max(0, sh - view.oy - view.safeH),
  }
  view.hasBleed = view.extra.l > 0 or view.extra.r > 0 or view.extra.t > 0 or view.extra.b > 0

  -- Le fond cover remplit toute la fenêtre : il remplace les letterbox bars sans étirer le gameplay.
  local cover = math.max(contain, sw / vw, sh / vh)
  local bv = view.bleed or {}
  bv.scale = cover
  bv.ox = math.floor((sw - vw * cover) / 2)
  bv.oy = math.floor((sh - vh * cover) / 2)
  bv.screenW, bv.screenH = sw, sh
  bv.safeW, bv.safeH = vw * cover, vh * cover
  bv.designScale = cover / 4
  view.bleed = bv

  return view
end

return Viewport
