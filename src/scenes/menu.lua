-- src/scenes/menu.lua
-- ÉCRAN TITRE "The Pit" — reconstruit au design PROPRE du designer (design-system §3.1). « YOU DESCEND /
-- The Pit » sur fond d'atmosphère (gueule du puits + braises), filet laiton/sang, puis les ENTRÉES de menu
-- empilées, et un pied rappelant la méta-progression (reliques inscrites au Grimoire). On entre dans le Puits ici.
--
-- DA « reliquary » (kit src/ui/draw.lua + theme) : pas de boutons-cadres ni d'œil/gritty — les entrées sont du
-- TEXTE gravé dont la HIÉRARCHIE passe par la CASSE/le POIDS Cinzel (pas par la taille seule) :
--   • ENTER THE PIT = HÉROS : Cinzel 700 ~19px, préfixe losange SANG, lueur sang douce ; survol -> ink vif + lueur.
--   • Secondaires (GRIMOIRE/PROVING/DESIGN SYSTEM…) = Cinzel 500 ~15px ink-2 ; survol -> ink + soulignement sang.
--   • Désactivées (RITES, ABANDON inerte si scellé) = Cinzel 500 ink-4 (jamais hoverables).
-- Le titre gothique « The Pit » (Jacquard) est PRÉSERVÉ. Couleurs/polices via Theme UNIQUEMENT, texte NET (Draw).
--
-- CLIQUABILITÉ (le cœur) : chaque entrée porte un RECT de hit-test (espace design) calculé dans :layout()
-- (mesure de la largeur du texte + préfixe losange pour ENTER) -> dispo dès new() (avant la 1re frame). La souris
-- arrive en VIRTUEL (320×180, main.lua a divisé par view.scale) -> on la repasse en DESIGN (×4) pour le hit-test,
-- comme tout le reste de l'UI. mousemoved pose un hover par entrée ; mousepressed arme ; mousereleased agit.
--
-- Couche RENDER/scène (love.graphics autorisé) : atmosphère en pre-pass natif (drawBack), entrées/texte en
-- overlay natif. Composé en ESPACE DESIGN 1280x720 (= virtuel ×4). RENDER pur, headless-safe.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Feel = require("src.ui.feel") -- JUICE (bible §4) : survol/press/respiration + ACTION DIFFÉRÉE
local Forge = require("src.ui.forge") -- YEUX cauchemardesques du CTA (overlay seedé, hors-texte) — RENDER pur
local Nightmare = require("src.ui.nightmare") -- surcouche ONIRIQUE (bordures qui tanguent) : avance le dt mural
local Ambient = require("src.fx.ambient")
local Grimoire = require("src.core.grimoire")
local Relics = require("src.data.relics")
local Dev = require("src.core.dev") -- MODE DEV : toggle full-unlock (visible/inerte selon Dev.ENABLED)
local T = require("src.core.i18n").t

local Menu = {}
Menu.__index = Menu

local CX = Draw.W / 2

-- ── Métriques de la pile d'entrées (espace design). La hiérarchie est portée par la CASSE/le POIDS Cinzel
-- (pas la taille seule) : ENTER (héros) un peu plus grand + un sang en préfixe ; secondaires plus discrètes ;
-- désactivées plus petites. La pile est CENTRÉE dans la bande sous le diviseur (BAND_TOP..BAND_BOTTOM) ->
-- tient quel que soit le nombre d'entrées (dev = +1). On RABOTE le pas si la pile déborde la bande.
local CTA_PX  = 19   -- ENTER THE PIT (Cinzel 700)
local SEC_PX  = 15   -- entrées secondaires (Cinzel 500)
local OFF_PX  = 13   -- entrées désactivées (ABANDON-like, Cinzel 500)
local CTA_TRACK, SEC_TRACK = 1.9, 1.8 -- interlettrage (px design) ≈ 0.1em / 0.12em
local CTA_STEP = 44  -- pas vertical du CTA (sa propre ligne, plus aérée)
local SEC_STEP = 32  -- pas vertical des secondaires
local DIAMOND_R = 4  -- losange sang en préfixe de ENTER
local DIAMOND_GAP = 12 -- espace losange -> texte de ENTER
local HIT_PADX, HIT_PADY = 14, 8 -- marge de confort autour du texte pour le hit-test (clic plus généreux)
local BAND_TOP, BAND_BOTTOM = 452, 660 -- bande des entrées : sous le diviseur (~444), au-dessus du pied (~690)

