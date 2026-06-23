-- src/scenes/combat.lua
-- Phase de COMBAT : on rejoue automatiquement la bataille entre l'équipe du joueur (gauche,
-- construite dans la phase build) et une équipe adverse (droite, IA de seed). Spectateur :
-- aucune entrée pendant le combat. À la fin -> bandeau VICTOIRE/DEFAITE puis retour au build.
--
-- Sépare SIM et RENDER : `arena` (src/combat) résout la bataille (déterministe, seedée) et émet
-- des événements ; `renderer` (src/render) les consomme pour l'animation. La scène orchestre.
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mousepressed.

local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local Ambient = require("src.fx.ambient")
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local T = require("src.core.i18n").t

local Combat = {}
Combat.__index = Combat

-- Post-mortem "pourquoi" (1.3) : ordre FIXE des causes de mort = tie-break déterministe pour la
-- cause dominante (jamais `pairs`). Les afflictions priment sur la frappe à égalité (thème + clarté).
local CAUSE_ORDER = { "poison", "rot", "bleed", "burn", "shock", "reflect", "attack" }

function Combat.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local arena = Arena.new({ left = payload.left, right = payload.right, autoReset = false, seed = payload.seed })
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette, payload = payload,
    daChrome = true, -- chrome DA portée par la scène
    nativeWorld = true, -- arène rendue en RÉSOLUTION NATIVE (sprites primgen 64px nets, pas via le canvas 320)
    titleKey = "scene.combat",
    hintKey = "ui.hint_combat",
    enemyKey = payload.enemyKey,
    ambient = Ambient.new(payload.seed or 11), -- atmosphère "combat" (gueule du puits + braises)
    arena = arena,
    renderer = ArenaDraw.new(arena, palette),
    paused = false, -- PAUSE spectateur (Espace) : gèle entièrement le combat (analyse / screenshots)
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
  if self.paused then return end -- combat GELÉ (sim + anims + horloge) -> reprise identique via Espace
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
  if self.arena.over then
    self.hintKey = "ui.hint_combat_end"
  end
end

-- Atmosphère "combat" native (gueule du puits + braises), derrière les combattants pixel.
function Combat:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("combat")
  Draw.finish()
end

function Combat:drawWorld()
  self.renderer:draw(false)
end

function Combat:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)
  -- Chrome debug + adversaire (centré haut, "vs" éteint + nom en sang).
  Draw.text(T("ui.title") .. "  -  " .. T("scene.combat"):upper(), 16, 14, c.faint, Theme.ui(11))
  Draw.text(T(self.hintKey), 16, 32, c.ghost, Theme.ui(9))
  local font = Theme.ui(13)
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  love.graphics.setFont(font)
  local x = Draw.W / 2 - (font:getWidth("vs ") + font:getWidth(name)) / 2
  Draw.text("vs ", x, 18, c.faint, font)
  Draw.text(name, x + font:getWidth("vs "), 18, c.bloodBright, font)
  Draw.finish()

  self.renderer:drawOverlay(view) -- noms d'unités + nombres flottants (gère sa propre transform)

  -- Bandeau VICTORY / DEFEAT (logotype gothique) + post-mortem "POURQUOI" (1.3) : cause dominante +
  -- 1re perte, attribuées depuis le bus. L'attribution causale est la précondition du ranked/rétention.
  if self.arena.over and self.arena.overAge >= 20 then
    local won = self.arena.win
    if not self.summary then self.summary = self:_computeSummary() end
    local s = self.summary
    Draw.begin(view)
    Draw.rect(0, Draw.H / 2 - 100, Draw.W, 200, { 0.02, 0.012, 0.03, 0.66 })
    Draw.textC(won and T("result.victory") or T("result.defeat"), Draw.W / 2, Draw.H / 2 - 80,
      won and c.gold or c.bloodBright, Theme.display(104))
    local y = Draw.H / 2 + 28
    if s.cause and s.n > 0 then
      Draw.textC(T(won and "combat.why.dealt" or "combat.why.slain",
          { cause = T("combat.cause." .. s.cause), n = s.n }),
        Draw.W / 2, y, won and c.gold or c.bloodBright, Theme.ui(15))
      y = y + 24
    end
    if s.firstLoss then
      Draw.textC(T("combat.why.first_loss", { name = T("unit." .. s.firstLoss.id .. ".name") }),
        Draw.W / 2, y, c.faint, Theme.ui(13))
    end
    Draw.textC(T("ui.hint_combat_end"), Draw.W / 2, Draw.H / 2 + 78, c.muted, Theme.ui(12))
    Draw.finish()
  end

  -- Indicateur de PAUSE : glyphe ❚❚ DESSINÉ (pas de texte -> aucune dépendance i18n), haut-centre, hors
  -- de la zone des grilles -> screenshot lisible. Le combat figé est déjà un retour clair en soi.
  if self.paused then
    Draw.begin(view)
    local bx, by = Draw.W / 2 - 5, 44
    love.graphics.setColor(c.inkBright[1], c.inkBright[2], c.inkBright[3], 0.92)
    love.graphics.rectangle("fill", bx, by, 4, 14)
    love.graphics.rectangle("fill", bx + 7, by, 4, 14)
    love.graphics.setColor(1, 1, 1, 1)
    Draw.finish()
  end
end

function Combat:keypressed(key)
  if key == "space" then self.paused = not self.paused; return end -- PAUSE / reprise (spectateur)
  if key == "r" then self:restart() end
end

function Combat:mousepressed(vx, vy, button)
  if button == 1 and self.arena.over then
    -- EXHIBITION (banc d'essai) : payload.onFinish prend la main -> retour au Proving Ground, SANS
    -- toucher la méta de run. Sinon route normale via le host (résout vies/victoires, round suivant ou
    -- fin de run). Fallback goto("build") pour les contextes sans run (tests).
    if self.payload.onFinish then self.payload.onFinish(self.arena.win, self.arena)
    elseif self.host.finishCombat then self.host.finishCombat(self.arena.win)
    else self.host.goto("build") end
  end
end

return Combat
