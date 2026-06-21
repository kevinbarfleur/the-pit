-- src/scenes/grimoire.lua
-- LE GRIMOIRE (pilier #2, méta-progression) : codex/COLLECTION PERSISTANT des reliques. Une relique
-- RENCONTRÉE (collectée en run, cf. src/core/grimoire) y est inscrite à VIE au niveau du compte ; on y voit
-- son icône, son nom, son effet et son flavor. Les non rencontrées restent voilées (« the ink runs here »).
-- Modèle LISIBLE (cf. docs/research/relics-design.md). [esc] -> retour menu (géré par main).
--
-- Lecture seule : Relics.order (toutes les reliques) × Grimoire.isKnown (état persistant). Liste à gauche,
-- détail à droite. Atmosphère calme (mode "grimoire"). daChrome=true. [esc] -> retour menu (géré par main).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local Relics = require("src.data.relics")
local Grimoire = require("src.core.grimoire")
local RelicGen = require("src.gen.relicgen") -- icones bakees (artefact reel) pour les reliques collectees
local T = require("src.core.i18n").t

local Screen = {}
Screen.__index = Screen

-- Repli procedural (pip) quand une icone manque : type -> forme/couleur. Les reliques collectees montrent
-- leur VRAIE icone ; ceci ne sert que de garde-fou.
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
}

local LIST_X, LIST_Y, LIST_W, ROW_H, ROW_GAP = 32, 122, 372, 40, 8
local DET_X, DET_Y, DET_W, DET_H = 436, 122, 810, 552

function Screen.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    sel = 1,
    ambient = Ambient.new(5),
  }, Screen)
  self:refresh()
  return self
end

-- (Re)lit l'état d'identification (la persistance peut changer entre deux ouvertures).
function Screen:refresh()
  self.rows = {}
  for _, id in ipairs(Relics.order) do
    self.rows[#self.rows + 1] = { id = id, known = Grimoire.isKnown and Grimoire.isKnown(id) or false }
  end
  self.known = 0
  for _, r in ipairs(self.rows) do if r.known then self.known = self.known + 1 end end
end

local function rowRect(i) return { x = LIST_X, y = LIST_Y + (i - 1) * (ROW_H + ROW_GAP), w = LIST_W, h = ROW_H } end
local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

-- Blit d'une icône bakée centrée sur (cx, cy) à scale ENTIER (pixel-perfect, sans teinte). Renvoie true si dessinée.
local function drawIconC(baked, cx, cy, scale)
  if not baked or not baked.image then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(baked.image, math.floor(cx - 8 * scale), math.floor(cy - 8 * scale), 0, scale, scale)
  return true
end

function Screen:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
end

function Screen:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("grimoire")
  Draw.finish()
end

function Screen:drawWorld() end

function Screen:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- En-tête.
  Draw.text(T("grimoire.title"), LIST_X, 30, c.title, Theme.display(44))
  Draw.text(T("grimoire.subtitle", { n = self.known, total = #self.rows }):upper(), LIST_X + 2, 86, c.faint, Theme.ui(10))
  Draw.textR(T("grimoire.back"), Draw.W - 32, 36, c.ghost, Theme.ui(11))

  -- Liste (gauche).
  for i, row in ipairs(self.rows) do
    local r = rowRect(i)
    local sel = (self.sel == i)
    Draw.rect(r.x, r.y, r.w, r.h, sel and c.panel or c.panelDeep, sel and c.ecoBorder or c.line, 1)
    if not (row.known and drawIconC(RelicGen.cached(row.id, self.palette), r.x + 22, r.y + r.h / 2, 2)) then
      local emt = RELIC_TYPE[row.id] or "bone"
      Draw.pip(emt, r.x + 22, r.y + r.h / 2, 7, row.known and Theme.type(emt).color or c.lock)
    end
    Draw.text(row.known and T("relic." .. row.id .. ".name") or T("grimoire.unknown"),
      r.x + 44, r.y + r.h / 2 - 6, row.known and c.title or c.fainter, Theme.ui(12))
    Draw.textR(row.known and T("grimoire.inked") or T("grimoire.cryptic"), r.x + r.w - 12, r.y + r.h / 2 - 5,
      c.fainter, Theme.ui(9))
  end

  -- Détail (droite).
  self:drawDetail(c)

  Draw.finish()
end

function Screen:drawDetail(c)
  Draw.rect(DET_X, DET_Y, DET_W, DET_H, c.panelDeep, c.hair, 1)
  local row = self.rows[self.sel]
  if not row then return end
  local cx = DET_X + DET_W / 2
  local emblemType = RELIC_TYPE[row.id] or "bone"
  local tcol = row.known and Theme.type(emblemType).color or c.lock

  if not (row.known and drawIconC(RelicGen.cached(row.id, self.palette), cx, DET_Y + 64, 4)) then
    Draw.pip(emblemType, cx, DET_Y + 64, 26, tcol)
  end
  Draw.textC(row.known and T("relic." .. row.id .. ".name") or T("grimoire.unknown"), cx, DET_Y + 100,
    row.known and c.title or c.fainter, Theme.uiBold(22))
  Draw.divider(cx, DET_Y + 150, 260, c.fainter, 1)

  -- Corps de lore (saveur romaine, lisible).
  local body = row.known and T("relic." .. row.id .. ".flavor") or T("grimoire.body_unknown")
  Draw.textWrap(body, DET_X + 60, DET_Y + 176, DET_W - 120, row.known and c.body or c.dim, Theme.loreRoman(18), "center")

  -- Effet (en pied) : réel si inscrit, sinon notes cryptiques.
  Draw.text(T(row.known and "grimoire.effect_known" or "grimoire.effect_unknown"), DET_X + 40, DET_Y + DET_H - 78,
    c.fainter, Theme.ui(10))
  Draw.textWrap(row.known and T("relic." .. row.id .. ".effect") or T("grimoire.effect_pending"),
    DET_X + 40, DET_Y + DET_H - 58, DET_W - 80, row.known and c.goldBright or c.faint, Theme.ui(12))
end

function Screen:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  for i = 1, #self.rows do if ptIn(dx, dy, rowRect(i)) then self.hover = i; return end end
  self.hover = nil
end

function Screen:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  for i = 1, #self.rows do if ptIn(dx, dy, rowRect(i)) then self.sel = i; return end end
end

function Screen:keypressed(key)
  if key == "up" then self.sel = (self.sel - 2) % #self.rows + 1
  elseif key == "down" then self.sel = self.sel % #self.rows + 1
  elseif key == "g" then self.host.goto("menu") end
end

return Screen