function Menu.new(palette, vw, vh, host)
  local self = setmetatable({}, Menu)
  self.palette = palette
  self.vw, self.vh = vw, vh
  self.host = host
  self.daChrome = true          -- dessine sa propre chrome -> pas de HUD générique
  self.titleKey = "ui.title"
  self.hintKey = "ui.empty"
  self.t = 0
  self.mx, self.my = 0, 0        -- souris en ESPACE DESIGN
  self.ambient = Ambient.new(7)  -- seed fixe -> atmosphère stable

  -- Entrées : ENTER (CTA héros) + GRIMOIRE/PROVING/DESIGN SYSTEM (secondaires) + RITES (scellée) + ABANDON.
  -- kind = "cta" | "sec" | "off" : pilote la voix (police/poids), la lueur héros et le préfixe losange.
  self.items = {
    { id = "enter",        key = "menu.enter",        kind = "cta", enabled = true,  action = function() self.host.newRun() end },
    { id = "grimoire",     key = "menu.grimoire",     kind = "sec", enabled = true,  action = function() self.host.goto("grimoire") end },
    { id = "proving",      key = "menu.proving",      kind = "sec", enabled = true,  action = function() self.host.goto("playground") end },
    { id = "designsystem", key = "menu.designsystem", kind = "sec", enabled = true,  action = function() self.host.goto("designsystem") end },
    { id = "rites",        key = "menu.rites",        kind = "sec", enabled = false },
    { id = "abandon",      key = "menu.abandon",      kind = "off", enabled = true,  action = function() love.event.quit() end },
  }
  self:layout()
  self.hover = nil
  self.down = false
  Feel.reset() -- repart au repos en (re)entrant dans le menu (survol/press/respiration vierges)
  -- Toggle MODE DEV (cheat) — coin haut-gauche, présent UNIQUEMENT si Dev.ENABLED (masqué/inerte en release).
  self.devRect = Dev.ENABLED and { x = 16, y = 14, w = 252, h = 26 } or nil
  return self
end

-- Police/poids d'une entrée selon son kind (la voix qui porte la hiérarchie). px raboté = override de taille.
local function fontFor(kind, px)
  if kind == "cta" then return Theme.heading(px or CTA_PX) end -- Cinzel 700
  return Theme.subhead(px or (kind == "off" and OFF_PX or SEC_PX)) -- Cinzel 600/500 (secondaire/désactivée)
end

