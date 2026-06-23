-- src/scenes/relicpick.lua
-- ÉCRAN RELIQUE 1-PARMI-3. Après une victoire d'acquisition, « quelque chose remonte du Puits » : on choisit
-- UNE relique parmi 3 offertes. L'EFFET est AFFICHÉ clairement (modèle lisible, cf. docs/research/relics-design.md) ;
-- le choix est confirmé par BIND THE FRAGMENT.
--
-- DA « nightmare forge » (kit src/ui/forge.lua) : chaque carte = une PLAQUE forge qui respire (Forge.uiCard :
-- matière + cadre laiton patiné + veines + œil qui guette sur la sélection « héros »), avec l'ARTEFACT baké
-- (RelicGen.cached) en cœur de carte, posé PAR-DESSUS via Layout (gem d'accent + nom + effet clair + flavor).
-- États : repos (sobre) / survol (liseré accent) / SÉLECTIONNÉE (liseré allumé + œil + gem qui pulse = héros).
-- Le BIND est le bouton-œil SIGNATURE (Forge.uiButton tone='cta', regard piloté par la souris de la scène).
--
-- Couche scène (love.graphics) : atmosphère native (drawBack) + cartes en overlay design. daChrome=true.
-- Le host fournit les choix (ids de reliques, tirés seedé par RunState:rollRelicChoices) et reçoit le
-- pick via host.finishRelicPick(id).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Layout = require("src.ui.layout")
local Ambient = require("src.fx.ambient")
local Forge = require("src.ui.forge")       -- KIT « nightmare forge » : plaque-carte + bouton-œil CTA
local RelicGen = require("src.gen.relicgen") -- icones bakees des reliques (le vrai artefact)
local RunState = require("src.run.state")    -- pour DECLINE_RELIC_GOLD (or accordé au refus)
local T = require("src.core.i18n").t

local Relicpick = {}
Relicpick.__index = Relicpick

-- Emblème par relique = une FAMILLE forge (forme + couleur de la gem d'accent). Variété visuelle, sans
-- glyphe Unicode. Les clés correspondent à Forge.FAM (flesh/bone/order/abyss/arcane).
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
}

-- Géométrie (espace design 1280×720). Les cartes sont disposées par Layout.row (gouttières égales,
-- bande centrée) -> jamais de trou ni de carte mal alignée.
local CARD_W, CARD_H, GAP, CARD_Y = 300, 372, 36, 206
local BIND_W, BIND_H, BIND_Y = 320, 60, 622
-- REFUSE (éco-bouton secondaire) posé À DROITE du BIND, même ligne : refuser l'offre -> +or. Calque visuel
-- exact du REFUSER des grants de slot (Forge.uiButton tone='eco' + diamant de coût montrant l'or accordé).
local DECLINE_W, DECLINE_GAP = 160, 24
local ICON_SCALE = 6 -- artefact 16×16 -> 96×96 (scale entier net), cœur de carte

function Relicpick.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    choices = payload.choices or {},
    sel = nil, hover = nil,
    mx = 0, my = 0, -- souris en ESPACE DESIGN (pour le regard du bouton-œil)
    ambient = Ambient.new(33),
  }, Relicpick)

  -- Géométrie des cartes (espace design), bande centrée via Layout.row.
  local n = #self.choices
  self.cards = {}
  if n > 0 then
    local total = n * CARD_W + (n - 1) * GAP
    local band = { x = math.floor((Draw.W - total) / 2), y = CARD_Y, w = total, h = CARD_H }
    local specs = {}
    for i = 1, n do specs[i] = { size = CARD_W } end
    local cols = Layout.row(band, specs, { gap = GAP, align = "stretch" })
    for i = 1, n do self.cards[i] = cols[i] end
  end
  -- Artefacts bakés (le vrai objet maudit) par choix.
  self.icons = {}
  for i = 1, n do self.icons[i] = RelicGen.cached(self.choices[i], palette) end
  self.bind = { x = math.floor((Draw.W - BIND_W) / 2), y = BIND_Y, w = BIND_W, h = BIND_H }
  -- REFUSE : éco-bouton secondaire, posé à DROITE du BIND sur la même ligne (refuser -> +or).
  self.decline = { x = self.bind.x + BIND_W + DECLINE_GAP, y = BIND_Y, w = DECLINE_W, h = BIND_H }
  return self
end

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Relicpick:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  Forge.uiTick(frameDt / 60) -- horloge des widgets forge (en SECONDES ; frameDt ~1.0/tick au 1/60)
end

function Relicpick:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("relic")
  Draw.finish()
end

function Relicpick:drawWorld() end

