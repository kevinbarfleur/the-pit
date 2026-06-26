-- feel-lab/lib/shell.lua
-- LE SHELL / CHROME PERSISTANT — la clé du « on est dans UN seul jeu » (recherche §5). Une couche dessinée
-- AUTOUR de la scène changeante : même fond, même barre de titre (fil d'Ariane), même bouton-retour, même
-- pied. Les scènes ne dessinent que LEUR contenu ; le shell, lui, ne bouge jamais -> continuité instantanée.
-- RENDER pur (Draw/Theme/Feel), headless-safe.
--
-- API :
--   Shell.drawBack(view)                 -- fond d'ambiance (derrière la scène)
--   Shell.drawFront(view, ctx) -> back   -- barre haute (titre + retour) + pied ; renvoie le rect du retour
--                                           ctx = { title, sub, canBack, mx, my, status = {...} }
--   Shell.backHit(back, mx, my)          -- hit-test du bouton retour

local Draw  = require("lib.draw")
local Theme = require("lib.theme")
local Feel  = require("lib.feel")

local Shell = {}
local W, H = 1280, 720
local BAR_H = 64          -- hauteur de la barre de titre
local FOOT_H = 34         -- pied (hints)

-- fond : dégradé pierre du puits (void en bas, stone900 en haut) + une braise basse discrète
function Shell.drawBack(view)
  Draw.begin(view)
  local c = Theme.c
  local n = 48
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local top, bot = c.stone900, c.void
    local r = top[1] + (bot[1] - top[1]) * t
    local g = top[2] + (bot[2] - top[2]) * t
    local b = top[3] + (bot[3] - top[3]) * t
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 0, H * t / 1, W, H / n + 1)
  end
  -- braise basse (la « bouche » du puits)
  love.graphics.setColor(c.bgEmber[1], c.bgEmber[2], c.bgEmber[3], 0.5)
  love.graphics.rectangle("fill", 0, H - 120, W, 120)
  Draw.reset()
  Draw.finish()
end

-- barre de titre + retour + pied. Renvoie le rect du bouton retour (design) ou nil.
function Shell.drawFront(view, ctx)
  ctx = ctx or {}
  Draw.begin(view)
  local c = Theme.c
  local back

  -- ── barre haute ──────────────────────────────────────────────────────────────────────────────────────
  Draw.rect(0, 0, W, BAR_H, c.stone850)
  Draw.divider(W / 2, BAR_H - 1, W * 0.96, c.brass, 0.7)

  -- wordmark (cérémonial Jacquard) + fil d'Ariane (Cinzel)
  local wx = 28
  if ctx.canBack then
    -- bouton retour « ‹ » avec juice (Feel id stable)
    back = { x = 18, y = 14, w = 36, h = 36 }
    local over = ctx.mx and Shell.backHit(back, ctx.mx, ctx.my)
    Feel.hover("shell_back", over and true or false)
    local s = Feel.state("shell_back")
    local lift = s.lift or 0
    Draw.rrect(back.x, back.y - lift, back.w, back.h, 6,
      over and c.stone700 or c.stone800, over and c.brassL or c.brass, 2)
    Draw.textC("‹", back.x + back.w / 2, back.y - lift + 4, over and c.ink or c.ink2, Theme.title(26))
    wx = back.x + back.w + 18
  end

  Draw.textTrackedL("THE PIT", wx, 14, c.ink, Theme.display(26), 1)
  local px = wx + Draw.textWidth("THE PIT", Theme.display(26)) + 14
  Draw.text("·", px, 20, c.ink4, Theme.title(20)); px = px + 16
  Draw.textTrackedL((ctx.title or "FEEL LAB"):upper(), px, 22, c.gold, Theme.title(18), 2)
  if ctx.sub then
    Draw.text(ctx.sub, px, 44, c.ink3, Theme.body(13))
  end

  -- ── statut à droite (chips : SFX / FEEL / FPS) ──────────────────────────────────────────────────────
  local st = ctx.status or {}
  local rx = W - 24
  local function chip(label, val, col)
    local lw = Draw.textWidth(val, Theme.label(13))
    Draw.textR(val, rx, 16, col or c.ink2, Theme.label(13))
    Draw.textR(label, rx, 36, c.ink4, Theme.label(10))
    rx = rx - math.max(lw, Draw.textWidth(label, Theme.label(10))) - 22
  end
  if st.fps then chip("FPS", tostring(st.fps), c.ink3) end
  if st.profile ~= nil then chip("FEEL", string.format("%d%%", math.floor(st.profile * 100 + 0.5)), c.gold) end
  if st.sfx ~= nil then chip("SOUND", st.sfx and "ON" or "OFF", st.sfx and c.regen or c.ink4) end
  if st.fx ~= nil then chip("SHADER", st.fx and "ON" or "OFF", st.fx and c.regen or c.ink4) end

  -- ── pied (hints) ─────────────────────────────────────────────────────────────────────────────────────
  Draw.rect(0, H - FOOT_H, W, FOOT_H, c.stone850)
  Draw.divider(W / 2, H - FOOT_H, W * 0.96, c.brass, 0.5)
  if ctx.hint then
    Draw.textC(ctx.hint, W / 2, H - FOOT_H + 9, c.ink4, Theme.label(12))
  end

  Draw.reset()
  Draw.finish()
  return back
end

function Shell.backHit(back, mx, my)
  if not back then return false end
  return mx >= back.x and mx <= back.x + back.w and my >= back.y and my <= back.y + back.h
end

Shell.BAR_H, Shell.FOOT_H, Shell.W, Shell.H = BAR_H, FOOT_H, W, H
return Shell
