-- src/scenes/combat.lua
-- Phase de COMBAT : on rejoue automatiquement la bataille entre l'équipe du joueur (gauche,
-- construite dans la phase build) et une équipe adverse (droite, IA de seed). Spectateur :
-- aucune entrée pendant le combat. À la fin -> bandeau VICTOIRE/DEFAITE puis retour au build.
--
-- Sépare SIM et RENDER : `arena` (src/combat) résout la bataille (déterministe, seedée) et émet
-- des événements ; `renderer` (src/render) les consomme pour l'animation. La scène orchestre.
--
-- ── UI = kit PROPRE (.dc.html / design-system), aligné sur src/scenes/build.lua ──────────────────────
-- La scène n'utilise plus Forge (kit legacy) : la chrome (titre/hint/« vs »), le verdict (Banner) et les
-- boutons de fin (Button : CHRONICLE secondary / CONTINUE primary+yeux) viennent du kit propre. Le JUICE
-- (survol/press) passe par Feel (RENDER pur, headless-safe). Le texte est en rôles de police Theme via Draw
-- (Cinzel gravé pour titres/noms, Space Mono pour valeurs/hints, Spectral pour la prose) -> net à toute réso.
--
-- Interface scène : update / drawWorld / drawBack / drawOverlay(view) / keypressed / mousepressed / mousemoved.

local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local Chronicle = require("src.render.chronicle")
local Ambient = require("src.fx.ambient")
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Button = require("src.ui.button")  -- boutons propres (CHRONICLE secondary / CONTINUE primary)
local Banner = require("src.ui.banner")  -- bandeau de verdict (VICTORY / DEFEAT) : remplace l'overlay forge
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash)
local Reliquary = require("src.ui.reliquary") -- ENROBAGE : cadre de pierre gravée autour de l'écran (spec §A.9)
local T = require("src.core.i18n").t

local Combat = {}
Combat.__index = Combat

-- Post-mortem "pourquoi" (1.3) : ordre FIXE des causes de mort = tie-break déterministe pour la
-- cause dominante (jamais `pairs`). Les afflictions priment sur la frappe à égalité (thème + clarté).
local CAUSE_ORDER = { "poison", "rot", "bleed", "burn", "shock", "reflect", "attack" }

-- Boutons de fin (espace DESIGN) : CHRONICLE (secondary) + CONTINUE (primary, CTA). Largeurs/hauteurs propres.
local BTN_W, BTN_H, BTN_GAP = 176, 44, 18

-- ENROBAGE (spec §A.9 / §C.1) : cadre de pierre gravée plein écran (épaisseur d'art FRAME_FT) + onglet de nom
-- centré sur le bord haut. Le contenu (arène + « vs » + bandeau bas) vit À L'INTÉRIEUR de l'inset.
local FRAME_FT = 8          -- épaisseur d'art de la bande (×4 = ~32px design) ; pad = marge contenu/pierre
local STRIP_H = 30          -- hauteur du bandeau de contrôle bas (auto-battle + vitesse + hints), en design

-- Hit-test d'un rect (espace design). Tolère un curseur hors-écran (mx<0) et un rect absent.
local function inBtn(mx, my, r)
  return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

function Combat.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local arena = Arena.new({ left = payload.left, right = payload.right, autoReset = false, seed = payload.seed })
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette, payload = payload,
    daChrome = true, -- chrome DA portée par la scène (pas de HUD générique : cf. main.lua drawHud)
    nativeWorld = true, -- arène rendue en RÉSOLUTION NATIVE (sprites primgen 64px nets, pas via le canvas 320)
    titleKey = "scene.combat",
    hintKey = "ui.hint_combat",
    enemyKey = payload.enemyKey,
    ambient = Ambient.new(payload.seed or 11), -- atmosphère "combat" (gueule du puits + braises)
    arena = arena,
    renderer = ArenaDraw.new(arena, palette),
    paused = false, -- PAUSE spectateur (Espace) : gèle entièrement le combat (analyse / screenshots)
    speed = 1,      -- VITESSE spectateur (toggle bandeau bas) : 1× / 2× pas de temps FIXES par frame
    mx = -1, my = -1, -- curseur (espace design) : survol des boutons de fin + gaze des yeux du CTA
  }, Combat)
  self:_track() -- écoute le bus SIM (lecture seule) pour le post-mortem "pourquoi" (1.3)
  return self
