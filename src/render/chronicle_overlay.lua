-- src/render/chronicle_overlay.lua
-- LA CHRONIQUE — overlay MODAL, ouvrable n'importe où ([c]) et figeant le jeu derrière. Voile plein écran
-- + SÉLECTEUR DE ROUND (carrousel ‹ ... ›) + le panneau journal (chronicle_draw) pour la chronique choisie.
-- Le host route les inputs ici tant qu'il est ouvert -> aucune interaction ne termine un match (le bug à corriger).

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
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
  return setmetatable({ sources = sources, sel = 1, panel = ChronicleDraw.new(sources[1].model) }, Overlay)
end

function Overlay:_select(i)
  if i < 1 or i > #self.sources or i == self.sel then return end
  self.sel = i
  self.panel:setChron(self.sources[i].model)
end

function Overlay:draw(view)
  local c = Theme.c
  Draw.begin(view)
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 0.93 }) -- voile : le jeu derrière est figé
  Draw.text(T("chronicle.title"), 24, 16, c.title, Theme.display(30))
  Draw.textR(T("chronicle.close_hint"), Draw.W - 24, 26, c.muted, Theme.read(13))

  -- Carrousel de round : ‹ label ›  +  i / n  (robuste quel que soit le nombre de rounds).
  local font = Theme.read(15)
  local label = self.sources[self.sel].label
  local lw = Draw.textWidth(label, font)
  local cxL = math.floor(Draw.W / 2 - lw / 2)
  local cy = 58
  local arrowCol = (#self.sources > 1) and c.goldBright or c.line
  Draw.text("<", cxL - 30, cy - 2, arrowCol, Theme.read(20))
  Draw.text(">", cxL + lw + 14, cy - 2, arrowCol, Theme.read(20))
  Draw.text(label, cxL, cy, c.title, font)
  Draw.textC(string.format("%d / %d", self.sel, #self.sources), Draw.W / 2, cy + 22, c.fainter, Theme.read(11))
  self._prev = { x = cxL - 34, y = cy - 4, w = 24, h = 26 }
  self._next = { x = cxL + lw + 10, y = cy - 4, w = 24, h = 26 }
  Draw.finish()

  self.panel:draw(view, 24, 92, Draw.W - 48, Draw.H - 108)
end

local function ptIn(px, py, r) return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Overlay:mousepressed(vx, vy)
  if ptIn(vx, vy, self._prev) then self:_select(self.sel - 1); return true end
  if ptIn(vx, vy, self._next) then self:_select(self.sel + 1); return true end
  self.panel:mousepressed(vx, vy)
  return true -- MODAL : capte tout (rien ne fuit vers la scène derrière)
end

function Overlay:wheelmoved(dx, dy) self.panel:wheelmoved(dx, dy) end

function Overlay:keypressed(key)
  if key == "left" then self:_select(self.sel - 1)
  elseif key == "right" then self:_select(self.sel + 1) end
end

return Overlay
