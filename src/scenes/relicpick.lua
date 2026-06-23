-- src/scenes/relicpick.lua
-- ÉCRAN RELIQUE 1-PARMI-3. Après une victoire d'acquisition (ou un level-up mid-round), « quelque chose
-- remonte du Puits » : on choisit UNE relique parmi 3 offertes. L'EFFET est AFFICHÉ clairement (modèle
-- LISIBLE, cf. docs/research/relics-design.md) ; le choix est confirmé par BIND THE FRAGMENT.
--
-- ── DA = KIT UI PROPRE (.dc.html / design-system) ────────────────────────────────────────────────────
-- La scène n'utilise PLUS Forge/Frame (kit legacy gritty). Chaque offre = la MOLÉCULE `RelicCard`
-- (src/ui/relic_card.lua) en état "identified" (offre = sélectionnée -> liseré doré d'accent) : Panel
-- propre (dégradé + liseré iron) + gemme-losange de famille + NOM gravé (Cinzel) + EFFET clair (Spectral,
-- valeurs en Space Mono) + flavor (Spectral italique). L'ARTEFACT baké (RelicGen.cached) est posé en
-- COEUR de carte (dans la gemme = son écrin) -> l'objet maudit reste le point focal du reveal.
-- Le BIND est un `Button` PRIMARY (l'action unique, sang) ; le REFUSE un `Button` ECO (coût = or accordé).
-- JUICE via `Feel` (survol/press/respiration) ; aucune œil/rivet gritty (la crasse viendra au shader).
--
-- ── OVERFLOW (bible §2-§3) : la hauteur des cartes vient de RelicCard.measure (wrap mesuré de l'effet ET
-- du flavor) -> on prend le MAX des 3 -> rangée HOMOGÈNE où aucun texte ne passe sous le bord. Cartes
-- disposées par Layout.row (gouttières égales). Tokens d'espacement Theme.sp (jamais de littéral au pif).
--
-- ── CONTRAT (inchangé) : interface scène (new/update/drawBack/drawWorld/drawOverlay/keypressed/mouse*) +
-- la LOGIQUE DE SÉLECTION (self.cards = 3 rects, self.hover, self.sel, self.bind, self.bindHover) +
-- la passe au host : host fournit payload.choices (ids seedés par RunState:rollRelicChoices) et reçoit le
-- pick via host.finishRelicPick(id) ; le refus via host.finishRelicPickDecline().
-- TIMING : le test e2e clique BIND/REFUSE et asserte le pick IMMÉDIATEMENT (sans Feel.update entre) ->
-- on joue le feedback (Feel.press) ET on appelle l'action SYNCHRONE (comme build.lua:startCombat).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Layout = require("src.ui.layout")
local Ambient = require("src.fx.ambient")
local Panel = require("src.ui.panel")        -- surface propre (dégradé + liseré iron) : socle d'en-tête
local Button = require("src.ui.button")      -- boutons propres : primary (BIND) / eco (REFUSE)
local Dividers = require("src.ui.dividers")  -- filets laiton/sang propres (cassure d'en-tête)
local Feel = require("src.ui.feel")          -- JUICE : survol (glow/lift) + press (squash/flash)
local RelicCard = require("src.ui.relic_card") -- MOLÉCULE carte de relique (fond + gemme + nom + effet + flavor)
local RelicGen = require("src.gen.relicgen") -- icones bakees des reliques (le vrai artefact, posé en coeur)
local RunState = require("src.run.state")    -- pour DECLINE_RELIC_GOLD (or accordé au refus)
local T = require("src.core.i18n").t

local Relicpick = {}
Relicpick.__index = Relicpick

local C = Theme.c

-- Emblème par relique = une FAMILLE (teinte de la gemme-losange). Variété visuelle. Clés ∈ Theme.types
-- (flesh/bone/order/abyss/arcane) ; aligné sur src/scenes/build.lua (RELIC_TYPE).
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
}

-- ── Géométrie (espace design 1280×720). Cartes disposées par Layout.row (gouttières égales, bande centrée)
-- -> jamais de trou ni de carte mal alignée. La HAUTEUR est dérivée du contenu (RelicCard.measure). ──
local CARD_W, GAP = 300, 36
local CARD_TOP = 196               -- haut de la bande de cartes (sous l'en-tête)
local BIND_W, BIND_H = 320, 60     -- BIND THE FRAGMENT (Button primary)
local DECLINE_W, DECLINE_GAP = 168, 24 -- REFUSE (Button eco) à DROITE du BIND, même ligne
local FOOTER_BOTTOM = 696          -- la ligne de boutons s'ancre au-dessus de ce bord (safe zone)

-- L'artefact baké (16×16) posé en COEUR de carte, DANS la gemme (= son écrin). Scale entier (net). La gemme
-- de RelicCard a un rayon ~w*0.14 ; on dimensionne l'icône pour s'asseoir dedans sans déborder le losange.
local ICON_SCALE = 3 -- 16×16 -> 48×48 design (tient dans une gemme de demi-diagonale ~42px)

function Relicpick.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    choices = payload.choices or {},
    sel = nil, hover = nil,
    mx = 0, my = 0, -- souris en ESPACE DESIGN (×4 du virtuel)
    bindHover = false, declineHover = false,
    ambient = Ambient.new(33),
  }, Relicpick)

  -- Données d'affichage + HAUTEUR de carte MESURÉE (overflow discipline) : on construit les opts RelicCard
  -- une fois (i18n résolu) puis on prend le MAX des hauteurs -> rangée homogène, aucun flavor sous le bord.
  self.cardOpts = {}
  local cardH = 0
  for i, id in ipairs(self.choices) do
    local opts = {
      name = T("relic." .. id .. ".name"),
      effect = T("relic." .. id .. ".effect"),
      flavor = T("relic." .. id .. ".flavor"),
      fam = RELIC_TYPE[id] or "bone",
    }
    self.cardOpts[i] = opts
    cardH = math.max(cardH, RelicCard.measure(CARD_W, opts))
  end
  self.cardH = math.max(cardH, 320) -- plancher : une carte n'est jamais ridiculement courte

  -- Géométrie des cartes (espace design), bande CENTRÉE via Layout.row (gouttières égales).
  local n = #self.choices
  self.cards = {}
  if n > 0 then
    local total = n * CARD_W + (n - 1) * GAP
    local band = { x = math.floor((Draw.W - total) / 2), y = CARD_TOP, w = total, h = self.cardH }
    local specs = {}
    for i = 1, n do specs[i] = { size = CARD_W } end
    local cols = Layout.row(band, specs, { gap = GAP, align = "stretch" })
    for i = 1, n do self.cards[i] = cols[i] end
  end

  -- Artefacts bakés (le vrai objet maudit) par choix — posés en coeur de carte (dans la gemme).
  self.icons = {}
  for i = 1, n do self.icons[i] = RelicGen.cached(self.choices[i], palette) end

  -- BIND (primary, centré) + REFUSE (eco, à droite) sur la même ligne, ancrés au pied (safe zone).
  local bindY = FOOTER_BOTTOM - BIND_H
  self.bind = { x = math.floor((Draw.W - BIND_W) / 2), y = bindY, w = BIND_W, h = BIND_H }
  self.decline = { x = self.bind.x + BIND_W + DECLINE_GAP, y = bindY, w = DECLINE_W, h = BIND_H }

  Feel.reset() -- repart au repos en (re)entrant (survol/press/respiration vierges)
  return self
end

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Relicpick:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  Feel.update(frameDt) -- avance easings + respiration (les actions sont SYNCHRONES ici, cf. confirm/decline)
  -- cibles de survol des boutons (glow/lift montent en ease-out).
  Feel.hover("relicpick.bind", self.bindHover and self.sel ~= nil)
  Feel.hover("relicpick.decline", self.declineHover)
end

function Relicpick:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("relic")
  Draw.finish()
end

function Relicpick:drawWorld() end

-- Une carte de relique PROPRE : la MOLÉCULE RelicCard (fond Panel + gemme de famille + nom + effet + flavor)
-- en état "identified" (ou "selected" = liseré doré d'accent pour l'offre choisie), avec l'ARTEFACT baké
-- posé en COEUR (dans la gemme = son écrin). Survol (sans sélection) = léger liseré laiton (affordance).
function Relicpick:drawCard(i)
  local card = self.cards[i]
  local sel = (self.sel == i)
  local opts = self.cardOpts[i]

  -- état de la carte : sélectionnée = "selected" (liseré doré) ; sinon "identified".
  local state = sel and "selected" or "identified"
  RelicCard.draw(card.x, card.y, card.w, card.h, {
    state = state, name = opts.name, effect = opts.effect, flavor = opts.flavor, fam = opts.fam,
  })

  -- AFFORDANCE de survol (carte non sélectionnée) : fin liseré laiton, pour signaler la cible cliquable
  -- sans imiter la lueur doré de la sélection (héros). RENDER pur, par-dessus le liseré iron de Panel.
  if not sel and self.hover == i then
    Draw.rect(card.x, card.y, card.w, card.h, nil, C.brass, 1)
  end

  -- ARTEFACT baké (le vrai objet) posé en COEUR de carte, centré sur la GEMME de RelicCard. On RECALCULE la
  -- géométrie de la gemme à l'identique de relic_card.lua (gr ~= w*0.14, gemCy = PAD_TOP(12) + gr) -> l'icône
  -- s'assoit DANS son écrin. Scale entier (net). Sous le mock, baked.image est absent -> no-op (golden neutre).
  local baked = self.icons[i]
  if baked and baked.image then
    local gr = math.max(8, math.floor(card.w * 0.14 + 0.5))
    local gemCx = card.x + card.w / 2
    local gemCy = card.y + 12 + gr -- PAD_TOP de RelicCard = 12
    local iw, ih = baked.w * ICON_SCALE, baked.h * ICON_SCALE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(baked.image, math.floor(gemCx - iw / 2), math.floor(gemCy - ih / 2), 0, ICON_SCALE, ICON_SCALE)
    Draw.reset()
  end
end

function Relicpick:drawOverlay(view)
  Draw.begin(view)

  -- ── EN-TÊTE (voix cérémoniale, kit propre) : kicker (Spectral italique, ink-3) + titre Jacquard gravé
  -- (PRÉSERVÉ : Theme.display) + filet laiton orné dessous (Dividers.brass). Hiérarchie par CASSE/COULEUR. ──
  Draw.textTrackedC(T("relicpick.kicker"), Draw.W / 2, 70, C.ink3, Theme.flavor(15), 1)
  Draw.textC(T("relicpick.title"), Draw.W / 2, 96, C.ink, Theme.display(50))
  Dividers.brass(Draw.W / 2, 168, 360)

  -- ── CARTES PROPRES (RelicCard) ──
  for i = 1, #self.cards do self:drawCard(i) end

  -- ── BIND : Button PRIMARY (l'action unique). Actif si une carte est choisie. JUICE via Feel.state. ──
  local ok = self.sel ~= nil
  Button.draw(self.bind.x, self.bind.y, self.bind.w, self.bind.h, "primary",
    ok and T("relicpick.bind") or T("relicpick.choose"),
    { disabled = not ok, hover = self.bindHover and ok, feel = Feel.state("relicpick.bind"),
      id = "relicpick.bind", mouse = { mx = self.mx, my = self.my }, t = self.t / 60 })

  -- ── REFUSE : Button ECO (compact + coût = or accordé au refus). Toujours actif (indépendant du choix). ──
  Button.draw(self.decline.x, self.decline.y, self.decline.w, self.decline.h, "eco",
    T("relic.decline_label"),
    { cost = RunState.DECLINE_RELIC_GOLD, hover = self.declineHover, feel = Feel.state("relicpick.decline"),
      id = "relicpick.decline" })

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
  -- REFUSE en premier (toujours actif, indépendant de la sélection) : feedback de press IMMÉDIAT (Feel.press
  -- sans action différée) + action SYNCHRONE (le test asserte le routage juste après le clic -> pas de différé).
  if self.decline and ptIn(dx, dy, self.decline) then
    Feel.press("relicpick.decline"); self:declineOffer(); return
  end
  -- Clic sur une carte : sélection (le BIND confirmera). Feedback léger de press sur l'id de la carte.
  for i, card in ipairs(self.cards) do
    if ptIn(dx, dy, card) then self.sel = i; Feel.press("relicpick.card." .. i); return end
  end
  -- BIND : confirme la sélection. Feedback de press IMMÉDIAT + confirm SYNCHRONE (test-safe).
  if self.sel and ptIn(dx, dy, self.bind) then
    Feel.press("relicpick.bind"); self:confirm()
  end
end

function Relicpick:mousereleased() end

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
