-- src/scenes/relicpick.lua
-- ÉCRAN RELIQUE 1-PARMI-3 — « REWARD ». Après une victoire d'acquisition (ou un level-up mid-round),
-- « quelque chose remonte du Puits » : on choisit UNE relique parmi 3 offertes. L'EFFET est AFFICHÉ
-- clairement (modèle LISIBLE, cf. docs/research/relics-design.md) ; le choix se confirme par BIND THE FRAGMENT.
--
-- ── DA = MAQUETTE §B.3 (design-system-spec-v2) sous l'ENROBAGE partagé ────────────────────────────────
-- La scène porte le CADRE de pierre gravée signature (ScreenFrame) + onglet « REWARD », comme combat/build :
-- le contenu se compose DANS l'inset (~40px de marge), le cadre borde la marge (centre transparent). À
-- l'intérieur, on aligne sur la maquette §B.3 (les VALEURS sont le point) :
--   • EN-TÊTE centré : kicker Spectral italique « the victory loosens something below » (12.5px ink-3)
--     + titre Cinzel 700 « A Fragment Surfaces » (26px ink) + filet laiton orné dessous.
--   • 3 CARTES centrées (Layout.row, gouttières égales) = la MOLÉCULE `RelicCard` (Panel + gemme de famille
--     + NOM gravé Cinzel + EFFET clair Spectral/Space Mono + flavor) avec l'ARTEFACT baké (RelicGen) en cœur.
--   • la CARTE MISE EN AVANT (le centre par défaut, sinon la sélection) reçoit le traitement « héros » du
--     mockup : LIFT (translateY -6) + halo violet (rot, `0 0 22px`) + liseré laiton. L'offre CHOISIE passe en
--     état `selected` de RelicCard (liseré doré « rayonne ») — la lueur monte sur le héros, le reste calme.
--   • FOOTER : BIND THE FRAGMENT (CTA sang, Button primary) + REFUSE +2◆ (Button eco, le +2◆ en or),
--     centrés en groupe au pied (safe zone, dans l'inset).
-- JUICE via `Feel` (survol/press/respiration) ; aucune œil/rivet gritty (la crasse viendra au shader).
--
-- ── OVERFLOW (bible §2-§3) : la hauteur des cartes vient de RelicCard.measure (wrap mesuré de l'effet ET
-- du flavor) -> on prend le MAX des 3 -> rangée HOMOGÈNE où aucun texte ne passe sous le bord. Cartes
-- disposées par Layout.row (gouttières égales). Tokens d'espacement Theme.sp (jamais de littéral au pif).
--
-- ── CONTRAT (inchangé) : interface scène (new/update/drawBack/drawWorld/drawOverlay/keypressed/mouse*) +
-- la LOGIQUE DE SÉLECTION (self.cards = 3 rects, self.hover, self.sel, self.bind, self.bindHover,
-- self.declineHover) + la passe au host : host fournit payload.choices (ids seedés par RunState:rollRelicChoices)
-- et reçoit le pick via host.finishRelicPick(id) ; le refus via host.finishRelicPickDecline().
-- TIMING : le test e2e clique BIND/REFUSE et asserte le pick IMMÉDIATEMENT (sans Feel.update entre) ->
-- on joue le feedback (Feel.press) ET on appelle l'action SYNCHRONE (comme build.lua:startCombat).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Layout = require("src.ui.layout")
local Ambient = require("src.fx.ambient")
local Button = require("src.ui.button")      -- boutons propres : primary (BIND) / eco (REFUSE)
local Dividers = require("src.ui.dividers")  -- filets laiton/sang propres (cassure d'en-tête)
local Feel = require("src.ui.feel")          -- JUICE : survol (glow/lift) + press (squash/flash)
local RelicCard = require("src.ui.relic_card") -- MOLÉCULE carte de relique (fond + gemme + nom + effet + flavor)
local RelicGen = require("src.gen.relicgen") -- icones bakees des reliques (le vrai artefact, posé en coeur)
local RunState = require("src.run.state")    -- pour DECLINE_RELIC_GOLD (or accordé au refus)
local ScreenFrame = require("src.ui.screenframe") -- ENROBAGE partagé : cadre de pierre gravée + onglet « REWARD »
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

-- ── Géométrie (espace design 1280×720). Tout se compose DANS l'inset du cadre (~40px de marge). Cartes
-- disposées par Layout.row (gouttières égales, bande centrée) -> jamais de trou ni de carte mal alignée.
-- La HAUTEUR est dérivée du contenu (RelicCard.measure). ──
local CARD_W, GAP = 300, 36
local LIFT = 6                     -- translateY de la carte mise en avant (mockup §B.3 : translateY(-6px))
local BIND_W, BIND_H = 320, 60     -- BIND THE FRAGMENT (Button primary)
local DECLINE_W, DECLINE_GAP = 168, 20 -- REFUSE (Button eco) à DROITE du BIND ; gap groupe = 20 (mockup)

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

  -- AIRE DE CONTENU = inset du cadre reliquaire (le contenu doit TENIR dedans ; le cadre borde la marge).
  local ix, iy, iw, ih = ScreenFrame.inset({ ft = ScreenFrame.FT })
  self.inset = { x = ix, y = iy, w = iw, h = ih }

  -- ── EN-TÊTE (maquette §B.3) : kicker + titre + filet, centrés en haut de l'inset. Ancres verticales
  -- dérivées (kicker -> titre -> filet) pour rester sous l'onglet et au-dessus de la bande de cartes. ──
  self.kickerY = iy + 18                 -- voix cérémoniale (Spectral italique)
  self.titleY = self.kickerY + 22        -- « A Fragment Surfaces » (Cinzel 700 26)
  self.dividerY = self.titleY + 40       -- filet laiton orné sous le titre

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

  -- Bande de cartes CENTRÉE sous l'en-tête, dans l'inset. On réserve LIFT px en haut (la carte héros remonte)
  -- et la place du footer en bas, puis on centre verticalement la bande dans l'espace restant.
  local cardTop = self.dividerY + 24 + LIFT
  -- BIND + REFUSE : groupe centré, ancré au pied de l'inset (safe zone). On le pose AVANT pour border la bande.
  local groupW = BIND_W + DECLINE_GAP + DECLINE_W
  local groupX = math.floor((Draw.W - groupW) / 2)
  local footerY = iy + ih - BIND_H - 16          -- 16px d'air au-dessus du bord bas de l'inset
  self.bind = { x = groupX, y = footerY, w = BIND_W, h = BIND_H }
  self.decline = { x = groupX + BIND_W + DECLINE_GAP, y = footerY, w = DECLINE_W, h = BIND_H }

  -- centrage vertical de la bande entre l'en-tête et le footer (si la place le permet, sinon collé en haut).
  local avail = footerY - 24 - cardTop
  if avail > self.cardH then cardTop = math.floor(cardTop + (avail - self.cardH) / 2) end

  -- Géométrie des cartes (espace design), bande CENTRÉE via Layout.row (gouttières égales).
  local n = #self.choices
  self.cards = {}
  if n > 0 then
    local total = n * CARD_W + (n - 1) * GAP
    local band = { x = math.floor((Draw.W - total) / 2), y = cardTop, w = total, h = self.cardH }
    local specs = {}
    for i = 1, n do specs[i] = { size = CARD_W } end
    local cols = Layout.row(band, specs, { gap = GAP, align = "stretch" })
    for i = 1, n do self.cards[i] = cols[i] end
  end

  -- CARTE MISE EN AVANT par défaut = le CENTRE (mockup : carte centrale highlightée). La sélection déplace
  -- l'emphase, mais à l'ouverture c'est le milieu qui « rayonne ».
  self.featured = (n > 0) and math.floor((n + 1) / 2) or nil

  -- Artefacts bakés (le vrai objet maudit) par choix — posés en coeur de carte (dans la gemme).
  self.icons = {}
  for i = 1, n do self.icons[i] = RelicGen.cached(self.choices[i], palette) end

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

-- Halo violet (rot) derrière la carte mise en avant — l'équivalent du `box-shadow: 0 0 22px rgba(168,111,196,.2)`
-- du mockup §B.3. Bandes additives décroissantes autour du rect (RENDER pur, no-op headless sous le mock).
local function featuredGlow(x, y, w, h)
  local g = love and love.graphics
  if not (g and g.setBlendMode) then return end
  g.setBlendMode("add")
  for i = 1, 6 do
    local pad = i * 3
    local a = 0.10 * (1 - (i - 1) / 6)
    g.setColor(C.rot[1], C.rot[2], C.rot[3], a)
    g.rectangle("line", x - pad, y - pad, w + 2 * pad, h + 2 * pad)
  end
  g.setBlendMode("alpha")
  g.setColor(1, 1, 1, 1)
end

-- Une carte de relique PROPRE : la MOLÉCULE RelicCard (fond Panel + gemme de famille + nom + effet + flavor)
-- en état "identified" (ou "selected" = liseré doré d'accent pour l'offre choisie), avec l'ARTEFACT baké
-- posé en COEUR (dans la gemme = son écrin). La carte MISE EN AVANT (centre, ou sélection) remonte de LIFT px,
-- baigne dans un halo violet (rot) et reçoit un liseré laiton — le traitement « héros » du mockup §B.3.
-- Survol (sans sélection) = léger liseré laiton (affordance).
function Relicpick:drawCard(i)
  local card = self.cards[i]
  local sel = (self.sel == i)
  local featured = (i == self.featured) or sel
  local opts = self.cardOpts[i]

  -- la carte héros remonte de LIFT px (mockup : translateY(-6px)) ; les autres restent à leur ancre.
  local cy = featured and (card.y - LIFT) or card.y

  -- halo violet derrière la carte mise en avant (avant le fond -> le glow déborde le panneau).
  if featured then featuredGlow(card.x, cy, card.w, card.h) end

  -- état de la carte : sélectionnée = "selected" (liseré doré qui rayonne) ; sinon "identified".
  local state = sel and "selected" or "identified"
  RelicCard.draw(card.x, cy, card.w, card.h, {
    state = state, name = opts.name, effect = opts.effect, flavor = opts.flavor, fam = opts.fam,
  })

  -- liseré LAITON sur la carte MISE EN AVANT non-sélectionnée (`1px --brass` du mockup) — distingue le héros
  -- du repos sans imiter la lueur DORÉE de la sélection. RENDER pur, par-dessus le liseré iron de Panel.
  if featured and not sel then
    Draw.rect(card.x, cy, card.w, card.h, nil, C.brass, 1)
  end

  -- AFFORDANCE de survol (carte non mise en avant, non sélectionnée) : fin liseré laiton -> cible cliquable.
  if not featured and self.hover == i then
    Draw.rect(card.x, cy, card.w, card.h, nil, C.brass, 1)
  end

  -- ARTEFACT baké (le vrai objet) posé en COEUR de carte, centré sur la GEMME de RelicCard. On RECALCULE la
  -- géométrie de la gemme à l'identique de relic_card.lua (gr ~= w*0.14, gemCy = PAD_TOP(12) + gr) -> l'icône
  -- s'assoit DANS son écrin. Scale entier (net). Sous le mock, baked.image est absent -> no-op (golden neutre).
  local baked = self.icons[i]
  if baked and baked.image then
    local gr = math.max(8, math.floor(card.w * 0.14 + 0.5))
    local gemCx = card.x + card.w / 2
    local gemCy = cy + 12 + gr -- PAD_TOP de RelicCard = 12
    local iw, ih = baked.w * ICON_SCALE, baked.h * ICON_SCALE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(baked.image, math.floor(gemCx - iw / 2), math.floor(gemCy - ih / 2), 0, ICON_SCALE, ICON_SCALE)
    Draw.reset()
  end
end

function Relicpick:drawOverlay(view)
  Draw.begin(view)

  -- ── EN-TÊTE (voix cérémoniale, maquette §B.3) : kicker Spectral italique (ink-3) + titre Cinzel 700 gravé
  -- « A Fragment Surfaces » (26px ink) + filet laiton orné dessous. Hiérarchie par CASSE/COULEUR. ──
  Draw.textC(T("relicpick.kicker"), Draw.W / 2, self.kickerY, C.ink3, Theme.flavor(13))
  Draw.textTrackedC(T("relicpick.title"), Draw.W / 2, self.titleY, C.ink, Theme.heading(26), 1.3)
  Dividers.brass(Draw.W / 2, self.dividerY, 320)

  -- ── CARTES PROPRES (RelicCard) : la carte mise en avant rendue EN DERNIER (par-dessus ses voisines) pour
  -- que son halo/lift ne soit pas masqué par la carte suivante. ──
  local feat = nil
  for i = 1, #self.cards do
    if (i == self.featured) or (self.sel == i) then feat = i else self:drawCard(i) end
  end
  if feat then self:drawCard(feat) end

  -- ── BIND : Button PRIMARY (l'action unique). Actif si une carte est choisie. JUICE via Feel.state. ──
  local ok = self.sel ~= nil
  Button.draw(self.bind.x, self.bind.y, self.bind.w, self.bind.h, "primary",
    ok and T("relicpick.bind") or T("relicpick.choose"),
    { disabled = not ok, hover = self.bindHover and ok, feel = Feel.state("relicpick.bind"),
      id = "relicpick.bind", mouse = { mx = self.mx, my = self.my }, t = self.t / 60 })

  -- ── REFUSE : Button ECO (compact + coût = or accordé au refus, « +2◆ » en or). Toujours actif. ──
  Button.draw(self.decline.x, self.decline.y, self.decline.w, self.decline.h, "eco",
    T("relic.decline_label"),
    { cost = RunState.DECLINE_RELIC_GOLD, hover = self.declineHover, feel = Feel.state("relicpick.decline"),
      id = "relicpick.decline" })

  -- ── ENROBAGE signature : cadre reliquaire partagé (bande de pierre gravée + onglet « REWARD ») posé EN
  -- DERNIER, par-dessus le contenu. Le centre du cadre est transparent : le contenu tient DANS l'inset
  -- (~40px de marge) ; le cadre borde la marge (comme combat/build/runover). ──
  ScreenFrame.draw("REWARD", { ft = ScreenFrame.FT })

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
