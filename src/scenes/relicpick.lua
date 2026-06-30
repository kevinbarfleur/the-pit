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
local Panel = require("src.ui.panel")
local Button = require("src.ui.button")      -- boutons propres : primary (BIND) / eco (REFUSE)
local Dividers = require("src.ui.dividers")  -- filets laiton/sang propres (cassure d'en-tête)
local Badge = require("src.ui.badge")
local Feel = require("src.ui.feel")          -- JUICE : survol (glow/lift) + press (squash/flash)
local Overlay = require("src.ui.overlay")    -- CHORÉGRAPHIE d'entrée unifiée (voile modéré qui monte + cartes back-ease)
local SFX = require("src.audio.sfx")         -- SON (Oniric grave) : BIND d'une relique = payoff (success). No-op headless.
local RelicCard = require("src.ui.relic_card") -- MOLÉCULE carte de relique (fond + icône animée + nom + effet + flavor)
local CardGlossary = require("src.ui.card_glossary")
local Relics = require("src.data.relics")    -- pour le PALIER de nature (band -> couleur de carte Argent/Or/Prismatique)
local RelicGen = require("src.gen.relicgen")
local Rarity = require("src.gen.rarity")
local MonsterCard = require("src.render.monstercard")
local Units = require("src.data.units")
local UnitResolver = require("src.core.unit_resolver")
local Mutations = require("src.run.mutations")
local MechanicsText = require("src.ui.mechanics_text")
local RunState = require("src.run.state")    -- pour DECLINE_RELIC_GOLD (or accordé au refus)
local I18n = require("src.core.i18n")
local T = I18n.t

local Relicpick = {}
Relicpick.__index = Relicpick

local C = Theme.c

-- Emblème par relique = une FAMILLE (teinte de la gemme-losange). Variété visuelle. Clés ∈ Theme.types
-- (flesh/bone/order/abyss/arcane) ; aligné sur src/scenes/build.lua (RELIC_TYPE).
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
  -- vague 5 : reliques d'économie / boutique (teinte = nature du foyer ; or=order, mort=bone, Puits=abyss)
  usurers_ledger = "order", tithe_bowl = "order", paupers_boon = "order",
  grave_robbers_cut = "bone", carrion_ledger = "bone",
  black_summons = "abyss", beggars_lantern = "order",
  -- refonte 2026-06 (relics-overhaul) : teinte = foyer mécanique (sang=empower/exécution, abysse=vuln/poison,
  -- ordre=écho/défense, chair=cleave/lifesteal). La famille de la gemme reste un INDICE visuel (le palier = liseré).
  blood_banner = "flesh", seers_mark = "abyss", carrion_feast = "bone", second_plague = "abyss",
  tide_caller = "order", bait_lantern = "flesh",
  echo_crown = "order", gravediggers_due = "bone", splitting_maw = "flesh",
}

