-- src/render/chronicle_overlay.lua
-- LA CHRONIQUE — overlay MODAL, ouvrable n'importe où ([c]) et figeant le jeu derrière. Voile plein écran
-- + SÉLECTEUR DE ROUND (carrousel ‹ ... ›) + le panneau journal (chronicle_draw) pour la chronique choisie.
-- Le host route les inputs ici tant qu'il est ouvert -> aucune interaction ne termine un match (le bug à corriger).

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Forge = require("src.ui.forge")       -- boutons-icône forge (‹ › carrousel + X de fermeture)
local Chronicle = require("src.render.chronicle")
local ChronicleDraw = require("src.render.chronicle_draw")
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
    mx = -1, my = -1 }, Overlay)
end

local function inR(mx, my, r) return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h end

function Overlay:_select(i)
  if i < 1 or i > #self.sources or i == self.sel then return end
  self.sel = i
  self.panel:setChron(self.sources[i].model)
end

function Overlay:draw(view)
  local c = Theme.c
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
end

function Overlay:mousemoved(vx, vy) self.mx, self.my = vx, vy end

-- Renvoie "close" si le X a été cliqué (main.lua referme l'overlay), sinon true (modal : capte tout).
function Overlay:mousepressed(vx, vy)
  if inR(vx, vy, self._close) then return "close" end
  if inR(vx, vy, self._prev) then self:_select(self.sel - 1); return true end
  if inR(vx, vy, self._next) then self:_select(self.sel + 1); return true end
  self.panel:mousepressed(vx, vy)
  return true -- MODAL : capte tout (rien ne fuit vers la scène derrière)
end

function Overlay:wheelmoved(dx, dy) self.panel:wheelmoved(dx, dy) end

function Overlay:keypressed(key)
  if key == "left" then self:_select(self.sel - 1)
  elseif key == "right" then self:_select(self.sel + 1) end
end

return Overlay