end

function Combat:restart()
  -- Même seed -> bataille rejouée À L'IDENTIQUE (c'est déjà un replay déterministe).
  self.arena = Arena.new(
    { left = self.payload.left, right = self.payload.right, autoReset = false, seed = self.payload.seed })
  self.renderer = ArenaDraw.new(self.arena, self.palette)
  self:_track()
end

-- 1.3 — Attribution causale : on ÉCOUTE le bus SIM (lecture seule, comme le renderer ; aucun effet sur
-- la sim -> golden inchangé). "damage" mémorise le dernier coup reçu par chaque unité ; "death" fige
-- l'attribution (qui a fauché qui, par quelle cause, à quel tick).
function Combat:_track()
  self.killLog = {} -- ordre de tick : { victim, killer, cause, tick }
  self.lastHit = {} -- [victime] = { source, cause } : dernier coup encaissé
  self.summary = nil -- résumé "pourquoi", mémoïsé en fin de combat
  local arena = self.arena
  arena.bus:on("damage", function(r)
    if r.target then self.lastHit[r.target] = { source = r.source, cause = r.cause or "attack" } end
  end)
  arena.bus:on("death", function(u)
    local h = self.lastHit[u]
    self.killLog[#self.killLog + 1] =
      { victim = u, killer = h and h.source, cause = (h and h.cause) or "attack", tick = arena.t }
  end)
  self.chron = Chronicle.new(arena) -- modèle du JOURNAL — écoute le bus (golden-safe) ; affiché par l'overlay [c]
end

-- Résumé du combat (mémoïsé) : cause DOMINANTE + PREMIÈRE perte du joueur. En victoire on lit ce que
-- TON équipe a infligé (morts ennemies "right"), en défaite ce qui T'a fauché (morts joueur "left").
function Combat:_computeSummary()
  local foe = self.arena.win and "right" or "left"
  local count, firstLoss = {}, nil
  for _, k in ipairs(self.killLog) do
    if k.victim.team == foe then count[k.cause] = (count[k.cause] or 0) + 1 end
    if k.victim.team == "left" and not firstLoss then firstLoss = k.victim end
  end
  local topCause, topN = nil, 0
  for _, cause in ipairs(CAUSE_ORDER) do -- ordre fixe = tie-break déterministe
    if (count[cause] or 0) > topN then topCause, topN = cause, count[cause] end
  end
  return { win = self.arena.win, cause = topCause, n = topN, firstLoss = firstLoss }
end

function Combat:update(frameDt)
  Feel.update(frameDt) -- JUICE (remplace Forge.uiTick) : avance survol/press des boutons (RENDER pur)
  if self.paused then return end -- combat GELÉ (sim + anims) -> reprise identique via Espace
  self.ambient:update(frameDt)
  -- VITESSE : on avance la SIM `speed` PAS DE TEMPS FIXES par frame (PAS un gros dt -> déterminisme PRÉSERVÉ,
  -- juste un wall-clock accéléré ; chaque pas émet/anime normalement). Une fois fini, 1 pas (fondus de mort/VFX
  -- continuent via le renderer, la SIM est inerte). speed=1 par défaut -> headless/golden strictement intacts.
  local steps = self.arena.over and 1 or (self.speed or 1)
  for _ = 1, steps do
    self.t = self.t + frameDt
    self.arena:update(frameDt, self.t)   -- SIM (émet des événements)
    self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
    if self.arena.over then break end
  end
  if self.arena.over then
    self.hintKey = "ui.hint_combat_end"
    -- survol des deux boutons de fin (glow/lift lissés) — n'a d'effet visible qu'une fois l'écran affiché.
    Feel.hover("combat.chron", inBtn(self.mx, self.my, self._btnChron))
    Feel.hover("combat.cont", inBtn(self.mx, self.my, self._btnCont))
  end
end

-- La souris arrive en espace VIRTUEL (main.lua:toVirtual) ; les rects de fin + le gaze des yeux sont en
-- espace DESIGN -> on convertit ×4 ICI (comme relicpick/runover). self.mx/self.my sont donc en DESIGN.
function Combat:mousemoved(vx, vy) self.mx, self.my = vx * 4, vy * 4 end

-- Atmosphère "combat" native (gueule du puits + braises), derrière les combattants pixel.
function Combat:drawBack(view)
  Draw.begin(view)
  -- L'arène (gradient qui ROUGIT + stalactites + lueur du puits) est CLIPPÉE à l'intérieur du cadre reliquaire
  -- -> la pierre gravée borde une arène nette (pas un fond plein écran). Le cadre est posé en overlay par-dessus.
  local ix, iy, iw, ih = Reliquary.inset(0, 0, Draw.W, Draw.H, { ft = FRAME_FT, pad = 2 })
  Draw.scissor(view, ix, iy, iw, ih)
  self.ambient:draw("combat")
  Draw.noScissor()
  Draw.finish()
end

function Combat:drawWorld()
  self.renderer:draw(false)
end

-- Chrome haute (espace design) : titre gravé + hint inscrit à gauche, « vs NOM » centré. PROPRE : Cinzel pour
-- le titre/nom (gravé), Space Mono pour le hint (inscrit), pas de Silkscreen ni de cadre gritty. Un filet laiton
-- discret sous la bande -> séparation nette sans masquer l'arène. (Le HUD générique est désactivé : daChrome.)
-- Onglet de nom de l'écran : pilier de pierre centré sur le bord HAUT du cadre, portant le nom (Cinzel tracké
-- en encre tarnie). Réutilisable -> à extraire en helper partagé quand on propage le cadre aux autres écrans.
function Combat:_drawNameTab(label)
  local c = Theme.c
  local f = Theme.heading(12)
  local tracking = 4
  local tw = Draw.textWidth(label, f) + tracking * math.max(0, #label - 1)
  local w, h, y = tw + 44, 24, 6
  local x = math.floor(Draw.W / 2 - w / 2)
  Draw.rect(x, y, w, h, Theme.hex(0x0e0a14), c.iron, 1)        -- pilier métal sombre + liseré iron
  if love and love.graphics then                              -- éclat laiton haut (biseau)
    Draw.setColor(c.brassS, 0.18); love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 1); Draw.reset()
  end
  Draw.textTrackedC(label, Draw.W / 2, y + (h - (f and f:getHeight() or 12)) / 2, Theme.hex(0xcdbca0), f, tracking)