-- ── Géométrie (espace design 1280×720). Cartes disposées par Layout.row (gouttières égales, bande centrée)
-- -> jamais de trou ni de carte mal alignée. La HAUTEUR est dérivée du contenu (RelicCard.measure). ──
local CARD_W, GAP = 300, 36
local CARD_TOP = 196               -- haut de la bande de cartes (sous l'en-tête)
local BIND_W, BIND_H = 320, 60     -- BIND THE FRAGMENT (Button primary)
local DECLINE_W, DECLINE_GAP = 168, 24 -- REFUSE (Button eco) à DROITE du BIND, même ligne
local FOOTER_BOTTOM = 696          -- la ligne de boutons s'ancre au-dessus de ce bord (safe zone)
local EVENT_REWARD_ART_H = 68

local REWARD_COLOR = {
  relic = C.gold,
  unit = C.ember,
  gold = C.brassL,
  shop_xp = Theme.type("arcane").color,
  shop_tier_up = Theme.type("abyss").color,
  mutation = C.blood,
}

local function hasKey(key) return I18n.has and I18n.has(key) end

local function tx(key, fallback, vars)
  if hasKey(key) then return T(key, vars) end
  return fallback or key
end

local function mutationText(id, field)
  local def = Mutations.byId[id]
  local key = id and ("mutation." .. tostring(id) .. "." .. field) or nil
  if key and hasKey(key) then return T(key) end
  if field == "name" then return def and def.label or tostring(id) end
  return def and def.desc or ""
end

local function wrapLines(font, str, limit)
  if not (font and font.getWrap and str and str ~= "") then return 0 end
  local _, lines = font:getWrap(str, limit)
  return math.max(1, #lines)
end

local function rewardTitle(reward)
  reward = reward or {}
  if reward.kind == "relic" then
    return reward.id and T("relic." .. reward.id .. ".name") or T("runevent.reward.kind.relic")
  elseif reward.kind == "unit" then
    local nm = reward.id and T("unit." .. reward.id .. ".name") or T("runevent.reward.kind.unit")
    return T("runevent.reward.unit", { name = nm, level = reward.level or 1 })
  elseif reward.kind == "gold" then
    return T("runevent.reward.gold", { n = reward.amount or 0 })
  elseif reward.kind == "shop_xp" then
    return T("runevent.reward.shop_xp", { n = reward.amount or 0 })
  elseif reward.kind == "shop_tier_up" then
    return T("runevent.reward.shop_tier_up", { n = reward.amount or 1 })
  elseif reward.kind == "mutation" then
    local id = reward.id or reward.mutation
    return T("runevent.reward.mutation", { name = mutationText(id, "name") })
  end
  return T("runevent.reward.unknown")
end

local function rewardDetail(reward)
  reward = reward or {}
  if reward.kind == "relic" then return reward.id and T("relic." .. reward.id .. ".effect") or "" end
  if reward.kind == "unit" then
    local u = Units[reward.id] or {}
    return T("runevent.reward.unit_detail", {
      rank = u.rank or 1,
      cost = u.cost or u.rank or 1,
    })
  end
  if reward.kind == "gold" then return T("runevent.reward.gold_detail") end
  if reward.kind == "shop_xp" then return T("runevent.reward.shop_xp_detail") end
  if reward.kind == "shop_tier_up" then return T("runevent.reward.shop_tier_up_detail") end
  if reward.kind == "mutation" then
    return mutationText(reward.id or reward.mutation, "desc")
  end
  return ""
end

local function rewardHasArt(reward)
  reward = reward or {}
  return (reward.kind == "relic" and reward.id and Relics[reward.id])
    or (reward.kind == "unit" and reward.id and Units[reward.id])
    or reward.kind == "gold"
    or reward.kind == "shop_xp"
    or reward.kind == "shop_tier_up"
    or reward.kind == "mutation"
end

local function eventChoiceOpts(choice, eventId)
  local reward = choice and choice.reward or {}
  local label = tx(choice.labelKey, choice.id and choice.id:gsub("_", " "):upper() or T("relicpick.choose"))
  local bodyKey = choice.bodyKey or (eventId and choice.id and ("runevent." .. eventId .. ".choice." .. choice.id .. ".body"))
  return {
    label = label,
    body = tx(bodyKey or "", ""),
    reward = reward,
    rewardTitle = rewardTitle(reward),
    rewardDetail = rewardDetail(reward),
    accent = REWARD_COLOR[reward.kind] or C.iron,
  }
end

local function measureEventCard(w, opts)
  local bodyW = w - 34
  local labelF = Theme.label(14)
  local rewardF = Theme.subhead(18)
  local bodyF = Theme.body(16)
  local detailF = Theme.body(14)
  local h = 26
  h = h + (labelF and labelF:getHeight() or 14) + 18
  h = h + wrapLines(bodyF, opts.body, bodyW) * (bodyF and bodyF:getHeight() or 16) + 18
  h = h + 20
  if rewardHasArt(opts.reward) then h = h + EVENT_REWARD_ART_H + 10 end
  h = h + wrapLines(rewardF, opts.rewardTitle, bodyW) * (rewardF and rewardF:getHeight() or 18) + 8
  h = h + wrapLines(detailF, opts.rewardDetail, bodyW) * (detailF and detailF:getHeight() or 14) + 24
  return math.max(300, h)
end

local function drawRewardArt(view, palette, reward, x, y, w, h, t)
  if not rewardHasArt(reward) then return 0 end
  local boxW = math.min(132, w)
  local bx = math.floor(x + (w - boxW) / 2)
  local cx, cy = bx + boxW / 2, y + h / 2
  Draw.rect(bx, y, boxW, h, C.stone900, C.iron, 1)
  if reward.kind == "relic" then
    local baked = RelicGen.cached(reward.id, palette)
    if baked and baked.image and love.graphics then
      local s = math.min((boxW - 18) / baked.w, (h - 12) / baked.h)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(baked.image,
        math.floor(bx + boxW / 2 - baked.w * s / 2),
        math.floor(y + h / 2 - baked.h * s / 2), 0, s, s)
    else
      Badge.diamond(bx + boxW / 2, y + h / 2, 9, C.gold, C.brass, C.brassS)
    end
  elseif reward.kind == "unit" then
    local rank = (Units[reward.id] and Units[reward.id].rank) or 1
    MonsterCard.drawCardPortrait(view, palette, reward.id, nil,
      { x = bx + 4, y = y + 4, w = boxW - 8, h = h - 8 },
      rank, Rarity.frame(rank), rank >= 4, t)
  elseif reward.kind == "gold" then
    Badge.diamond(cx - 18, cy, 11, C.brassL, C.brassD, C.brassS)
    Badge.diamond(cx + 2, cy - 6, 7, C.gold, C.brassD, C.brassS)
    Badge.diamond(cx + 18, cy + 7, 6, C.brass, C.brassD, nil)
    Draw.textC(T("runevent.reward.art.gold", { n = reward.amount or 0 }), cx, y + h - 24, C.gold, Theme.value(13))
  elseif reward.kind == "shop_xp" then
    local n = math.max(1, math.min(5, math.floor((reward.amount or 0) / 2 + 0.5)))
    for i = 1, 5 do
      local px = cx - 34 + (i - 1) * 17
      Draw.rect(px, cy - 10, 11, 20, i <= n and C.gold or C.stone800, i <= n and C.brassS or C.brassD, 1)
    end
    Draw.textC(T("runevent.reward.art.shop_xp"), cx, y + h - 22, C.gold, Theme.value(12))
  elseif reward.kind == "shop_tier_up" then
    Badge.rarity(cx - 46, cy - 16, 92, math.max(1, math.min(5, reward.amount or 1)), 5, 10)
    Draw.textC(T("runevent.reward.art.shop_tier"), cx, y + h - 22, Theme.type("abyss").color, Theme.value(11))
  elseif reward.kind == "mutation" then
    local col = C.blood
    Draw.setColor(col, 0.22)
    love.graphics.circle("fill", cx, cy - 2, 24)
    Draw.setColor(col, 0.80)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy - 2, 20)
    love.graphics.line(cx - 18, cy + 8, cx - 4, cy - 17, cx + 9, cy + 11, cx + 20, cy - 9)
    love.graphics.setLineWidth(1)
    Draw.textC(T("runevent.reward.art.mutation"), cx, y + h - 22, col, Theme.value(11))
  end
  return h
end

function Relicpick.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local event = payload.event
  local eventMode = event ~= nil
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    eventMode = eventMode,
    event = event,
    choices = eventMode and ((event and event.choices) or {}) or (payload.choices or {}),
    -- SOURCE de l'offre (retour user 2026-06) : level-up (fusion build, midRound) vs marchand (post-combat /3).
    source = payload.source or (eventMode and "runevent") or (payload.midRound and "levelup") or "merchant",
    sel = nil, hover = nil,
    mx = 0, my = 0, -- souris en ESPACE DESIGN (×4 du virtuel)
    bindHover = false, declineHover = false,
    ambient = Ambient.new(33),
  }, Relicpick)

  -- Données d'affichage + HAUTEUR de carte MESURÉE (overflow discipline) : on construit les opts RelicCard
  -- une fois (i18n résolu) puis on prend le MAX des hauteurs -> rangée homogène, aucun flavor sous le bord.
  self.cardOpts = {}
  local cardH = 0
  local cardW = (eventMode and #self.choices >= 4) and 268 or CARD_W
  self.cardW = cardW
  for i, choice in ipairs(self.choices) do
    local id = choice
    local opts
    if eventMode then
      opts = eventChoiceOpts(choice, event and event.id)
      cardH = math.max(cardH, measureEventCard(cardW, opts))
    else
      opts = {
        name = T("relic." .. id .. ".name"),
        effect = table.concat(MechanicsText.relicLines(id), "\n"),
        flavor = T("relic." .. id .. ".flavor"),
        fam = RELIC_TYPE[id] or "bone",
        band = Relics[id] and Relics[id].band, -- PALIER de nature -> couleur de carte (Argent/Or/Prismatique)
      }
      cardH = math.max(cardH, RelicCard.measure(cardW, opts))
    end
    self.cardOpts[i] = opts
  end
  self.cardH = math.max(cardH, 320) -- plancher : une carte n'est jamais ridiculement courte

  -- Géométrie des cartes (espace design), bande CENTRÉE via Layout.row (gouttières égales).
  local n = #self.choices
  self.cards = {}
  if n > 0 then
    local total = n * cardW + (n - 1) * GAP
    local band = { x = math.floor((Draw.W - total) / 2), y = CARD_TOP, w = total, h = self.cardH }
    local specs = {}
    for i = 1, n do specs[i] = { size = cardW } end
    local cols = Layout.row(band, specs, { gap = GAP, align = "stretch" })
    for i = 1, n do self.cards[i] = cols[i] end
  end

  -- (l'icône — le vrai objet maudit — est désormais portée/animée par RelicCard via opts.id + opts.t.)

  -- BIND (primary, centré) + REFUSE (eco, à droite) sur la même ligne, ancrés au pied (safe zone).
  local bindY = FOOTER_BOTTOM - BIND_H
  self.bind = { x = math.floor((Draw.W - BIND_W) / 2), y = bindY, w = BIND_W, h = BIND_H }
  if not eventMode then
    self.decline = { x = self.bind.x + BIND_W + DECLINE_GAP, y = bindY, w = DECLINE_W, h = BIND_H }
  end

  Feel.reset() -- repart au repos en (re)entrant (survol/press/respiration vierges)
  return self
end

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Relicpick:update(frameDt)
  self.t = self.t + frameDt
  self._anim = Overlay.advance(self._anim, frameDt / 60) -- ENTRÉE chorégraphiée (voile modéré + cartes back-ease)
  self.ambient:update(frameDt)
  Feel.update(frameDt) -- avance easings + respiration (les actions sont SYNCHRONES ici, cf. confirm/decline)
  -- cibles de survol des boutons (glow/lift montent en ease-out).
  Feel.hover("relicpick.bind", self.bindHover and self.sel ~= nil)
  if self.decline then Feel.hover("relicpick.decline", self.declineHover) end
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
function Relicpick:drawCard(i, view)
  local card = self.cards[i]
  local sel = (self.sel == i)
  local opts = self.cardOpts[i]

  if self.eventMode then
    Panel.draw(card.x, card.y, card.w, card.h, {
      fill1 = C.stone800, fill2 = C.stone900,
      accent = sel and C.gold or opts.accent,
    })
    local x, y, w = card.x + 17, card.y + 18, card.w - 34
    local labelF = Theme.label(14)
    local bodyF = Theme.body(16)
    local rewardF = Theme.subhead(18)
    local detailF = Theme.body(14)
    Draw.textTrackedC(opts.label:upper(), card.x + card.w / 2, y, sel and C.gold or C.ink, labelF, 1.5)
    y = y + (labelF and labelF:getHeight() or 14) + 18
    y = y + Draw.textWrap(opts.body, x, y, w, C.ink2, bodyF, "left") + 18
    Dividers.text(card.x + card.w / 2, y, w, T("runevent.reward_header"), 2)
    y = y + 24
    if rewardHasArt(opts.reward) then
      y = y + drawRewardArt(view, self.palette, opts.reward, x, y, w, EVENT_REWARD_ART_H, self.t / 60) + 10
    end
    Draw.textWrap(opts.rewardTitle, x, y, w, opts.accent or C.gold, rewardF, "left")
    y = y + wrapLines(rewardF, opts.rewardTitle, w) * (rewardF and rewardF:getHeight() or 18) + 8
    Draw.textWrap(opts.rewardDetail, x, y, w, C.ink2, detailF, "left")
    if not sel and self.hover == i then Draw.rect(card.x, card.y, card.w, card.h, nil, C.brass, 1) end
    return
  end

  -- état de la carte : sélectionnée = "selected" (liseré doré) ; sinon "identified". Le PALIER (band) teinte
  -- le liseré (Argent/Or/Prismatique) ET pose un label de palier -> la nature se lit d'un coup d'œil.
  -- L'ICÔNE ANIMÉE (le vrai objet maudit) est portée par la carte elle-même : on passe `id` + `t` (secondes)
  -- -> RelicCard pose l'icône en cœur (déformation per-pixel + overlays via RelicAnim). Plus de blit séparé.
  local state = sel and "selected" or "identified"
  RelicCard.draw(card.x, card.y, card.w, card.h, {
    state = state, name = opts.name, effect = opts.effect, flavor = opts.flavor, fam = opts.fam,
    band = opts.band, id = self.choices[i], t = self.t / 60,
  })

  -- AFFORDANCE de survol (carte non sélectionnée) : fin liseré laiton, pour signaler la cible cliquable
  -- sans imiter la lueur doré de la sélection (héros). RENDER pur, par-dessus le liseré iron de Panel.
  if not sel and self.hover == i then
    Draw.rect(card.x, card.y, card.w, card.h, nil, C.brass, 1)
  end
end

function Relicpick:drawOverlay(view)
  Draw.begin(view)

  -- VOILE MODÉRÉ qui MONTE (≈0,5·anim) : assombrit l'ambiance onirique (drawBack) pour détacher l'offre, mais
  -- la laisse RESPIRER dessous (pas un masque opaque comme la chronique). Cohérent avec les autres overlays.
  local anim = self._anim or 1
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 0.5 * anim })

  -- ENROBAGE du GROUPE (en-tête + 3 cartes + BIND/REFUSE) : back-ease subtil autour du centre écran -> les
  -- cartes ENTRENT au lieu de « poper ». À anim=1 -> transform identité (pose finale = rendu d'avant).
  Overlay.pushContent(Draw.W / 2, Draw.H / 2, anim)

  -- ── EN-TÊTE (voix cérémoniale, kit propre) : kicker (Spectral italique, ink-3) + titre Jacquard gravé
  -- (PRÉSERVÉ : Theme.display) + filet laiton orné dessous (Dividers.brass). Hiérarchie par CASSE/COULEUR. ──
  -- KICKER = SOURCE de l'offre (dit POURQUOI on a la relique) : level-up doré (mis en avant) vs marchand sourd.
  local lv = (self.source == "levelup")
  if self.eventMode then
    Draw.textTrackedC(T("relicpick.src_event"), Draw.W / 2, 62, C.ink3, Theme.flavor(15), 1)
    Draw.textC(T(self.event.titleKey), Draw.W / 2, 86, C.ink, Theme.display(42))
    Draw.textWrap(T(self.event.bodyKey), 280, 118, 720, C.ink2, Theme.body(16), "center")
  else
    Draw.textTrackedC(T(lv and "relicpick.src_levelup" or "relicpick.src_merchant"),
      Draw.W / 2, 70, lv and C.gold or C.ink3, Theme.flavor(15), 1)
    Draw.textC(T("relicpick.title"), Draw.W / 2, 96, C.ink, Theme.display(50))
  end
  Dividers.brass(Draw.W / 2, self.eventMode and 182 or 168, 360)

  -- ── CARTES PROPRES (RelicCard) ──
  for i = 1, #self.cards do self:drawCard(i, view) end
  do
    local gi = self.hover or self.sel
    if gi and self.cards[gi] and self.choices[gi] then
      if self.eventMode then
        local reward = self.choices[gi].reward or {}
        if reward.kind == "relic" and reward.id then
          CardGlossary.drawRelic(view, self.cards[gi], reward.id, self.t / 60,
            { force = self.forceKeywordGlossary, scroll = self.tagGlossaryScroll or 0 })
        elseif reward.kind == "unit" and reward.id then
          local level = UnitResolver.clampLevel(reward.level or 1)
          CardGlossary.drawMonster(view, self.cards[gi], reward.id, self.t / 60,
            { unit = UnitResolver.unitForLevel(reward.id, level), force = self.forceKeywordGlossary,
              scroll = self.tagGlossaryScroll or 0 })
        end
      elseif not self.eventMode then
        CardGlossary.drawRelic(view, self.cards[gi], self.choices[gi], self.t / 60,
          { force = self.forceKeywordGlossary, scroll = self.tagGlossaryScroll or 0 })
      end
    end
  end

  -- ── BIND : Button PRIMARY (l'action unique). Actif si une carte est choisie. JUICE via Feel.state. ──
  local ok = self.sel ~= nil
  Button.draw(self.bind.x, self.bind.y, self.bind.w, self.bind.h, "primary",
    ok and T(self.eventMode and "runevent.bind" or "relicpick.bind") or T("relicpick.choose"),
    { disabled = not ok, hover = self.bindHover and ok, feel = Feel.state("relicpick.bind"),
      id = "relicpick.bind", mouse = { mx = self.mx, my = self.my }, t = self.t / 60 })

  -- ── REFUSE : Button ECO (compact + coût = or accordé au refus). Toujours actif (indépendant du choix). ──
  if self.decline then
    Button.draw(self.decline.x, self.decline.y, self.decline.w, self.decline.h, "eco",
      T("relic.decline_label"),
      { cost = RunState.DECLINE_RELIC_GOLD, hover = self.declineHover, feel = Feel.state("relicpick.decline"),
        id = "relicpick.decline" })
  end

  Overlay.popContent() -- fin de l'enrobage du groupe (back-ease)
  -- FADE-UP : wash sombre par-dessus, alpha = (1-anim)·force, qui s'efface à l'entrée -> l'offre « remonte du
  -- noir » d'un bloc (appaire la chorégraphie au son du reveal). À anim=1 -> rien (rendu d'avant).
  if anim < 1 then Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, (1 - anim) * 0.5 }) end

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
  -- REFUSE en premier (toujours actif, indépendant de la sélection) : ⭐ ACTION DIFFÉRÉE (Feel) -> press
  -- visible AVANT le changement de scène (~160 ms). Le test mûrit via Relicpick:update avant d'asserter.
  if self.decline and ptIn(dx, dy, self.decline) then
    Feel.press("relicpick.decline", function() self:declineOffer() end); return
  end
  -- Clic sur une carte : sélection (le BIND confirmera). Feedback léger de press sur l'id de la carte.
  for i, card in ipairs(self.cards) do
    if ptIn(dx, dy, card) then self.sel = i; Feel.press("relicpick.card." .. i); return end
  end
  -- BIND : confirme la sélection. ⭐ DIFFÉRÉE : press visible AVANT que l'écran change (test mûrit via update).
  if self.sel and ptIn(dx, dy, self.bind) then
    Feel.press("relicpick.bind", function() self:confirm() end, { delay = Feel.CTA_DELAY })
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
  if self.eventMode then
    if self.sel and self.host.finishRunEventPick then
      SFX.play("success")
      self.host.finishRunEventPick(self.sel)
    end
    return
  end
  local id = self.choices[self.sel]
  if id and self.host.finishRelicPick then
    SFX.play("success") -- BIND : on scelle une relique (pad maj7 grave, rêveur) — payoff sémantique
    self.host.finishRelicPick(id)
  end
end

-- REFUSE : on renonce à la relique contre de l'or (host.finishRelicPickDecline -> declineRelic + round suivant).
-- Nommée declineOffer (et non decline) : `self.decline` est déjà le RECT du bouton -> pas de collision méthode/champ.
function Relicpick:declineOffer()
  if self.host.finishRelicPickDecline then self.host.finishRelicPickDecline() end
end

return Relicpick