-- Une carte de relique forge : FOND = plaque qui respire (Forge.uiCard, accent de la famille, œil qui
-- guette quand sélectionnée = « héros »), puis le contenu posé PAR-DESSUS en colonne Layout.
function Relicpick:drawCard(i)
  local card, c = self.cards[i], Theme.c
  local id = self.choices[i]
  local sel, hov = (self.sel == i), (self.hover == i)
  local fam = RELIC_TYPE[id] or "bone"
  local emblem = Theme.type(fam)
  -- accent du cadre : allumé (or vif) si sélectionné, tiède au survol, sobre au repos.
  local accCol = sel and Forge.accentFrom(c.goldBright)
    or (hov and Forge.accentFrom(c.gold) or nil)

  -- FOND forge : plaque qui respire + cadre patiné. `rich` (œil + cadre épais) sur la SÉLECTION (héros).
  Forge.uiCard("relicpick.card." .. i, card.x, card.y, card.w, card.h,
    { px = 2, seed = 60 + (#id), accentCol = accCol, rich = sel, t = self.t / 60 })

  -- CONTENU en colonne Layout (aucune poche vide) : artefact > gem+nom > effet clair > flavor.
  local inner = Layout.inset(card, 22)
  local rows = Layout.column(inner, {
    { size = 110 },  -- 1 artefact baké (cœur lumineux)
    { size = 16 },   -- 2 gem d'accent (famille)
    { size = 30 },   -- 3 nom (or)
    { flex = 1 },    -- 4 effet clair (le reste haut)
    { size = 46 },   -- 5 flavor (pied)
  }, { gap = 6, align = "stretch" })
  local rArt, rGem, rName, rEff, rFlav = rows[1], rows[2], rows[3], rows[4], rows[5]

  -- (1) ARTEFACT : l'icône bakée (le vrai objet), centrée, scale entier net.
  local baked = self.icons[i]
  if baked and baked.image then
    love.graphics.setColor(1, 1, 1, 1)
    local ix = math.floor(rArt.x + rArt.w / 2 - 8 * ICON_SCALE)
    local iy = math.floor(rArt.y + rArt.h / 2 - 8 * ICON_SCALE)
    love.graphics.draw(baked.image, ix, iy, 0, ICON_SCALE, ICON_SCALE)
  else
    Draw.pip(fam, rArt.x + rArt.w / 2, rArt.y + rArt.h / 2, 30)
  end

  -- (2) GEM d'accent (famille) centrée : un diamant forge teinté, qui pulse sur la sélection.
  Forge.diamondAt(rGem.x + rGem.w / 2, rGem.y + rGem.h / 2, sel and 4 or 3,
    sel and c.goldBright or emblem.color, emblem.dark)

  -- (3) NOM (or, gothique-fonctionnel) centré.
  Draw.textC(T("relic." .. id .. ".name"), rName.x + rName.w / 2, rName.y + 2,
    sel and c.inkBright or c.title, Theme.uiBold(20))

  -- (4) EFFET CLAIR (le coeur du modèle lisible) : enroulé, or vif sur la sélection.
  Draw.textWrap(T("relic." .. id .. ".effect"), rEff.x, rEff.y, rEff.w,
    sel and c.goldBright or c.name, Theme.ui(13), "center")

  -- (5) FLAVOR (serif d'ambiance, éteint) en pied de carte.
  Draw.textWrap(T("relic." .. id .. ".flavor"), rFlav.x, rFlav.y, rFlav.w,
    c.dim, Theme.loreRoman(15), "center")
end

function Relicpick:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- En-tête : kicker (saveur romaine) + titre gothique iconique.
  Draw.textC(T("relicpick.kicker"), Draw.W / 2, 64, c.faint, Theme.loreRoman(18))
  Draw.textC(T("relicpick.title"), Draw.W / 2, 92, c.title, Theme.display(52))

  -- Cartes forge.
  for i = 1, #self.cards do self:drawCard(i) end

  -- BIND : bouton-œil SIGNATURE (tone='cta'), regard piloté par la souris ; actif si une carte est choisie.
  local ok = self.sel ~= nil
  Forge.uiButton("relicpick.bind", self.bind.x, self.bind.y, self.bind.w, self.bind.h,
    ok and T("relicpick.bind") or T("relicpick.choose"),
    { tone = "cta", hover = self.bindHover, active = self.bindDown, disabled = not ok,
      mouse = { mx = self.mx, my = self.my }, fontSz = 9, eyeR = 7, t = self.t / 60 })

  -- REFUSE : éco-bouton secondaire (calque du REFUSER de slot), diamant = or accordé au refus.
  Forge.uiButton("relicpick.decline", self.decline.x, self.decline.y, self.decline.w, self.decline.h,
    T("relic.decline_label"),
    { tone = "eco", cost = RunState.DECLINE_RELIC_GOLD, hover = self.declineHover, active = self.declineDown,
      t = self.t / 60 })

  Draw.finish()
end

function Relicpick:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.hover = nil
  for i, card in ipairs(self.cards) do if ptIn(dx, dy, card) then self.hover = i; break end end
  self.bindHover = self.bind ~= nil and ptIn(dx, dy, self.bind) or false
  self.declineHover = self.decline ~= nil and ptIn(dx, dy, self.decline) or false
end

function Relicpick:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  -- REFUSE en premier (toujours actif, indépendant de la sélection) : refuser l'offre -> +or.
  if self.decline and ptIn(dx, dy, self.decline) then self.declineDown = true; self:declineOffer(); return end
  for i, card in ipairs(self.cards) do
    if ptIn(dx, dy, card) then self.sel = i; return end
  end
  if self.sel and ptIn(dx, dy, self.bind) then self.bindDown = true; self:confirm() end
end

function Relicpick:mousereleased() self.bindDown = false; self.declineDown = false end

function Relicpick:keypressed(key)
  if key == "1" or key == "2" or key == "3" then
    local i = tonumber(key)
    if self.choices[i] then self.sel = i end
  elseif (key == "return" or key == "kpenter" or key == "space") and self.sel then
    self:confirm()
  elseif key == "backspace" then -- REFUSE au clavier (Esc est happé par le quit global ; on évite ce footgun)
    self:declineOffer()
  end
end

function Relicpick:confirm()
  local id = self.choices[self.sel]
  if id and self.host.finishRelicPick then self.host.finishRelicPick(id) end
end

-- REFUSE : on renonce à la relique contre de l'or (host.finishRelicPickDecline -> declineRelic + round suivant).
-- Nommée declineOffer (et non decline) : `self.decline` est déjà le RECT du bouton -> pas de collision méthode/champ.
function Relicpick:declineOffer()
  if self.host.finishRelicPickDecline then self.host.finishRelicPickDecline() end
end

return Relicpick
