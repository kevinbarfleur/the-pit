-- src/scenes/runover.lua
-- Écran de FIN DE RUN (DA PROPRE, kit .dc.html) : affiché quand le run se conclut (10 victoires = ASCENSION,
-- ou 0 vie = THE PIT KEEPS YOU). Le VERDICT cérémonial + le récap de la run vivent dans une BANNIÈRE
-- (src/ui/banner.lua, kind ascension/defeat = la SEULE voix Jacquard), puis un BOUTON PRIMARY relance le Puits.
--
-- DA « reliquary » (kit Panel/Banner/Button/Dividers/Feel + Theme/Draw) — plus de Forge/Frame gritty :
--   • La BANNIÈRE est le centre cérémonial : mot du destin (Jacquard) + kicker (subtitle) + score (wins/losses)
--     + progression (hint). Halo doré/braise pour l'ascension, halo sang pour la chute. Filets gravés (Dividers).
--   • Sous la bannière, un filet laiton (Dividers.brass) puis le CTA PRIMARY « DESCEND AGAIN » (sang + yeux),
--     avec le JUICE propre (Feel : lift/glow au survol, squash/flash au press). Structure = menu (verdict + CTA).
-- Couleurs/polices via Theme UNIQUEMENT ; tout le texte est NET (Draw + rôles de police), composé en ESPACE
-- DESIGN 1280×720 (= virtuel ×4) ; mesure/wrap maîtrisés (la bannière borne sa largeur au contenu).
--
-- CLIQUABILITÉ + CONTRAT : on PRÉSERVE l'interface scène (update/drawBack/drawWorld/drawOverlay/keypressed/
-- mouse*) et le routing de relance (host.newRun). La souris arrive en VIRTUEL (320×180) -> repassée en DESIGN
-- (×4) pour le hit-test. Le test (tests/ui.lua) lit self.panel + self.cta et asserte que le clic relance
-- IMMÉDIATEMENT -> on joue le feedback de press (Feel.press SANS action) PUIS on appelle host.newRun() tout de
-- suite (aucune action différée), comme le bouton COMBAT du build. daChrome=true.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Banner = require("src.ui.banner")   -- VERDICT cérémonial (Jacquard) : le centre de l'écran
local Button = require("src.ui.button")   -- CTA propre PRIMARY (sang + yeux) : la relance
local Dividers = require("src.ui.dividers") -- filet laiton propre entre verdict et CTA
local Feel = require("src.ui.feel")       -- JUICE propre (survol/press) — RENDER pur, headless-safe
local Ambient = require("src.fx.ambient")
local T = require("src.core.i18n").t

local Runover = {}
Runover.__index = Runover

-- Géométrie (espace design 1280×720). Bloc « verdict + CTA » centré : la BANNIÈRE (large, bornée au contenu)
-- au-dessus, un filet laiton, puis le CTA. self.panel = l'enveloppe (compat test + ancrage) ; self.cta = le rect.
local BANNER_W, BANNER_H = 760, 196 -- large : le mot long « THE PIT KEEPS YOU » (Jacquard) respire sans déborder
local DIV_GAP = 30                  -- air entre la bannière et le filet/CTA (respiration des séparateurs)
local CTA_W, CTA_H = 320, 60

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Runover.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.runover",
    hintKey = "ui.hint_runover",
    result = payload.result or "lose", -- "win" | "lose"
    run = payload.run,
    mx = -100, my = -100,
    ambient = Ambient.new(21),
  }, Runover)

  -- Bloc vertical centré : bannière (haut) + filet + CTA (bas). On calcule la hauteur totale puis on centre.
  local cx = math.floor(Draw.W / 2)
  local bannerH = BANNER_H
  local totalH = bannerH + DIV_GAP + CTA_H
  local top = math.floor((Draw.H - totalH) / 2)
  self.bx = math.floor(cx - BANNER_W / 2)
  self.by = top
  self.divY = top + bannerH + math.floor(DIV_GAP / 2)
  self.cta = {
    x = math.floor(cx - CTA_W / 2),
    y = top + bannerH + DIV_GAP,
    w = CTA_W, h = CTA_H,
  }
  -- Enveloppe (compat : le test lit self.panel) : l'aire englobant le bloc verdict+CTA. Pas un cadre dessiné
  -- (le verdict est porté par la BANNIÈRE), juste un repère d'ancrage/hit-test.
  self.panel = { x = self.bx, y = self.by, w = BANNER_W, h = totalH }
  Feel.reset() -- repart au repos en entrant (survol/press vierges)
  return self
end

function Runover:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  Feel.update(frameDt) -- avance le JUICE du CTA (survol/press) ; aucune action différée en file ici
  Feel.hover("runover.again", ptIn(self.mx, self.my, self.cta))
end

function Runover:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("runover")
  Draw.finish()
end

function Runover:drawWorld() end

function Runover:drawOverlay(view)
  local r = self.run
  local won = self.result == "win"
  local tt = self.t / 60 -- horloge en SECONDES (pulse de la bannière + yeux du CTA)

  Draw.begin(view)

  -- ── 1) VERDICT cérémonial : BANNIÈRE (kind ascension/defeat). Le récap de run est porté par la bannière
  --       elle-même (subtitle = kicker, score = wins/losses, hint = progression) -> un seul centre lisible. ──
  local kind = won and "ascension" or "defeat"
  local word = T(won and "runover.win" or "runover.lose")
  local subtitle = T(won and "runover.kicker_win" or "runover.kicker_lose")
  local score = r and T("runover.score", { wins = r.wins, losses = r.losses }) or nil
  local hint = r and T("runover.progress", { rounds = r.round, level = r.shopTier }) or nil -- shopTier = niveau de progression (le RunState n'a pas de .level)
  Banner.draw(self.bx, self.by, BANNER_W, kind, word,
    { subtitle = subtitle, score = score, hint = hint, t = tt, h = BANNER_H })

  -- ── 2) Filet laiton propre (Dividers.brass) entre le verdict et l'appel à redescendre. ──
  Dividers.brass(math.floor(Draw.W / 2), self.divY, 280)

  -- ── 3) CTA PRIMARY « DESCEND AGAIN » (sang + yeux) avec le JUICE propre (survol/press). ──
  Button.draw(self.cta.x, self.cta.y, self.cta.w, self.cta.h, "primary", T("runover.descend"),
    { hover = self.ctaHover, feel = Feel.state("runover.again"), id = "runover.again",
      mouse = { mx = self.mx, my = self.my }, t = tt })

  Draw.finish()
end

function Runover:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.ctaHover = ptIn(dx, dy, self.cta)
  Feel.hover("runover.again", self.ctaHover)
end

-- ⭐ Pointer-DOWN sur le CTA : ACTION DIFFÉRÉE (Feel, bible §4) -> press visible (squash + flash + braise)
-- AVANT la relance (~160 ms), pour qu'on SENTE le clic avant que l'écran change. Le verrou de Feel évite le
-- double-fire. Le test mûrit l'action via Runover:update (-> Feel.update) avant d'asserter la relance.
function Runover:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if ptIn(dx, dy, self.cta) then
    Feel.press("runover.again", function() self.host.newRun() end)
  end
end

function Runover:mousereleased() end

function Runover:keypressed(key)
  if key == "r" then Feel.press("runover.again"); self.host.newRun() end
end

return Runover
