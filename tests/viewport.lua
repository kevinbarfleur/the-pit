package.path = "./?.lua;./?/init.lua;" .. package.path

local Viewport = require("src.ui.viewport")

local VW, VH = 320, 180

local function near(a, b, eps)
  eps = eps or 0.0001
  return math.abs(a - b) <= eps
end

local function assertCover(v, label)
  assert(v.bleed.ox <= 0, label .. ": bleed ne couvre pas le bord gauche")
  assert(v.bleed.oy <= 0, label .. ": bleed ne couvre pas le bord haut")
  assert(v.bleed.ox + v.bleed.safeW >= v.screenW, label .. ": bleed ne couvre pas le bord droit")
  assert(v.bleed.oy + v.bleed.safeH >= v.screenH, label .. ": bleed ne couvre pas le bord bas")
end

do
  local v = Viewport.update({}, VW, VH, 1280, 720)
  assert(v.scale == 4, "16:9: scale attendu x4")
  assert(v.ox == 0 and v.oy == 0, "16:9: pas de marge")
  assert(not v.hasBleed, "16:9: aucun bleed necessaire")
  assert(v.layout == "standard", "16:9: layout standard")
  assertCover(v, "16:9")
end

do
  local v = Viewport.update({}, VW, VH, 1440, 900)
  assert(near(v.scale, 4.5), "16:10: contain attendu x4.5")
  assert(v.oy == 45 and v.extra.t == 45 and v.extra.b == 45, "16:10: marges verticales attendues")
  assert(v.hasBleed, "16:10: bleed necessaire")
  assert(near(v.bleed.scale, 5), "16:10: cover attendu x5")
  assertCover(v, "16:10")
end

do
  local v = Viewport.update({}, VW, VH, 1024, 768)
  assert(near(v.scale, 3.2), "4:3: contain attendu x3.2")
  assert(v.oy == 96 and v.extra.t == 96 and v.extra.b == 96, "4:3: marges verticales attendues")
  assert(v.layout == "tall", "4:3: layout tall")
  assertCover(v, "4:3")
end

do
  local v = Viewport.update({}, VW, VH, 3440, 1440)
  assert(v.scale == 8, "ultrawide: contain attendu x8")
  assert(v.ox == 440 and v.extra.l == 440 and v.extra.r == 440, "ultrawide: marges laterales attendues")
  assert(v.layout == "wide", "ultrawide: layout wide")
  assert(near(v.bleed.scale, 10.75), "ultrawide: cover attendu x10.75")
  assertCover(v, "ultrawide")
end

print("=> VIEWPORT OK : safe-area 16:9 + fond cover responsive.")