end

-- Chrome de combat = CADRE RELIQUAIRE (bande de pierre gravée plein écran) + onglet « COMBAT » + « vs NOM »
-- en haut DANS l'arène. Plus de chrome haut-gauche ni de hint ici (déplacés -> bandeau bas).
function Combat:_drawChrome()
  local c = Theme.c
  Reliquary.draw(0, 0, Draw.W, Draw.H, { ft = FRAME_FT })
  self:_drawNameTab(T("scene.combat"):upper())
  -- « vs NOM » : « vs » laiton sourd (Space Mono) + NOM ennemi en Cinzel sang (gravé), sous l'onglet.
  local lf = Theme.label(13)
  local nf = Theme.subhead(16)
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  local vsW = Draw.textWidth("vs ", lf)
  local nmW = Draw.textWidth(name, nf)
  local x = math.floor(Draw.W / 2 - (vsW + nmW) / 2)
  Draw.text("vs ", x, 58, c.ink4, lf)
  Draw.text(name, x + vsW, 55, c.bloodL, nf)
end

-- Bandeau de contrôle bas (spec §C.4) : DANS l'inset, collé au bord bas de l'arène. Gauche = statut auto-battle
-- (Space Mono), droite = toggle vitesse segmenté 1× / 2× (actif = sang) + hint [c]/[r]. Pose self._speedRect.
function Combat:_drawControlStrip()
  local c = Theme.c
  local gr = love and love.graphics
  local ix, iy, iw, ih = Reliquary.inset(0, 0, Draw.W, Draw.H, { ft = FRAME_FT, pad = 2 })
  local sy = iy + ih - STRIP_H
  Draw.setColor(c.brass, 0.10); if gr then gr.rectangle("fill", ix, sy, iw, 1) end
  Draw.setColor({ 0.031, 0.016, 0.039, 0.5 }); if gr then gr.rectangle("fill", ix, sy + 1, iw, STRIP_H - 1) end
  Draw.reset()
  local midY = sy + STRIP_H / 2
  local lf = Theme.label(10)
  local lh = lf and lf:getHeight() or 10
  -- GAUCHE : statut auto-battle (clé existante « auto-battle in progress... »).
  Draw.text(T("ui.hint_combat"), ix + 14, midY - lh / 2, c.ink4, lf)
  -- DROITE : toggle vitesse 1× / 2× calé à droite, puis hint [c]/[r] à sa gauche.
  local segW, segH = 32, 18
  local toggX = ix + iw - 14 - segW * 2
  local toggY = math.floor(midY - segH / 2)
  self._speedRect = { x = toggX, y = toggY, w = segW * 2, h = segH }
  local sf = Theme.label(9)
  local sfh = sf and sf:getHeight() or 9
  local labels = { "1×", "2×" }
  for i = 1, 2 do
    local sx = toggX + (i - 1) * segW
    local active = (self.speed == i)
    Draw.rect(sx, toggY, segW, segH, active and c.blood or Theme.hex(0x100d16), c.iron, 1)
    Draw.textTrackedC(labels[i], sx + segW / 2, toggY + (segH - sfh) / 2, active and Theme.hex(0xf3dcc6) or c.ink3, sf, 0.5)
  end
  Draw.textR(T("ui.hint_combat_end"), toggX - 12, midY - lh / 2, c.ink4, lf)
