-- src/render/minirig.lua
-- MINI-SPRITE de créature NON ANIMÉ, figé en pose idle, calé dans une petite boîte (≈ taille d'une police).
-- Extrait/généralisé du portrait de fiche de src/scenes/build.lua (newRig / rigBounds / rigFitScale /
-- drawCardPortrait) pour être réutilisable par d'autres vues — d'abord La Chronique, qui préfixe chaque nom
-- de monstre (acteur ET cible) par sa frimousse. Couche RENDER (love.graphics) — hors firewall SIM.
--
-- DÉTERMINISTE PAR ID : le rig vient de Creatures[id] (rig dessiné main, s'il y en a) sinon de
-- CreatureGen.cached(...) résolu depuis Units[id] (type/family/effects/bodyplan/rank). Donc une chronique
-- ARCHIVÉE (qui ne porte que des ids) rend les mêmes frimousses qu'en direct, sans état extérieur.
--
-- CACHE INTERNE par id (comme previewRigs / _rigBounds dans build) : un rig idle figé + sa silhouette
-- OPAQUE mesurée (bounds), construits une fois. La pose ne bouge pas (Rig.update à t=0) -> on peut réutiliser
-- le même char à chaque draw sans le ré-updater.
--
-- HEADLESS-SAFE : sans canvas réel (mock LÖVE), bounds retombe sur une boîte de repli (no-op visuel,
-- jamais de crash), exactement comme Build:rigBounds.

local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen")
local Draw = require("src.ui.draw")
local Palette = require("src.core.palette") -- palette Wraeclast par défaut (le caller n'a pas à la fournir)

local MiniRig = {}

local _rigs = {}   -- [id] = char idle figé (pose calculée une fois)
local _bounds = {} -- [id] = { w, h, top, bot } silhouette opaque (unités virtuelles, origine au sol)

local FIT_PROBE = 96 -- demi-canvas de mesure (origine du rig au centre) : couvre toute créature
-- repli conservateur (mock LÖVE / pas de canvas) : ≈ plus grande créature observée, centrée au sol.
local FALLBACK = { w = 28, h = 26, top = -24, bot = 2 }

-- Construit (ou récupère) le rig figé d'un id. Visuel : rig dessiné MAIN (Creatures[id]) sinon créature
-- GÉNÉRÉE (déterministe par id) résolue via Units[id] — COHÉRENT avec build/arena_draw (même bascule).
function MiniRig.rig(id, palette)
  palette = palette or Palette
  local cached = _rigs[id]
  if cached then return cached end
  local def = Creatures[id]
  if not def then
    local spec = Units[id] or {}
    def = CreatureGen.cached({
      id = id, type = spec.type, family = spec.family,
      effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank,
    })
  end
  local c = Rig.new(def, palette)
  c.facing = 1
  -- DÉTERMINISME : Rig.new tire idlePhase au hasard (love.math.random) -> à t=0, breathe = sin(idlePhase)≠0,
  -- donc la silhouette figée varierait de ~1-2px par instance/rechargement. On force idlePhase=0 -> pose de
  -- REPOS EXACTE (breathe=0), identique à chaque ouverture (une chronique archivée doit être reproductible).
  c.idlePhase = 0
  Rig.update(c, 0, 0) -- fige la pose idle (rig.lua:144 — t=0, frameDt=0 : aucune oscillation)
  _rigs[id] = c
  return c
end

-- Étendue OPAQUE RÉELLE du rig (id) en unités virtuelles relatives à l'origine (~pieds). Mesurée UNE FOIS
-- en rendant la pose idle sur un canvas hors-écran et en scannant les pixels non transparents (mêmes
-- garde-fous que Build:rigBounds : tout pcall, repli sur FALLBACK au moindre manque). Mémoïsée par id.
function MiniRig.bounds(id, palette)
  local cached = _bounds[id]
  if cached then return cached end
  if not (love.graphics and love.graphics.newCanvas and love.graphics.getCanvas) then
    _bounds[id] = FALLBACK; return FALLBACK
  end
  -- dpiscale=1 : sur écran HiDPI/Retina, un newCanvas SANS ce réglage est créé en 2× pixels (dpiscale du
  -- bureau) -> le rig (centré) tombe hors de la fenêtre de scan -> bounds faux -> rigs minuscules. On force le
  -- canvas de MESURE à 1 px = 1 unité virtuelle (purement hors-écran, n'affecte pas le rendu visuel des rigs).
  local okCv, cv = pcall(love.graphics.newCanvas, FIT_PROBE * 2, FIT_PROBE * 2, { dpiscale = 1 })
  if not okCv or not cv then _bounds[id] = FALLBACK; return FALLBACK end
  pcall(cv.setFilter, cv, "nearest", "nearest")
  local c = MiniRig.rig(id, palette)
  local sx, sy, sf = c.x, c.y, c.facing
  c.facing, c.x, c.y = 1, FIT_PROBE, FIT_PROBE -- origine du rig au centre du canvas de mesure
  local ok = pcall(function()
    local prev = love.graphics.getCanvas()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    Rig.draw(c)
    love.graphics.setCanvas(prev)
    love.graphics.pop()
  end)
  c.x, c.y, c.facing = sx, sy, sf -- restaure (le cache de rig est partagé avec le draw)
  if not ok then _bounds[id] = FALLBACK; return FALLBACK end
  local okI, idata = pcall(function() return cv:newImageData() end)
  if not okI or not idata then _bounds[id] = FALLBACK; return FALLBACK end
  local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  -- On scanne les dimensions PIXEL RÉELLES de l'ImageData (robuste même si dpiscale=1 n'a pas été honoré :
  -- HiDPI, arrondis). L'origine du rig est au CENTRE du canvas ; `ratio` ramène les pixels en unités VIRTUELLES
  -- (=1 si 1px=1u, =2 si le canvas est resté 2× HiDPI) -> bounds corrects quelle que soit la densité d'écran.
  local pw, ph = idata:getWidth(), idata:getHeight()
  local cxp, cyp = pw / 2, ph / 2
  local ratio = (pw / (FIT_PROBE * 2))
  if ratio <= 0 then ratio = 1 end
  for y = 0, ph - 1 do
    for x = 0, pw - 1 do
      local okp, _, _, _, a = pcall(function() return idata:getPixel(x, y) end)
      if okp and a and a > 0.2 then
        if x < minx then minx = x end; if x > maxx then maxx = x end
        if y < miny then miny = y end; if y > maxy then maxy = y end
      end
    end
  end
  if minx == math.huge then _bounds[id] = FALLBACK; return FALLBACK end
  local left, right = (minx - cxp) / ratio, (maxx - cxp) / ratio
  local top, bot = (miny - cyp) / ratio, (maxy - cyp) / ratio
  local halfW = math.max(math.abs(left), math.abs(right))
  local res = { w = halfW * 2, h = bot - top, top = top, bot = bot }
  _bounds[id] = res
  return res
end

-- Échelle qui CONTIENT la silhouette (id) dans boxW × boxH (marge 0..1), plafonnée par maxScale.
-- min des deux axes -> la créature tient ENTIÈREMENT (jamais coupée).
function MiniRig.fitScale(id, boxW, boxH, palette, margin, maxScale)
  margin = margin or 0.92
  maxScale = maxScale or 1
  local b = MiniRig.bounds(id, palette)
  local sw = (b.w > 0) and (boxW * margin / b.w) or 1
  local sh = (b.h > 0) and (boxH * margin / b.h) or 1
  return math.min(maxScale, sw, sh)
end

-- DESSINE la frimousse de `id` dans la boîte (x, y, boxW, boxH) en ESPACE DESIGN, CENTRÉE (h et v),
-- CLIPPÉE à la boîte (Draw.scissor — `view` requis pour convertir en pixels écran ; nil = pas de clip,
-- la silhouette tient déjà grâce au fitScale). `facing` (1 = regarde à droite, -1 = à gauche, défaut 1) :
-- l'origine du rig est au CENTRE horizontal (bounds symétriques) -> le miroir reste centré dans la boîte.
-- Renvoie la boîte effective (pour le caller qui avance son curseur).
function MiniRig.draw(view, id, palette, x, y, boxW, boxH, facing)
  local rigc = MiniRig.rig(id, palette)
  local b = MiniRig.bounds(id, palette)
  local s = MiniRig.fitScale(id, boxW, boxH, palette, 0.92, 2.0)
  local cx = x + boxW / 2
  -- centrage VERTICAL : on place le centre de la silhouette opaque au centre de la boîte. La silhouette va
  -- de top..bot (relatif à l'origine au sol) -> son milieu = (top+bot)/2 ; pour le centrer, l'origine doit
  -- descendre à boxCenter - midY*s.
  local midY = (b.top + b.bot) / 2
  local oy = y + boxH / 2 - midY * s
  -- CLIP : on RESTAURE le scissor parent au lieu de l'effacer (la frimousse vit DANS une liste déjà clippée
  -- -> Draw.noScissor() casserait le clip de liste pour les lignes suivantes). La frimousse tient déjà dans
  -- sa boîte (fitScale margin 0.92) ; le clip n'est qu'une ceinture. getScissor peut manquer sous mock -> nil.
  local sx, sy, sw, sh
  if love.graphics.getScissor then sx, sy, sw, sh = love.graphics.getScissor() end
  if view then Draw.scissor(view, x, y, boxW, boxH) end
  love.graphics.push()
  love.graphics.translate(math.floor(cx + 0.5), math.floor(oy + 0.5))
  love.graphics.scale(s, s)
  rigc.x, rigc.y, rigc.facing = 0, 0, (facing == -1) and -1 or 1
  Rig.draw(rigc)
  love.graphics.pop()
  if view then
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
  end
  love.graphics.setColor(1, 1, 1, 1)
  return { x = x, y = y, w = boxW, h = boxH }
end

-- Réinitialise les caches (sécurité tests / changement de palette). Optionnel.
function MiniRig.clear() _rigs = {}; _bounds = {} end

return MiniRig
