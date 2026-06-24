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
local Modal = require("src.ui.modal")    -- modale plein écran OPAQUE (verdict + boutons de choix) : recouvre l'arène
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash)
local T = require("src.core.i18n").t

local Combat = {}
Combat.__index = Combat

-- Post-mortem "pourquoi" (1.3) : ordre FIXE des causes de mort = tie-break déterministe pour la
-- cause dominante (jamais `pairs`). Les afflictions priment sur la frappe à égalité (thème + clarté).
local CAUSE_ORDER = { "poison", "rot", "bleed", "burn", "shock", "reflect", "attack" }

-- Boutons de fin (espace DESIGN) : CHRONICLE (secondary) + CONTINUE (primary, CTA). Largeurs/hauteurs propres.
local BTN_W, BTN_H, BTN_GAP = 176, 44, 18

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
    speed = 1, skipping = false, -- VITESSE spectateur (refonte Combat Frame) : 1×/2× ; SKIP = avance jusqu'à la fin
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

-- Un PAS de simulation+rendu (frameDt fixe). Le déroulé reste DÉTERMINISTE (arena.t incrémenté de frameDt) :
-- 2× = 2 pas/frame, SKIP = beaucoup de pas/frame -> même bataille, juste rejouée plus vite (spectateur).
function Combat:_step(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
end

function Combat:update(frameDt)
  Feel.update(frameDt) -- JUICE (remplace Forge.uiTick) : avance survol/press des boutons de fin (RENDER pur)
  Feel.hover("combat.spd1", inBtn(self.mx, self.my, self._btnSpd1))
  Feel.hover("combat.spd2", inBtn(self.mx, self.my, self._btnSpd2))
  Feel.hover("combat.skip", inBtn(self.mx, self.my, self._btnSkip))
  if self.paused then return end -- combat GELÉ (sim + anims) -> reprise identique via Espace
  -- VITESSE : hors conclusion, 1×/2× pas par frame (SKIP -> beaucoup, borné anti-gel). Une fois CONCLU, on
  -- continue à avancer UN pas/frame (overAge + anims de mort -> l'écran de fin apparaît, comportement d'avant).
  local steps = self.arena.over and 1 or (self.skipping and 240 or (self.speed or 1))
  for _ = 1, steps do
    self:_step(frameDt)
    if self.arena.over then break end
  end
  if self.arena.over then self.skipping = false end
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
  self.ambient:draw("combat")
  Draw.finish()
end

function Combat:drawWorld()
  self.renderer:draw(false)
end

-- Vivants/total par équipe (gauche = joueur, droite = ghost). Lecture seule de la SIM.
function Combat:_counts()
  local la, lt, ra, rt = 0, 0, 0, 0
  for _, u in ipairs(self.arena.units) do
    if u.team == "left" then lt = lt + 1; if u.alive then la = la + 1 end
    else rt = rt + 1; if u.alive then ra = ra + 1 end end
  end
  return la, lt, ra, rt
end

-- Petite goutte de sang (pip d'hôte) centrée en (cx,cy) : pleine = unité vivante, sourde = tombée.
local function teardrop(cx, cy, on, col)
  local C = Theme.c
  Draw.setColor(on and (col or C.blood) or C.stone700)
  if love.graphics then
    love.graphics.polygon("fill", cx, cy - 5, cx - 3.5, cy + 1.5, cx + 3.5, cy + 1.5)
    love.graphics.circle("fill", cx, cy + 1.5, 3.5)
  end
  Draw.reset()
end

-- Jauge de FATIGUE (centre, sous le « vs ») : progression vers l'enrage (t / FATIGUE_START) ; ENRAGE s'allume
-- au plafond (au-delà, l'usure globale frappe tout le monde -> tout combat conclut). Lecture seule.
function Combat:_drawFatigue()
  local c = Theme.c
  local ft = self.arena.fatigue
  local start = (ft and ft.start) or self.arena.FATIGUE_START or 1020
  local pct = math.max(0, math.min(1, (self.arena.t or 0) / start))
  local enraged = pct >= 1
  local f = Theme.label(8)
  local barW = 200
  local total = f:getWidth(T("ui.fatigue")) + 8 + barW + 8 + f:getWidth(T("ui.enrage"))
  local x, y = math.floor(Draw.W / 2 - total / 2), 52
  Draw.text(T("ui.fatigue"), x, y - 4, c.ink4, f)
  local bx = x + f:getWidth(T("ui.fatigue")) + 8
  Draw.rect(bx, y - 2, barW, 5, { 0x0a / 255, 0x08 / 255, 0x10 / 255, 1 }, c.iron, 1)
  local fillW = math.floor((barW - 2) * pct)
  if fillW > 0 then Draw.rect(bx + 1, y - 1, fillW, 3, enraged and c.bloodL or c.blood) end
  Draw.text(T("ui.enrage"), bx + barW + 8, y - 4, enraged and c.bloodL or c.ink5, f)
end

-- HUD haut (refonte « Combat Frame ») : [ YOUR HOST · pips · count ] · [ ROUND·GHOST / vs NOM ] · [ count ·
-- pips · NOM ]. Pips = un par unité (plein = vivant). PROPRE (Cinzel pour le nom, Space Mono pour le reste).
function Combat:_drawCombatHud()
  local c = Theme.c
  local la, lt, ra, rt = self:_counts()
  local labF, valF = Theme.label(9), Theme.value(13)
  local midY = 22
  -- GAUCHE : YOUR HOST + pips + count.
  Draw.text(T("ui.your_host"), 22, midY - 5, c.ink4, labF)
  local px = 22 + labF:getWidth(T("ui.your_host")) + 12
  local nl = math.min(9, lt)
  for i = 1, nl do teardrop(px + (i - 1) * 9 + 4, midY, i <= la, c.blood) end
  Draw.text(tostring(la), px + nl * 9 + 8, midY - valF:getHeight() / 2, c.ink2, valF)
  -- CENTRE : ROUND·GHOST + vs NOM.
  local run = self.host.run
  Draw.textC(run and T("ui.round_ghost", { n = run.round }) or T("ui.exhibition_ghost"), Draw.W / 2, 8, c.ink4, Theme.label(8))
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  local vf, nf = Theme.bodyItalic(13), Theme.subhead(16)
  local vw, nw = vf:getWidth("vs "), nf:getWidth(name)
  local cx = math.floor(Draw.W / 2 - (vw + nw) / 2)
  Draw.text("vs ", cx, 24, c.ink3, vf)
  Draw.text(name, cx + vw, 22, c.ink, nf)
  -- DROITE : count + pips + NOM (petit), aligné à droite.
  local rx = Draw.W - 22
  Draw.textR(name, rx, midY - 5, c.ink4, labF)
  local nr = math.min(9, rt)
  local pstart = rx - labF:getWidth(name) - 12 - nr * 9
  for i = 1, nr do teardrop(pstart + (i - 1) * 9 + 4, midY, i <= ra, { 0.48, 0.54, 0.42, 1 }) end
  Draw.textR(tostring(ra), pstart - 6, midY - valF:getHeight() / 2, c.ink2, valF)
  self:_drawFatigue()
end

-- Contrôles bas (refonte « Combat Frame ») : « auto-battle in progress · the Pit decides » à gauche ;
-- segments de VITESSE [ 1× | 2× | SKIP ] + « [c] chronicle » à droite. Les rects de vitesse sont posés ICI
-- (hit-test de mousepressed PENDANT le combat). Visible seulement tant que le combat n'est pas conclu.
function Combat:_drawControls()
  local c = Theme.c
  local f = Theme.label(9)
  local y = Draw.H - 17
  Draw.rect(0, Draw.H - 34, Draw.W, 1, { c.brassS[1], c.brassS[2], c.brassS[3], 0.1 })
  -- gauche : statut.
  Draw.text(T("ui.auto_battle"), 18, y - 5, c.ink4, f)
  local aw = f:getWidth(T("ui.auto_battle"))
  Draw.text("  ·  " .. T("ui.pit_decides"), 18 + aw, y - 5, c.ink5, f)
  -- droite : [c] chronicle (extrême droite) + segments de vitesse à sa gauche.
  local hint = T("ui.chronicle_hint")
  Draw.textR(hint, Draw.W - 18, y - 5, c.ink4, f)
  local segs = {
    { id = "spd1", label = "1×", on = (self.speed == 1) and not self.skipping },
    { id = "spd2", label = "2×", on = (self.speed == 2) and not self.skipping },
    { id = "skip", label = T("ui.speed_skip"), on = self.skipping },
  }
  local totalW = 0
  for _, s in ipairs(segs) do s.w = f:getWidth(s.label) + 24; totalW = totalW + s.w end
  local sx = Draw.W - 18 - f:getWidth(hint) - 16 - totalW
  for _, s in ipairs(segs) do
    local r = { x = sx, y = y - 11, w = s.w, h = 22 }
    local hot = inBtn(self.mx, self.my, r)
    Draw.rect(sx, r.y, s.w, 22, s.on and { 0x7a / 255, 0x1d / 255, 0x16 / 255, 1 } or { 0x10 / 255, 0x0d / 255, 0x16 / 255, 1 }, c.iron, 1)
    Draw.textC(s.label, sx + s.w / 2, y - 5, s.on and c.ctaText or (hot and c.ink2 or c.ink3), f)
    if s.id == "spd1" then self._btnSpd1 = r elseif s.id == "spd2" then self._btnSpd2 = r else self._btnSkip = r end
    sx = sx + s.w
  end
end

-- ── Écran de fin (verdict + post-mortem + 2 boutons) ─────────────────────────────────────────────────
-- Verdict via la MOLÉCULE Banner (mot Jacquard + halo) : subtitle = le « POURQUOI » (cause dominante, déjà
-- localisée — « ton venin a fauché 3 »), score = la 1re perte, hint = raccourcis clavier. Sous le bandeau,
-- DEUX boutons propres : CHRONICLE (secondary) ouvre l'overlay, CONTINUE (primary, CTA + yeux) termine.
-- Les rects _btnChron/_btnCont sont posés ICI (espace design) -> hit-test de mousepressed + asserts du test.
function Combat:_drawEndScreen(view)
  local won = self.arena.win
  if not self.summary then self.summary = self:_computeSummary() end
  local s = self.summary

  -- le POURQUOI (cause dominante) si elle existe -> sous-titre sobre de la modale (déjà résolu i18n).
  local why = nil
  if s.cause and s.n > 0 then
    why = T(won and "combat.why.dealt" or "combat.why.slain",
      { cause = T("combat.cause." .. s.cause), n = s.n })
  end

  -- MODALE plein écran OPAQUE (brique design-system) : recouvre l'arène (fini le voile à 0.62 « qu'on voit à
  -- travers » + le hint clavier). Titre cérémonial + tag d'issue + cause + flavor + 2 boutons de choix.
  local res = Modal.draw(view, {
    title = T("modal.verdict_title"),
    tag = won and T("result.victory") or T("result.defeat"),
    tagKind = won and "victory" or "defeat",
    sub = why,
    flavor = T(won and "modal.flavor_victory" or "modal.flavor_defeat"),
    buttons = {
      { id = "combat.chron", label = T("ui.chronicle"), variant = "secondary" },
      { id = "combat.cont", label = T("ui.continue"), variant = "primary" },
    },
    mx = self.mx, my = self.my, t = self.t / 60,
  })
  -- remappe les rects renvoyés -> _btnChron/_btnCont (hit-test de mousepressed + asserts du test headless).
  for _, r in ipairs(res.buttons) do
    if r.id == "combat.chron" then self._btnChron = r
    elseif r.id == "combat.cont" then self._btnCont = r end
  end
end

function Combat:drawOverlay(view)
  Draw.begin(view)
  self:_drawCombatHud()                                  -- HUD haut (hôtes/round/vs/fatigue)
  if not self.arena.over then self:_drawControls() end   -- contrôles bas (vitesse + chronicle) pendant le combat
  Draw.finish()

  self.renderer:drawOverlay(view) -- noms d'unités + nombres flottants (gère sa propre transform)

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
  self.mx, self.my = vx * 4, vy * 4 -- virtuel -> DESIGN (les rects sont en espace design)
  -- VITESSE (pendant le combat) : 1× / 2× / SKIP. Pas d'autre entrée tant que ce n'est pas conclu.
  if not self.arena.over then
    if inBtn(self.mx, self.my, self._btnSpd1) then Feel.press("combat.spd1"); self.speed, self.skipping = 1, false; return end
    if inBtn(self.mx, self.my, self._btnSpd2) then Feel.press("combat.spd2"); self.speed, self.skipping = 2, false; return end
    if inBtn(self.mx, self.my, self._btnSkip) then Feel.press("combat.skip"); self.skipping = true; return end
    return
  end
  -- 2A — plus de clic-n'importe-où : on hit-teste UNIQUEMENT les deux boutons de l'écran de fin.
  -- Feedback de press IMMÉDIAT (Feel.press sans action -> squash/flash) PUIS action TOUT DE SUITE : le test
  -- headless asserte openChronicle/finishCombat juste après le clic -> on n'utilise PAS l'action différée.
  if inBtn(self.mx, self.my, self._btnChron) then
    -- ⭐ ACTION DIFFÉRÉE (Feel, bible §4) : press visible AVANT l'ouverture (~160 ms) -> on SENT le clic.
    -- Le test mûrit l'action via Combat:update (-> Feel.update) avant d'asserter openChronicle.
    Feel.press("combat.chron", function()
      if self.host.openChronicle then self.host.openChronicle() end -- overlay chronique (no-op hors run)
    end)
    return
  end
  if inBtn(self.mx, self.my, self._btnCont) then
    -- ⭐ DIFFÉRÉE : press visible AVANT le changement de scène. EXHIBITION (banc d'essai) : payload.onFinish
    -- prend la main (retour Proving Ground, sans toucher la méta de run) ; sinon host ; fallback goto build.
    Feel.press("combat.cont", function()
      if self.payload.onFinish then self.payload.onFinish(self.arena.win, self.arena)
      elseif self.host.finishCombat then self.host.finishCombat(self.arena.win)
      else self.host.goto("build") end
    end, { delay = Feel.CTA_DELAY })
    return
  end
end

return Combat