end

-- ── Écran de fin (verdict + post-mortem + 2 boutons) ─────────────────────────────────────────────────
-- Verdict via la MOLÉCULE Banner (mot Jacquard + halo) : subtitle = le « POURQUOI » (cause dominante, déjà
-- localisée — « ton venin a fauché 3 »), score = la 1re perte, hint = raccourcis clavier. Sous le bandeau,
-- DEUX boutons propres : CHRONICLE (secondary) ouvre l'overlay, CONTINUE (primary, CTA + yeux) termine.
-- Les rects _btnChron/_btnCont sont posés ICI (espace design) -> hit-test de mousepressed + asserts du test.
function Combat:_drawEndScreen(view)
  local c = Theme.c
  local won = self.arena.win
  if not self.summary then self.summary = self:_computeSummary() end
  local s = self.summary

  -- 1) le POURQUOI (sous-titre du bandeau) : cause dominante si elle existe (la frappe/le reflet l'ont aussi),
  --    sinon nil. La cause est déjà résolue i18n -> le bandeau l'affiche centrée (Space Mono tracké).
  local why = nil
  if s.cause and s.n > 0 then
    why = T(won and "combat.why.dealt" or "combat.why.slain",
      { cause = T("combat.cause." .. s.cause), n = s.n })
  end
  local firstLoss = s.firstLoss and T("combat.why.first_loss", { name = T("unit." .. s.firstLoss.id .. ".name") }) or nil

  -- 2) BANNER (kind victory/defeat) — centré horizontalement, ancré au tiers supérieur de l'arène assombrie.
  local bW = 760
  local bH = 188
  local bx = math.floor(Draw.W / 2 - bW / 2)
  local by = math.floor(Draw.H / 2 - bH / 2 - 34) -- remonté : laisse la place aux boutons dessous
  Draw.begin(view)
  -- voile sombre derrière le verdict (lit l'arène à travers, sans la noyer) -> le bandeau ressort.
  Draw.rect(0, by - 16, Draw.W, bH + 116, { c.void[1], c.void[2], c.void[3], 0.62 })
  Banner.draw(bx, by, bW, won and "victory" or "defeat",
    won and T("result.victory") or T("result.defeat"),
    { subtitle = why, score = firstLoss, hint = T("ui.hint_combat_end"), t = self.t / 60, h = bH })
  Draw.finish()

  -- 3) BOUTONS de fin (sous le bandeau) : posés en DESIGN -> rects pour le hit-test + les asserts du test.
  local totalW = BTN_W * 2 + BTN_GAP
  local btnX = math.floor(Draw.W / 2 - totalW / 2)
  local btnY = math.floor(by + bH + 18)
  self._btnChron = { x = btnX, y = btnY, w = BTN_W, h = BTN_H }
  self._btnCont = { x = btnX + BTN_W + BTN_GAP, y = btnY, w = BTN_W, h = BTN_H }

  Draw.begin(view)
  Button.draw(self._btnChron.x, self._btnChron.y, BTN_W, BTN_H, "secondary", T("ui.chronicle"),
    { hover = inBtn(self.mx, self.my, self._btnChron), feel = Feel.state("combat.chron"), id = "combat.chron" })
  Button.draw(self._btnCont.x, self._btnCont.y, BTN_W, BTN_H, "primary", T("ui.continue"),
    { hover = inBtn(self.mx, self.my, self._btnCont), feel = Feel.state("combat.cont"), id = "combat.cont",
      mouse = { mx = self.mx, my = self.my }, t = self.t / 60 }) -- yeux du CTA : gaze vers la souris (espace design)
  Draw.finish()
