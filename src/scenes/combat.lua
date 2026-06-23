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
local Dividers = require("src.ui.dividers") -- séparateur laiton propre (chrome haut)
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
  Feel.update(frameDt) -- JUICE (remplace Forge.uiTick) : avance survol/press des boutons de fin (RENDER pur)
  if self.paused then return end -- combat GELÉ (sim + anims) -> reprise identique via Espace
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
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

-- Chrome haute (espace design) : titre gravé + hint inscrit à gauche, « vs NOM » centré. PROPRE : Cinzel pour
-- le titre/nom (gravé), Space Mono pour le hint (inscrit), pas de Silkscreen ni de cadre gritty. Un filet laiton
-- discret sous la bande -> séparation nette sans masquer l'arène. (Le HUD générique est désactivé : daChrome.)
function Combat:_drawChrome()
  local c = Theme.c
  -- titre d'écran : Cinzel gravé, capitales, interlettrage large (rôle heading).
  Draw.textTrackedL(T("ui.title") .. "  ·  " .. T("scene.combat"):upper(), 16, 14, c.ink2, Theme.heading(13), 1.4)
  -- hint : Space Mono (toutes les légendes/valeurs), ink sourd.
  Draw.text(T(self.hintKey), 16, 34, c.ink4, Theme.label(10))

  -- « vs NOM » centré : « vs » en laiton sourd (Space Mono), NOM de l'adversaire en Cinzel sang (gravé).
  local lf = Theme.label(13)
  local nf = Theme.subhead(16)
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  local vsW = Draw.textWidth("vs ", lf)
  local nmW = Draw.textWidth(name, nf)
  local x = math.floor(Draw.W / 2 - (vsW + nmW) / 2)
  Draw.text("vs ", x, 18, c.ink4, lf)
  Draw.text(name, x + vsW, 15, c.bloodL, nf)
  -- filet laiton sous la bande (séparation propre, profil triangulaire centré).
  Dividers.brass(Draw.W / 2, 40, 360)
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
  self:_drawChrome()
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
  if button ~= 1 or not self.arena.over then return end -- entrées ignorées tant que le combat n'est pas fini
  self.mx, self.my = vx * 4, vy * 4 -- virtuel -> DESIGN (les rects de fin sont en espace design)
  -- 2A — plus de clic-n'importe-où : on hit-teste UNIQUEMENT les deux boutons de l'écran de fin.
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
