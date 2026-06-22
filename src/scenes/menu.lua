-- src/scenes/menu.lua
-- ÉCRAN TITRE "The Pit" (premier écran de la DA). « YOU DESCEND / The Pit » sur fond d'atmosphère
-- (gueule du puits + stalactites + braises), puis les entrées de menu, et un pied de page rappelant la
-- méta-progression (reliques inscrites au Grimoire). On entre dans le Puits depuis ici.
--
-- DA « nightmare forge » (kit src/ui/forge.lua) : le LOGOTYPE gothique « The Pit » (Jacquard) est préservé,
-- mais les ENTRÉES de menu sont des BOUTONS FORGE. ENTER THE PIT = le bouton-œil SIGNATURE (tone='cta',
-- nuée d'yeux qui suivent la souris) ; les autres entrées = boutons forge éco (cadre laiton patiné) ;
-- les entrées scellées = boutons désactivés (grisés, hachurés). Disposés par Layout.column (colonne
-- centrée, gouttières égales) -> aligné au pixel, jamais de trou.
--
-- Couche RENDER/scène (love.graphics autorisé) : atmosphère en pre-pass natif (drawBack), texte en
-- overlay natif. UI composée en ESPACE DESIGN 1280x720 (= virtuel ×4) ; coords souris ×4 pour le hit-test.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Layout = require("src.ui.layout")
local Ambient = require("src.fx.ambient")
local Forge = require("src.ui.forge")          -- KIT « nightmare forge » : bouton-œil CTA + boutons forge
local Grimoire = require("src.core.grimoire")
local Relics = require("src.data.relics")
local Dev = require("src.core.dev") -- MODE DEV : toggle full-unlock (visible/inerte selon Dev.ENABLED)
local T = require("src.core.i18n").t

local Menu = {}
Menu.__index = Menu

local CX = Draw.W / 2
-- Disposition des entrées (colonne centrée, espace design). Le bouton-œil ENTER est un peu plus haut
-- (héros) ; les autres entrées plus compactes. La pile est CENTRÉE dans la bande disponible sous le
-- diviseur (BAND_TOP..BAND_BOTTOM) -> tient quel que soit le nombre d'entrées (dev = +1 « Frame Forge »).
local CTA_W, CTA_H = 300, 58     -- ENTER THE PIT (bouton-œil)
local ITEM_W, ITEM_H = 264, 36   -- entrées secondaires (forge éco)
local ITEMS_GAP = 12
local BAND_TOP, BAND_BOTTOM = 462, 686 -- bande verticale réservée aux entrées (sous le diviseur, au-dessus du pied)

function Menu.new(palette, vw, vh, host)
  local self = setmetatable({}, Menu)
  self.palette = palette
  self.vw, self.vh = vw, vh
  self.host = host
  self.daChrome = true          -- dessine sa propre chrome -> pas de HUD générique
  self.titleKey = "ui.title"
  self.hintKey = "ui.empty"
  self.t = 0
  self.mx, self.my = 0, 0        -- souris en ESPACE DESIGN (pour le regard du bouton-œil)
  self.ambient = Ambient.new(7) -- seed fixe -> atmosphère stable

  -- Entrées : ENTER (CTA héros) + GRIMOIRE/PROVING (forge éco) + RITES (scellée) + ABANDON (forge éco).
  self.items = {
    { id = "enter",    key = "menu.enter",    enabled = true,  tone = "cta", action = function() self.host.newRun() end },
    { id = "grimoire", key = "menu.grimoire", enabled = true,  tone = "eco", action = function() self.host.goto("grimoire") end },
    { id = "proving",  key = "menu.proving",  enabled = true,  tone = "eco", action = function() self.host.goto("playground") end },
    { id = "rites",    key = "menu.rites",    enabled = false, tone = "eco" },
    { id = "abandon",  key = "menu.abandon",  enabled = true,  tone = "eco", action = function() love.event.quit() end },
  }
  -- DEV-ONLY : écran-showcase « Frame Forge » (revue du kit UI « nightmare forge », src/ui/forge.lua).
  -- Inséré avant ABANDON (pied de liste). Présent uniquement si Dev.ENABLED.
  if Dev.ENABLED then
    table.insert(self.items, #self.items, {
      id = "frameforge", key = "menu.frameforge", enabled = true, tone = "eco",
      action = function()
        self.host.scene = require("src.scenes.frameforge").new(self.palette, self.vw, self.vh, self.host)
        self.host.name = "frameforge"
      end,
    })
  end
  self:layout()
  self.hover = nil
  -- Toggle MODE DEV (cheat) — coin haut-gauche, présent UNIQUEMENT si Dev.ENABLED (masqué/inerte en release).
  self.devRect = Dev.ENABLED and { x = 16, y = 14, w = 252, h = 26 } or nil
  return self
end

-- Calcule le rect (ESPACE DESIGN) de chaque entrée via Layout.column (colonne centrée, gouttières égales).
-- ENTER est plus haut/large (héros) ; chaque entrée a sa propre hauteur. La taille croisée est fixée par
-- entrée (align=center) -> chaque bouton est centré horizontalement à sa largeur propre.
function Menu:layout()
  local n = #self.items
  local bandH = BAND_BOTTOM - BAND_TOP
  -- Hauteur d'entrée FITTÉE : on part des tailles de référence, et si la pile déborde la bande (cas DEV
  -- = 1 entrée de plus), on RABOTE la hauteur des entrées secondaires (et le gap) jusqu'à ce que ça tienne
  -- -> aligné, centré, jamais coupé, quel que soit le nombre d'entrées.
  local nSec = n - 1 -- entrées secondaires (toutes sauf le CTA)
  local gap = ITEMS_GAP
  local itemH = ITEM_H
  local function pileH() return CTA_H + nSec * itemH + (n - 1) * gap end
  while pileH() > bandH and (itemH > 26 or gap > 6) do
    if gap > 6 then gap = gap - 1 end
    if itemH > 26 and pileH() > bandH then itemH = itemH - 1 end
  end
  local totalH = pileH()
  local y0 = math.floor(BAND_TOP + math.max(0, (bandH - totalH) / 2))
  local band = { x = math.floor(CX - CTA_W / 2), y = y0, w = CTA_W, h = totalH }
  local specs = {}
  for i, it in ipairs(self.items) do
    local cta = (it.tone == "cta")
    specs[i] = { size = cta and CTA_H or itemH, w = cta and CTA_W or ITEM_W }
  end
  local rows = Layout.column(band, specs, { gap = gap, align = "center" })
  for i, it in ipairs(self.items) do it.rect = rows[i] end