end

function Combat:drawOverlay(view)
  Draw.begin(view)
  self:_drawChrome()
  Draw.finish()

  self.renderer:drawOverlay(view) -- barres de vie + nombres flottants + pips (gère sa propre transform)

  -- Bandeau de contrôle bas (vitesse + hints), au-dessus de l'arène, sous le cadre.
  Draw.begin(view)
  self:_drawControlStrip()
  Draw.finish()

  -- Verdict + post-mortem + boutons (1.3 / 2A) : l'attribution causale est la précondition du ranked/rétention.
  -- On attend overAge >= 20 (laisse l'anim de mort se poser) avant d'afficher l'écran de fin.
  if self.arena.over and self.arena.overAge >= 20 then
    self:_drawEndScreen(view)
  end

  -- Indicateur de PAUSE : glyphe ❚❚ DESSINÉ (pas de texte -> aucune dépendance i18n), haut-centre, hors
  -- de la zone des grilles -> screenshot lisible. Le combat figé est déjà un retour clair en soi.
  if self.paused then
    Draw.begin(view)
    local c = Theme.c
    local bx, by = Draw.W / 2 - 5, 56
    Draw.setColor(c.ink, 0.92)
    if love and love.graphics then
      love.graphics.rectangle("fill", bx, by, 4, 14)
      love.graphics.rectangle("fill", bx + 7, by, 4, 14)
    end
    Draw.reset()
    Draw.finish()
  end
end

function Combat:keypressed(key)
  if key == "space" then self.paused = not self.paused; return end -- PAUSE / reprise (spectateur)
  if key == "r" then self:restart() end
end

function Combat:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx * 4, vy * 4 -- virtuel -> DESIGN (rects de fin + toggle vitesse en espace design)
  -- Toggle de VITESSE (bandeau bas) : cliquable PENDANT le combat (bascule 1× / 2×). Feedback de press seul.
  if not self.arena.over then
    if self._speedRect and inBtn(self.mx, self.my, self._speedRect) then
      Feel.press("combat.speed"); self.speed = (self.speed == 2) and 1 or 2
    end
    return -- rien d'autre à cliquer tant que le combat tourne (spectateur)
  end
  -- 2A — écran de fin : on hit-teste UNIQUEMENT les deux boutons.
  -- Feedback de press IMMÉDIAT (Feel.press sans action -> squash/flash) PUIS action TOUT DE SUITE : le test
  -- headless asserte openChronicle/finishCombat juste après le clic -> on n'utilise PAS l'action différée.
  if inBtn(self.mx, self.my, self._btnChron) then
    Feel.press("combat.chron")
    -- CHRONICLE : ouvre l'overlay modal (chronique du combat en cours). No-op hors run (exhibition).
    if self.host.openChronicle then self.host.openChronicle() end
    return
  end
  if inBtn(self.mx, self.my, self._btnCont) then
    Feel.press("combat.cont")
    -- CONTINUE : route normale (comme l'ancien clic). EXHIBITION (banc d'essai) : payload.onFinish prend
    -- la main (retour Proving Ground, SANS toucher la méta de run). Sinon host (résout vies/victoires).
    if self.payload.onFinish then self.payload.onFinish(self.arena.win, self.arena)
    elseif self.host.finishCombat then self.host.finishCombat(self.arena.win)
    else self.host.goto("build") end
    return
  end
end

return Combat
