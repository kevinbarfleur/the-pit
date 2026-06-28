-- feel-lab/rooms/menu.lua
-- Accueil du Feel Lab actuel. La surface active ne liste que les ateliers
-- alignes avec les composants Build/Grimoire, sans anciens prototypes visibles.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")
local Feel = require("lib.feel")

local Menu = {}
Menu.__index = Menu

local C = Theme.c
local W, H = 1280, 720

local PRIMARY = {
  key = "contract",
  title = "FEEDBACK CONTRACT",
  label = "OPEN CONTRACT",
  body = "La reference: chaque action doit avoir un mouvement, un son, un delai et un payoff lisibles.",
}

local ATELIERS = {
  {
    key = "components",
    title = "REAL COMPONENTS",
    label = "COMPONENTS",
    body = "Boutons, slots et drag/drop du style actuel.",
  },
  {
    key = "impact",
    title = "COMBAT IMPACT",
    label = "IMPACT",
    body = "Coups, chiffres, hitstop et particules.",
  },
  {
    key = "flow",
    title = "UX BEATS",
    label = "UX BEATS",
    body = "Transitions, scoring, recompenses et sous-menus.",
  },
  {
    key = "particles",
    title = "PARTICLE FORGE",
    label = "PARTICLES",
    body = "Explosions, sceaux et bursts de validation.",
  },
  {
    key = "levelup",
    title = "LEVEL-UP / FUSION",
    label = "FUSION",
    body = "Merge, aspiration, climax et cascade.",
  },
  {
    key = "sound",
    title = "SFX VOCABULARY",
    label = "SFX",
    body = "Cues sonores par action, Oneiric par defaut.",
  },
}

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function primaryRect()
  return { x = 72, y = 154, w = 520, h = 184 }
end

local function ruleRect()
  return { x = 640, y = 154, w = 568, h = 184 }
end

local function atelierRect(i)
  local w, h, gapX, gapY = 352, 112, 24, 22
  local col = (i - 1) % 3
  local row = math.floor((i - 1) / 3)
  return { x = 72 + col * (w + gapX), y = 392 + row * (h + gapY), w = w, h = h }
end

function Menu.new(app)
  Theme.load()
  return setmetatable({ app = app, mx = -1, my = -1, t = 0 }, Menu)
end

function Menu:enter()
  self.title = "Feel Lab"
end

function Menu:update(dt)
  self.t = self.t + (dt or 0)
  Feel.hover("menu.contract", ptIn(self.mx, self.my, primaryRect()))
  for i, it in ipairs(ATELIERS) do
    Feel.hover("menu." .. it.key, ptIn(self.mx, self.my, atelierRect(i)))
  end
end

function Menu:drawPrimary()
  local r = primaryRect()
  local hot = ptIn(self.mx, self.my, r)
  Panel.draw(r.x, r.y, r.w, r.h, { accent = hot and C.gold or nil })
  Draw.textTrackedL("PRIMARY BENCH", r.x + 24, r.y + 22, C.gold, Theme.label(10), 1.6)
  Draw.textTrackedL(PRIMARY.title, r.x + 24, r.y + 48, C.ink, Theme.subhead(20), 1.8)
  Draw.textWrap(PRIMARY.body, r.x + 24, r.y + 82, r.w - 48, C.ink3, Theme.body(14))
  Button.draw(r.x + 24, r.y + r.h - 58, 214, 42, "primary", PRIMARY.label, {
    hover = hot, feel = Feel.state("menu.contract"), id = "menu.contract",
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
  Draw.text("chaque atelier doit prouver ce contrat", r.x + 256, r.y + r.h - 45, C.ink5, Theme.flavor(13))
end

function Menu:drawRule()
  local r = ruleRect()
  Panel.draw(r.x, r.y, r.w, r.h)
  Draw.textTrackedL("QUALITY GATE", r.x + 24, r.y + 22, C.gold, Theme.label(10), 1.6)
  Draw.textTrackedL("NO ORPHAN EFFECTS", r.x + 24, r.y + 48, C.ink, Theme.subhead(20), 1.8)
  Draw.textWrap("Un effet valide ici doit etre beau dans une capture statique, clair pendant le mouvement, et compatible avec Build/Grimoire sans nouveau langage visuel.",
    r.x + 24, r.y + 82, r.w - 48, C.ink3, Theme.body(14))

  local tags = {
    { "layout", "grid first" },
    { "visual", "current UI" },
    { "sound", "named cue" },
    { "timing", "measured" },
  }
  for i, t in ipairs(tags) do
    local x = r.x + 24 + (i - 1) * 130
    Draw.textTrackedL(t[1]:upper(), x, r.y + 132, C.ink5, Theme.label(9), 1)
    Draw.textTrackedL(t[2]:upper(), x, r.y + 148, C.gold, Theme.label(11), 1.1)
  end
end

function Menu:drawAtelier(i, it)
  local r = atelierRect(i)
  local id = "menu." .. it.key
  local hot = ptIn(self.mx, self.my, r)
  Panel.draw(r.x, r.y, r.w, r.h, { accent = hot and C.brass or nil })
  Draw.textTrackedL(string.format("0%d", i), r.x + 18, r.y + 16, hot and C.gold or C.ink5, Theme.label(9), 1.2)
  Draw.textTrackedL(it.title, r.x + 58, r.y + 16, C.ink, Theme.subhead(14), 1.2)
  Draw.textWrap(it.body, r.x + 18, r.y + 44, r.w - 36, C.ink4, Theme.body(12))
  Button.draw(r.x + 18, r.y + r.h - 42, r.w - 36, 32, "secondary", it.label, {
    hover = hot, feel = Feel.state(id), id = id,
    mouse = { mx = self.mx, my = self.my }, t = self.t,
  })
end

function Menu:draw(view)
  Draw.begin(view)
  Draw.textTrackedL("FEEL LAB", 72, 86, C.ink, Theme.title(28), 2.5)
  Draw.text("Banc d'essai propre pour monter le feeling de The Pit sans casser le jeu principal.",
    72, 126, C.ink4, Theme.body(14))
  Draw.textR("shader OFF pour juger la structure · F9 pour l'ambiance finale", W - 72, 126, C.ink5, Theme.body(13))

  self:drawPrimary()
  self:drawRule()
  Draw.textTrackedL("ACTIVE ATELIERS", 72, 366, C.gold, Theme.subhead(13), 1.8)
  for i, it in ipairs(ATELIERS) do self:drawAtelier(i, it) end

  Draw.text("Surface active stricte: chaque page doit etre propre en capture avant d'entrer dans le jeu principal.",
    72, H - 58, C.ink5, Theme.flavor(13))
  Draw.finish()
end

function Menu:mousemoved(mx, my)
  self.mx, self.my = mx, my
end

function Menu:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  if ptIn(mx, my, primaryRect()) then
    Feel.press("menu.contract", function() self.app:go("contract", "slide_left") end, { delay = Feel.CTA_DELAY })
    return
  end
  for i, it in ipairs(ATELIERS) do
    if ptIn(mx, my, atelierRect(i)) then
      Feel.press("menu." .. it.key, function() self.app:go(it.key, "slide_left") end, { delay = 0.14 })
      return
    end
  end
end

return Menu
