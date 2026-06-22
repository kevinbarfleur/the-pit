-- src/scenes/runover.lua
-- Écran de FIN DE RUN (DA) : affiché quand le run se conclut (10 victoires = ASCENSION, ou 0 vie =
-- THE PIT KEEPS YOU). Récapitule la run sur fond d'atmosphère, puis attend un clic / [r] pour relancer.
--
-- DA « nightmare forge » (kit src/ui/forge.lua) : le récap vit dans un PANNEAU forge (Forge.drawPanel :
-- matière + cadre laiton patiné + veines + œil qui guette) ; le VERDICT est une BANNIÈRE forge
-- (Forge.drawBanner, kind win/defeat) ; la relance est un BOUTON-ŒIL forge (Forge.uiButton tone='cta').
-- Le panneau + la bannière sont des rendus « buffer » (raw) -> bakés dans des widgets cachés sur la scène
-- (alloués UNE FOIS par taille, re-bakés chaque frame car ils RESPIRENT), à la manière de l'orbe de vie.
--
-- Couche scène (love.graphics) : atmosphère native en drawBack, panneau+bannière+texte en overlay design.
-- daChrome=true. Interface scène : update / drawBack / drawWorld / drawOverlay(view) / keypressed / mouse*.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Layout = require("src.ui.layout")
local Ambient = require("src.fx.ambient")
local Forge = require("src.ui.forge") -- KIT « nightmare forge » : panneau + bannière + bouton-œil CTA
local T = require("src.core.i18n").t

local Runover = {}
Runover.__index = Runover

-- Géométrie (espace design 1280×720). Panneau centré, bannière en tête de panneau, bouton-œil en pied.
local PANEL_W, PANEL_H = 560, 320
local BANNER_W, BANNER_H = 440, 56
local CTA_W, CTA_H = 300, 60

function Runover.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.runover",
    hintKey = "ui.hint_runover",
    result = payload.result or "lose", -- "win" | "lose"
    run = payload.run,
    mx = 0, my = 0,
    ambient = Ambient.new(21),
  }, Runover)

  -- Panneau centré ; sous-zones par Layout (bannière > récap > bouton) -> aucune poche vide.
  local px = math.floor((Draw.W - PANEL_W) / 2)
  local py = math.floor((Draw.H - PANEL_H) / 2)
  self.panel = { x = px, y = py, w = PANEL_W, h = PANEL_H }
  local inner = Layout.inset(self.panel, { l = 28, t = 26, r = 28, b = 28 })
  local rows = Layout.column(inner, {
    { size = BANNER_H }, -- 1 bannière (verdict)
    { flex = 1 },        -- 2 récap (score/progression)
    { size = CTA_H },    -- 3 bouton-œil de relance
  }, { gap = 16, align = "stretch" })
  self.rBanner, self.rRecap, self.rCta = rows[1], rows[2], rows[3]
  -- Bouton-œil centré dans sa rangée.
  self.cta = {
    x = math.floor(self.rCta.x + self.rCta.w / 2 - CTA_W / 2),
    y = self.rCta.y, w = CTA_W, h = CTA_H,
  }
  return self
end

local function ptIn(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Runover:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  Forge.uiTick(frameDt / 60) -- horloge des widgets forge (en SECONDES)
end

function Runover:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("runover")
  Draw.finish()
end

function Runover:drawWorld() end

function Runover:drawOverlay(view)
  local c = Theme.c
  local r = self.run
  local won = self.result == "win"
  local tt = self.t / 60

  Draw.begin(view)

  -- ── 1) PANNEAU forge (matière qui respire + cadre patiné + œil) : baké dans un widget caché, PX=2. ──
  do
    local px, P = 2, self.panel
    local aw, ah = math.floor(P.w / px), math.floor(P.h / px)
    if not self.panelWidget or self.panelAw ~= aw or self.panelAh ~= ah then
      self.panelWidget = Forge.newWidget(aw, ah)
      self.panelAw, self.panelAh = aw, ah
    end
    local img = Forge.render(self.panelWidget, function(b, W, H, t) Forge.drawPanel(b, W, H, t) end, tt)
    Forge.blit(img, P.x, P.y, px)
  end

  -- ── 2) BANNIÈRE forge (verdict) : Forge.drawBanner (kind win/defeat), bakée dans un widget caché. ──
  do
    local px = 2
    local bx = math.floor(self.rBanner.x + self.rBanner.w / 2 - BANNER_W / 2)
    local by = self.rBanner.y
    local aw, ah = math.floor(BANNER_W / px), math.floor(BANNER_H / px)
    if not self.bannerWidget then
      self.bannerWidget = Forge.newWidget(aw, ah)
      self.bannerAw, self.bannerAh = aw, ah
    end
    local word = T(won and "runover.win" or "runover.lose")
    local kind = won and "win" or "defeat"
    local img = Forge.render(self.bannerWidget, function(b, W, H, t) Forge.drawBanner(b, W, H, word, kind, t) end, tt)
    Forge.blit(img, bx, by, px)
  end

  -- ── 3) KICKER (sous la bannière) + RÉCAP de la run (lisible : Silkscreen), centrés dans la rangée. ──
  local rc = self.rRecap
  local cx = rc.x + rc.w / 2
  Draw.textC(T(won and "runover.kicker_win" or "runover.kicker_lose"), cx, rc.y + 6, c.faint, Theme.loreRoman(16))
  if r then
    Draw.textC(T("runover.score", { wins = r.wins, losses = r.losses }), cx, rc.y + 36, c.title, Theme.uiBold(14))
    Draw.textC(T("runover.progress", { rounds = r.round, level = r.level }), cx, rc.y + 60, c.faint, Theme.ui(12))
  end

  -- ── 4) BOUTON-ŒIL de relance (tone='cta', regard depuis la souris). ──
  Forge.uiButton("runover.again", self.cta.x, self.cta.y, self.cta.w, self.cta.h, T("runover.descend"),
    { tone = "cta", hover = self.ctaHover, active = self.ctaDown,
      mouse = { mx = self.mx, my = self.my }, fontSz = 9, eyeR = 7, t = tt })

  Draw.finish()
end

function Runover:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.ctaHover = ptIn(dx, dy, self.cta)
end

function Runover:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx * 4, vy * 4
  self.ctaDown = true
  self.host.newRun()
end

function Runover:mousereleased() self.ctaDown = false end

function Runover:keypressed(key)
  if key == "r" then self.host.newRun() end
end

return Runover
