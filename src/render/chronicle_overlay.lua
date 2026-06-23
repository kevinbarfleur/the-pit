-- src/render/chronicle_overlay.lua
-- LA CHRONIQUE — overlay MODAL, ouvrable n'importe où ([c]) et figeant le jeu derrière. Voile plein écran
-- + SÉLECTEUR DE ROUND (carrousel ‹ ... ›) + le panneau journal (chronicle_draw) pour la chronique choisie.
-- Le host route les inputs ici tant qu'il est ouvert -> aucune interaction ne termine un match (le bug à corriger).

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Forge = require("src.ui.forge")       -- boutons-icône forge (‹ › carrousel + X de fermeture)
local Chronicle = require("src.render.chronicle")
local ChronicleDraw = require("src.render.chronicle_draw")
local MonsterCard = require("src.render.monstercard") -- fiche TCG flottante au survol d'un nom (J4)
local T = require("src.core.i18n").t

local Overlay = {}
Overlay.__index = Overlay

-- `currentChron` = chronique du combat EN COURS (si on ouvre depuis le combat), sinon nil. `run.chronicles`
-- = l'historique archivé (du plus récent au plus ancien). Le carrousel parcourt [courant] + archives.
function Overlay.new(run, currentChron)
  local sources = {}
  if currentChron then sources[#sources + 1] = { label = T("chronicle.now"), model = currentChron } end
  if run and run.chronicles then
    for i = #run.chronicles, 1, -1 do
      local a = run.chronicles[i]
      local res = a.win and T("chronicle.win") or T("chronicle.loss")
      sources[#sources + 1] = {
        label = T("chronicle.round", { n = a.round or i }) .. "  -  " .. res,
        model = Chronicle.fromEntries(a.entries),
      }
    end
  end
  if #sources == 0 then sources[1] = { label = T("chronicle.empty_hist"), model = Chronicle.fromEntries({}) } end
  return setmetatable({ sources = sources, sel = 1, panel = ChronicleDraw.new(sources[1].model),
    mx = -1, my = -1, t = 0 }, Overlay)
end

local function inR(mx, my, r) return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h end

-- Les inputs arrivent en espace VIRTUEL (main.lua:toVirtual divise par view.scale -> 320×180). Mais TOUTE
-- l'UI de l'overlay (et du panel) est composée en espace DESIGN 1280×720 (= virtuel ×4, la convention de
-- src/ui/draw.lua). On convertit donc ici, à l'unique point d'entrée souris. Le facteur est CONSTANT (×4 :
-- design = VW×4), indépendant de view.scale (qui, lui, mappe écran->virtuel). [Corrige le hit-test des
-- boutons/du carrousel, jusqu'ici en facteur 4 -> jamais déclenché à la souris ; RENDER pur, golden inchangé.]
local function toDesign(vx, vy) return vx * 4, vy * 4 end

function Overlay:_select(i)
  if i < 1 or i > #self.sources or i == self.sel then return end
  self.sel = i
  self.panel:setChron(self.sources[i].model)
end

function Overlay:draw(view)
  local c = Theme.c
  self.t = self.t + 1 / 60 -- horloge locale (overlay modal sans boucle update) : respiration de la fiche au survol
  Draw.begin(view)
  Forge.uiTick(1 / 60) -- horloge des boutons forge (overlay modal : pas de boucle update -> tick au rendu)
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 0.93 }) -- voile : le jeu derrière est figé
  Draw.text(T("chronicle.title"), 24, 16, c.title, Theme.display(30))
  Draw.textR(T("chronicle.close_hint"), Draw.W - 24 - 26 - 12, 26, c.fainter, Theme.read(12)) -- hint clavier (complément)

  -- Carrousel de round : [‹] label [›]  +  i / n. Boutons-ICÔNE FORGE (le carrousel texte est retiré).
  local font = Theme.read(15)
  local label = self.sources[self.sel].label
  local lw = Draw.textWidth(label, font)
  local cy = 50
  local many = #self.sources > 1
  Draw.text(label, math.floor(Draw.W / 2 - lw / 2), cy + 4, c.title, font)
  Draw.textC(string.format("%d / %d", self.sel, #self.sources), Draw.W / 2, cy + 24, c.fainter, Theme.read(11))
  -- rects des boutons (espace design) : flèches de part et d'autre du label, X en haut à droite.
  local BS = 26
  self._prev = { x = math.floor(Draw.W / 2 - lw / 2 - BS - 12), y = cy, w = BS, h = BS }
  self._next = { x = math.floor(Draw.W / 2 + lw / 2 + 12), y = cy, w = BS, h = BS }
  self._close = { x = Draw.W - 24 - BS, y = 16, w = BS, h = BS }
  Draw.finish()

  -- boutons forge (icon) : seulement si plusieurs rounds pour les flèches ; le X est toujours présent.
  Draw.begin(view)
  if many then
    Forge.uiButton("chron.ov.prev", self._prev.x, self._prev.y, BS, BS, "",
      { tone = "icon", cost = "left", hover = inR(self.mx, self.my, self._prev) })
    Forge.uiButton("chron.ov.next", self._next.x, self._next.y, BS, BS, "",
      { tone = "icon", cost = "right", hover = inR(self.mx, self.my, self._next) })
  end
  Forge.uiButton("chron.ov.close", self._close.x, self._close.y, BS, BS, "",
    { tone = "icon", cost = "gear", hover = inR(self.mx, self.my, self._close) })
  -- CROIX nette par-dessus le cadre forge (lecture « fermer » sans ambiguïté avec la roue).
  local xc = self._close.x + BS / 2
  local yc = self._close.y + BS / 2
  local cl = inR(self.mx, self.my, self._close) and c.inkBright or c.muted
  for d = -4, 4 do
    Draw.rect(xc + d - 0.5, yc + d - 0.5, 2, 2, cl)
    Draw.rect(xc + d - 0.5, yc - d - 0.5, 2, 2, cl)
  end
  Draw.finish()

  self.panel:draw(view, 24, 92, Draw.W - 48, Draw.H - 108)

  -- FICHE de monstre au SURVOL d'un nom (J4) : dessinée AU NIVEAU OVERLAY, PAR-DESSUS la liste et HORS de
  -- son clip (la carte déborde volontairement du panneau). Ancrée au curseur (en design), rebond sur les
  -- bords géré par MonsterCard. Sprite FIGÉ (pas de rig animé passé) : une fiche posée, pas vivante.
  local hid = self.panel:hoveredName()
  if hid then
    Draw.begin(view)
    MonsterCard.draw(view, nil, hid, self.mx, self.my, self.t)
    Draw.finish()
  end
end

function Overlay:mousemoved(vx, vy)
  self.mx, self.my = toDesign(vx, vy) -- mémorise en DESIGN (cohérent avec les rects de l'overlay/panel)
  self.panel:mousemoved(self.mx, self.my) -- propage : le panel détecte le NOM survolé (carte au survol, J4)
end

-- Renvoie "close" si le X a été cliqué (main.lua referme l'overlay), sinon true (modal : capte tout).
function Overlay:mousepressed(vx, vy)
  local dx, dy = toDesign(vx, vy)
  if inR(dx, dy, self._close) then return "close" end
  if inR(dx, dy, self._prev) then self:_select(self.sel - 1); return true end
  if inR(dx, dy, self._next) then self:_select(self.sel + 1); return true end
  self.panel:mousepressed(dx, dy)
  return true -- MODAL : capte tout (rien ne fuit vers la scène derrière)
end

function Overlay:wheelmoved(dx, dy) self.panel:wheelmoved(dx, dy) end

function Overlay:keypressed(key)
  if key == "left" then self:_select(self.sel - 1)
  elseif key == "right" then self:_select(self.sel + 1) end
end

return Overlay