-- Calcule le RECT de hit-test (espace design) de chaque entrée : pile CENTRÉE verticalement dans la bande,
-- chaque ligne CENTRÉE horizontalement sur CX. La largeur du rect = largeur du TEXTE (+ préfixe losange pour
-- ENTER) + une marge de confort. Disponible dès new() -> le hit-test marche avant la 1re frame (testé).
function Menu:layout()
  local n = #self.items
  -- Pas vertical par entrée (CTA plus aéré). On RABOTE si la pile déborde la bande (cas DEV = +1 entrée).
  local ctaStep, secStep = CTA_STEP, SEC_STEP
  local function pileH()
    local h = 0
    for _, it in ipairs(self.items) do h = h + (it.kind == "cta" and ctaStep or secStep) end
    return h
  end
  local bandH = BAND_BOTTOM - BAND_TOP
  local guard = 0
  while pileH() > bandH and guard < 200 do
    guard = guard + 1
    if secStep > 24 then secStep = secStep - 1
    elseif ctaStep > 34 then ctaStep = ctaStep - 1
    else break end
  end
  local total = pileH()
  local y = math.floor(BAND_TOP + math.max(0, (bandH - total) / 2))

  for _, it in ipairs(self.items) do
    local step = (it.kind == "cta") and ctaStep or secStep
    local f = fontFor(it.kind)
    local track = (it.kind == "cta") and CTA_TRACK or SEC_TRACK
    -- Largeur du texte avec interlettrage (somme des avances + (#-1) tracking). Mesure UTF-8-safe via Draw.
    local label = T(it.key)
    local tw = Draw.textWidth(label, f)
    local nch = math.max(1, #label)        -- approx du nombre de gaps (suffit pour le hit-test confortable)
    tw = tw + (nch - 1) * track
    local prefixW = (it.kind == "cta") and (DIAMOND_R * 2 + DIAMOND_GAP) or 0
    local fullW = tw + prefixW
    local fh = (f and f.getHeight and f:getHeight()) or step
    local cy = y + step / 2                  -- centre vertical de la ligne
    -- Hauteur du hit-test : texte + marge, MAIS bornée au pas (-1px de hairline) -> les rects PAVENT la pile
    -- sans JAMAIS se chevaucher (gouttières >= 0), même quand le pas est raboté (cas DEV). Clic généreux.
    local hitH = math.min(fh + HIT_PADY * 2, step - 1)
    it.rect = {
      x = math.floor(CX - fullW / 2 - HIT_PADX),
      y = math.floor(cy - hitH / 2),
      w = math.floor(fullW + HIT_PADX * 2),
      h = math.floor(hitH),
    }
    it._cy = cy
    it._textW = tw
    it._prefixW = prefixW
    y = y + step
  end
end

-- Indice de l'entrée sous (dx,dy) en coords DESIGN, ou nil (entrées scellées ignorées).
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
  Feel.update(dt) -- avance survol/press/respiration ET fire les actions différées mûres (ENTER, GRIMOIRE…)
  Nightmare.update(dt) -- avance le tangage onirique (utilisé si une box est dessinée ; horloge partagée)
end

-- id de feel stable d'une entrée (cache par id dans Feel) : "menu.enter", "menu.grimoire", …
local function feelId(it) return "menu." .. it.id end

-- Pre-pass : atmosphère native derrière (le menu n'a pas de monde pixel).
function Menu:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("menu")
  Draw.finish()
end

function Menu:drawWorld() end -- aucun monde pixel (canvas laissé transparent)

-- Titre gothique avec halo sang (faux bloom : passes décalées en dim puis le titre net). Préservé de l'original.
local function drawTitleGlow(str, cx, y, font)
  local c = Theme.c
  local off = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 2, 2 }, { -2, -2 } }
  for _, o in ipairs(off) do Draw.textC(str, cx + o[1], y + o[2], { c.blood[1], c.blood[2], c.blood[3], 0.16 }, font) end
  Draw.textC(str, cx, y, c.title, font)
end

-- Losange (rotation 45°) plein, en coords design. cx,cy = centre, r = demi-diagonale.
local function diamond(cx, cy, r, color, alpha)
  if not (love and love.graphics) then return end
  Draw.setColor(color, alpha)
  love.graphics.polygon("fill", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
  Draw.reset()
end

-- Dessine une entrée de menu (texte gravé + état). Tout est centré sur CX à partir du rect calculé.
-- JUICE (bible §4, RENDER pur) : l'état Feel pilote la LUEUR (enfle au survol), un PRESS-SINK de 1–2px au
-- clic + un FLASH bref de braise, et une RESPIRATION permanente (float vertical) réservée au CTA héros. La
-- pierre gravée « s'illumine » au survol et « s'enfonce » au clic — métaphore d'interaction unique de l'UI.
function Menu:drawItem(it, hovered)
  local c = Theme.c
  local fs = Feel.state(feelId(it)) -- { glow, lift, squash, flash } (neutre si inconnu)
  local g = fs.glow or 0            -- 0..1 : intensité de survol lissée (ease-out)
  local sink = math.floor((fs.squash or 0) + 0.5) -- enfoncement au press (px, entier = net)
  local floatY = (it.kind == "cta") and Feel.floatY(feelId(it), 1.1) or 0 -- respiration douce du héros
  local cy = it._cy + floatY + sink
  local f = fontFor(it.kind)
  local track = (it.kind == "cta") and CTA_TRACK or SEC_TRACK
  local label = T(it.key)
  local fh = (f and f.getHeight and f:getHeight()) or 16
  local ty = math.floor(cy - fh / 2)

  if it.kind == "cta" then
    -- ENTER THE PIT (héros) : losange sang en préfixe + texte ink (vif au survol) + lueur sang douce.
    local blockW = it._prefixW + it._textW
    local x0 = CX - blockW / 2
    local dx = x0 + DIAMOND_R
    -- lueur sang derrière le losange (signature héros) : enfle avec g (survol) ET le flash de press.
    local dAlpha = 0.32 + 0.26 * g + 0.30 * (fs.flash or 0)
    diamond(dx, cy, DIAMOND_R + 2, c.blood, math.min(0.8, dAlpha))
    diamond(dx, cy, DIAMOND_R, c.blood, 1)
    local textX = x0 + it._prefixW
    -- ⭐ YEUX cauchemardesques sur ENTER THE PIT (le héros) : au SURVOL des yeux s'ouvrent autour du texte
    -- (jamais DESSUS : keep-out de l'empreinte réelle du label), pilotés par g (glow lissé) ; au CLIC ils
    -- RÉAGISSENT (s'écarquillent + iris vif + regard vers la souris) via le flash. Dessinés AVANT le texte ->
    -- le libellé reste toujours au-dessus. Repos (g≈0) -> no-op (l'entrée reste un texte gravé propre).
    if it.enabled and (g > 0.02 or (fs.flash or 0) > 0.01) then
      local epx = Forge.PX or 2
      local margin = 26                       -- gouttières latérales pour loger la nuée (hors texte)
      local regW = it._textW + margin * 2      -- région des yeux (design px) : texte + marges
      local regH = math.max(fh + 16, 30)       -- un peu plus haut que la ligne -> de l'air vertical
      local rx = textX - margin
      local ry = math.floor(cy - regH / 2)
      Forge.uiCtaEyes("menu.cta.eyes", rx, ry, regW, regH, label, {
        open = g, react = fs.flash or 0, mouse = { mx = self.mx, my = self.my }, t = self.t,
        labelW = it._textW / epx, labelH = fh / epx, eyeR = 7, pad = 4, frameTh = 0,
      })
    end
    -- couleur du texte : interpole title -> ink avec g (montée continue, pas un saut binaire).
    local col = { c.title[1] + (c.ink[1] - c.title[1]) * g,
                  c.title[2] + (c.ink[2] - c.title[2]) * g,
                  c.title[3] + (c.ink[3] - c.title[3]) * g }
    -- faux glow : passes sang décalées sous le texte (la lueur 0 0 16px du designer), alpha piloté par g+flash.
    local gAlpha = 0.20 + 0.14 * g + 0.20 * (fs.flash or 0)
    local goff = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for _, o in ipairs(goff) do
      Draw.textTrackedL(label, textX + o[1], ty + o[2], { c.blood[1], c.blood[2], c.blood[3], gAlpha }, f, track)
    end
    Draw.textTrackedL(label, textX, ty, col, f, track)
  else
    -- Secondaires / désactivées : texte centré. Survol -> ink vif + soulignement sang qui « se remplit ».
    local base = (it.kind == "off") and c.ink4 or c.ink2
    local col = base
    if it.enabled then
      col = { base[1] + (c.ink[1] - base[1]) * g, base[2] + (c.ink[2] - base[2]) * g, base[3] + (c.ink[3] - base[3]) * g }
    end
    local w = Draw.textTrackedC(label, CX, ty, col, f, track)
    -- soulignement sang : largeur proportionnelle à g (se déploie du centre) + un coup de flash au press.
    local uw = (g + 0.6 * (fs.flash or 0))
    if it.enabled and uw > 0.02 and love and love.graphics then
      local ul = math.ceil(w * math.min(1, uw))
      Draw.setColor(c.blood, 0.8 * math.min(1, g + (fs.flash or 0)))
      love.graphics.rectangle("fill", math.floor(CX - ul / 2), ty + fh + 1, ul, 1)
      Draw.reset()
    end
  end
end

function Menu:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- Kicker (saveur) — Space Mono ~10px, tracking large, ink-3, centré.
  Draw.textTrackedC(T("menu.descend"), CX, 250, c.ink3, Theme.label(10), 4)
  -- Logotype gothique « The Pit » (PRÉSERVÉ : Jacquard) — ~74px, ink, ombre + lueur sang.
  drawTitleGlow(T("menu.title"), CX, 280, Theme.display(74))
  -- Filet laiton/sang + losange central (Draw.divider profil triangulaire + diamant sang au centre).
  Draw.divider(CX, 422, 300, c.brass, 0.9)
  diamond(CX, 422, 4, c.blood, 1)

  -- Entrées empilées : ENTER (héros) puis secondaires/désactivées. L'état hover vient du hit-test de la scène.
  for i, it in ipairs(self.items) do
    self:drawItem(it, self.hover == i)
  end

  -- Pied : reliques inscrites (méta-progression) en gold à gauche, version en ink-5 à droite.
  local inscribed = (Grimoire.count and Grimoire.count()) or 0
  Draw.text(T("menu.relics", { n = inscribed, total = #Relics.order }), 24, 690, c.gold, Theme.label(10))
  Draw.textR(T("menu.tag"), Draw.W - 24, 690, c.ink5, Theme.label(10))

  -- Toggle MODE DEV (coin haut-gauche) : visible seulement si Dev.ENABLED. Libellé en dur (dev-only).
  if self.devRect then
    local on, r = Dev.fullUnlock(), self.devRect
    Draw.rect(r.x, r.y, r.w, r.h, c.panelDeep, on and c.gold or c.hair, 1)
    Draw.text(on and "[DEV] FULL UNLOCK: ON" or "[DEV] FULL UNLOCK: OFF", r.x + 10, r.y + 7,
      on and c.goldBright or c.fainter, Theme.label(10))
  end

  Draw.finish()
end

-- ── Souris : hover (mousemoved) + arme (mousepressed) + agit (mousereleased). La souris arrive en VIRTUEL
-- (320×180, main.lua a divisé par view.scale) -> on la repasse en DESIGN (×4) pour le hit-test, comme l'UI.
-- Survol : pose le hover de la scène ET la cible Feel de CHAQUE entrée (l'entrée survolée -> 1, les autres
-- -> 0 ; les easings ramènent la lueur en douceur). Le tick de son (hook) ne part qu'au franchissement.
function Menu:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.hover = self:itemAt(dx, dy)
  for i, it in ipairs(self.items) do
    if it.enabled then Feel.hover(feelId(it), self.hover == i) end
  end
end

-- ⭐ Pointer-DOWN : feedback IMMÉDIAT (Feel.press = squash + flash + lueur) et l'action est DIFFÉRÉE (~160 ms)
-- -> on SENT le clic avant que l'écran change. Le verrou de Feel empêche un double-déclenchement (re-clic
-- ignoré tant que l'action est en file). Plus de « dead-click » : le feedback part toujours à t=0.
function Menu:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if self.devRect then -- MODE DEV : clic sur le toggle full-unlock (immédiat, pas une action de navigation)
    local r = self.devRect
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then Dev.toggleFullUnlock(); return end
  end
  local i = self:itemAt(dx, dy)
  if i then
    self.hover = i; self.down = true
    local it = self.items[i]
    Feel.press(feelId(it), it.action) -- feedback immédiat + action différée (fire dans Feel.update)
  end
end

-- Relâche : l'action a déjà été ARMÉE au press (différée). On lâche juste l'état « down » de la scène ;
-- surtout NE PAS re-déclencher l'action ici (sinon double-fire avec le press différé).
function Menu:mousereleased(vx, vy, button)
  if button ~= 1 then return end
  self.down = false
end

-- Clavier : navigation haut/bas parmi les entrées actives + entrée/espace pour valider (action différée via
-- Feel.fire -> même JUICE que la souris, sans verrou de re-clic). Le bouton « ressent » la validation clavier.
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
    for k, i in ipairs(order) do Feel.hover(feelId(self.items[i]), i == self.hover) end
  elseif key == "return" or key == "kpenter" or key == "space" then
    if self.hover and self.items[self.hover].action then
      local it = self.items[self.hover]
      Feel.fire(feelId(it), it.action)
    end
  elseif key == "u" and Dev.ENABLED then -- MODE DEV : toggle full-unlock du codex
    Dev.toggleFullUnlock()
  end
end

return Menu