end

-- Indice de l'entrée sous (dx,dy) en coords design, ou nil (entrées scellées ignorées).
function Menu:itemAt(dx, dy)
  for i, it in ipairs(self.items) do
    local r = it.rect
    if it.enabled and r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
      return i
    end
  end
  return nil
end

function Menu:update(dt)
  self.t = self.t + (dt or 1)
  self.ambient:update(dt)
  Forge.uiTick((dt or 1) / 60) -- horloge des widgets forge (en SECONDES ; dt ~1.0/tick au 1/60)
end

-- Pre-pass : atmosphère native derrière (le menu n'a pas de monde pixel).
function Menu:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("menu")
  Draw.finish()
end

function Menu:drawWorld() end -- aucun monde pixel (canvas laissé transparent)

-- Titre gothique avec halo sang (faux bloom : passes décalées en dim puis le titre net).
local function drawTitleGlow(str, cx, y, font)
  local c = Theme.c
  local off = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 2, 2 }, { -2, -2 } }
  for _, o in ipairs(off) do Draw.textC(str, cx + o[1], y + o[2], { c.blood[1], c.blood[2], c.blood[3], 0.16 }, font) end
  Draw.textC(str, cx, y, c.title, font)
end

function Menu:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- Kicker (saveur, serif romain lisible) + logotype gothique (PRÉSERVÉ : Jacquard).
  Draw.textTrackedC(T("menu.descend"), CX, 250, c.faint, Theme.loreRoman(20), 8)
  drawTitleGlow(T("menu.title"), CX, 280, Theme.display(128))
  Draw.divider(CX, 444, 300, c.blood, 1)

  -- Entrées : boutons forge. ENTER = bouton-œil (cta, regard depuis la souris) ; les autres = forge éco ;
  -- les scellées = désactivées (grisé hachuré). L'état hover/active vient du hit-test de la scène.
  for i, it in ipairs(self.items) do
    local r = it.rect
    local hov = (self.hover == i)
    Forge.uiButton("menu." .. it.id, r.x, r.y, r.w, r.h, T(it.key),
      { tone = it.tone, hover = it.enabled and hov, active = it.enabled and hov and self.down,
        disabled = not it.enabled, mouse = { mx = self.mx, my = self.my },
        fontSz = (it.tone == "cta") and 9 or 8, eyeR = 7, t = self.t / 60 })
  end

  -- Pied : reliques inscrites (méta-progression) à gauche, tag à droite.
  local inscribed = (Grimoire.count and Grimoire.count()) or 0
  Draw.text(T("menu.relics", { n = inscribed, total = #Relics.order }), 24, 690, c.fainter, Theme.ui(12))
  Draw.textR(T("menu.tag"), Draw.W - 24, 690, c.ghost, Theme.ui(12))

  -- Toggle MODE DEV (coin haut-gauche) : visible seulement si Dev.ENABLED. Libellé en dur (dev-only).
  if self.devRect then
    local on, r = Dev.fullUnlock(), self.devRect
    Draw.rect(r.x, r.y, r.w, r.h, c.panelDeep, on and c.gold or c.hair, 1)
    Draw.text(on and "[DEV] FULL UNLOCK: ON" or "[DEV] FULL UNLOCK: OFF", r.x + 10, r.y + 7,
      on and c.goldBright or c.fainter, Theme.ui(11))
  end

  Draw.finish()
end

-- Souris : hover (mousemoved) + activation (mousepressed). Coords virtuelles -> design (×4).
function Menu:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.hover = self:itemAt(dx, dy)
end

function Menu:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if self.devRect then -- MODE DEV : clic sur le toggle full-unlock
    local r = self.devRect
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then Dev.toggleFullUnlock(); return end
  end
  local i = self:itemAt(dx, dy)
  if i then self.hover = i; self.down = true end
end

function Menu:mousereleased(vx, vy, button)
  if button ~= 1 then return end
  self.down = false
  local i = self:itemAt(vx * 4, vy * 4)
  if i and self.items[i].action then self.items[i].action() end
end

-- Clavier : navigation haut/bas parmi les entrées actives + entrée/espace pour valider.
function Menu:keypressed(key)
  if key == "up" or key == "down" then
    local order = {}
    for i, it in ipairs(self.items) do if it.enabled then order[#order + 1] = i end end
    if #order == 0 then return end
    local cur = 1
    for k, i in ipairs(order) do if i == self.hover then cur = k end end
    cur = cur + (key == "down" and 1 or -1)
    if cur < 1 then cur = #order elseif cur > #order then cur = 1 end
    self.hover = order[cur]
  elseif key == "return" or key == "kpenter" or key == "space" then
    if self.hover and self.items[self.hover].action then self.items[self.hover].action() end
  elseif key == "u" and Dev.ENABLED then -- MODE DEV : toggle full-unlock du codex
    Dev.toggleFullUnlock()
  end
end

return Menu
