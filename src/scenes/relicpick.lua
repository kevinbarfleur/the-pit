-- src/scenes/relicpick.lua
-- ÉCRAN RELIQUE 1-PARMI-3. Après une victoire d'acquisition, « quelque chose remonte du Puits » : on choisit
-- UNE relique parmi 3 offertes. L'EFFET est AFFICHÉ clairement (modèle lisible, cf. docs/research/relics-design.md) ;
-- le choix est confirmé par BIND THE FRAGMENT.
--
-- Couche scène (love.graphics) : atmosphère native (drawBack) + cartes en overlay design. daChrome=true.
-- Le host fournit les choix (ids de reliques, tirés seedé par RunState:rollRelicChoices) et reçoit le
-- pick via host.finishRelicPick(id). Glyphes Unicode non garantis -> EMBLÈME procédural (Draw.pip) par relique.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local T = require("src.core.i18n").t

local Relicpick = {}
Relicpick.__index = Relicpick

-- Emblème par relique = un type (forme + couleur du pip). Variété visuelle sans glyphe Unicode.
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
}

local CARD_W, CARD_H, GAP, CARD_Y = 300, 372, 36, 206

function Relicpick.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    choices = payload.choices or {},
    sel = nil, hover = nil,
    ambient = Ambient.new(33),
  }, Relicpick)

  -- Géométrie des cartes (espace design), centrée selon le nombre de choix.
  local n = #self.choices
  self.cards = {}
  local total = n * CARD_W + (n - 1) * GAP
  local x0 = (Draw.W - total) / 2
  for i = 1, n do
    self.cards[i] = { x = x0 + (i - 1) * (CARD_W + GAP), y = CARD_Y, w = CARD_W, h = CARD_H }
  end
  self.bind = { x = (Draw.W - 300) / 2, y = 628, w = 300, h = 52 } -- bouton BIND (design)
  return self
end

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Relicpick:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
end

function Relicpick:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("relic")
  Draw.finish()
end

function Relicpick:drawWorld() end

function Relicpick:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- En-tête : kicker (saveur romaine) + titre gothique iconique.
  Draw.textC(T("relicpick.kicker"), Draw.W / 2, 64, c.faint, Theme.loreRoman(18))
  Draw.textC(T("relicpick.title"), Draw.W / 2, 92, c.title, Theme.display(52))

  -- Cartes.
  for i, card in ipairs(self.cards) do
    local id = self.choices[i]
    local sel, hov = (self.sel == i), (self.hover == i)
    local emblem = Theme.type(RELIC_TYPE[id] or "bone")
    local border = sel and c.gold or (hov and c.ecoBorder or c.hair)
    local fill = sel and c.panel or c.panelDeep
    Draw.rect(card.x, card.y, card.w, card.h, fill, border, 2)

    Draw.pip(RELIC_TYPE[id] or "bone", card.x + card.w / 2, card.y + 74, 30)
    Draw.textC(T("relic." .. id .. ".name"), card.x + card.w / 2, card.y + 124, sel and c.title or c.name, Theme.uiBold(20))
    Draw.textWrap(T("relic." .. id .. ".flavor"), card.x + 28, card.y + 168, card.w - 56, c.dim, Theme.loreRoman(16), "center")
    Draw.textWrap(T("relic." .. id .. ".effect"), card.x + 24, card.y + card.h - 72, card.w - 48,
      sel and c.gold or c.name, Theme.ui(13), "center")
    -- liseré coloré (rappel d'emblème) en pied de carte
    Draw.rect(card.x + 24, card.y + card.h - 14, card.w - 48, 2, emblem.color)
  end

  -- Bouton BIND (actif seulement si une carte est choisie).
  local ok = self.sel ~= nil
  Draw.button(self.bind.x, self.bind.y, self.bind.w, self.bind.h,
    ok and T("relicpick.bind") or T("relicpick.choose"), Theme.uiBold(14),
    { fill = ok and c.bloodDeep or c.panelDeep, border = ok and c.blood or c.bloodEdge, text = ok and c.ctaText or c.fainter })

  Draw.finish()
end

function Relicpick:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.hover = nil
  for i, card in ipairs(self.cards) do if ptIn(dx, dy, card) then self.hover = i; break end end
end

function Relicpick:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  for i, card in ipairs(self.cards) do
    if ptIn(dx, dy, card) then self.sel = i; return end
  end
  if self.sel and ptIn(dx, dy, self.bind) then self:confirm() end
end

function Relicpick:keypressed(key)
  if key == "1" or key == "2" or key == "3" then
    local i = tonumber(key)
    if self.choices[i] then self.sel = i end
  elseif (key == "return" or key == "kpenter" or key == "space") and self.sel then
    self:confirm()
  end
end

function Relicpick:confirm()
  local id = self.choices[self.sel]
  if id and self.host.finishRelicPick then self.host.finishRelicPick(id) end
end

return Relicpick
