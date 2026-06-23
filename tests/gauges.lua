-- tests/gauges.lua
-- ATOMES DE JEU (design-system-spec.md §IV) : BADGES (§2.6) + JAUGES (§2.8) + DIVIDERS (§2.9) + CASES (§2.10).
-- Couche RENDER -> tournée sous le mock LÖVE (love.graphics/love.image stubés) : on vérifie que CHAQUE fonction
-- s'exécute sans crash (smoke), et que les retours sont SAINS (largeurs/hauteurs > 0, bornes respectées).
-- RENDER pur -> golden neutre. Calque tests/reliquary.lua.
--   Lancement : luajit tests/gauges.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love") -- SET le global love (les atomes dessinent via love.graphics)

local Theme = require("src.ui.theme")
local Badge = require("src.ui.badge")
local Dividers = require("src.ui.dividers")
local Gauge = require("src.ui.gauge")
local Slot = require("src.ui.slot")

local font = love.graphics.getFont()

local ok, err = pcall(function()
  -- ═══════════════════════ BADGES (§2.6) ═══════════════════════
  -- cost : largeur > 0 ; abordable ET trop cher (couleurs/icône distinctes, mais on teste l'absence de crash).
  local wc = Badge.cost(10, 10, 4, true)
  assert(wc and wc > 0, "Badge.cost : largeur positive")
  assert(Badge.cost(10, 30, 12, false) > 0, "Badge.cost : variante trop cher")
  assert(Badge.cost(10, 50, 0, nil) > 0, "Badge.cost : valeur 0 + affordable nil (defaut true)")

  -- levelPips : largeur = max * pas ; n borné à [0,max].
  local wl = Badge.levelPips(10, 70, 2, 3)
  assert(wl == 3 * 9, "Badge.levelPips : largeur = max(3) * pas(9)")
  assert(Badge.levelPips(10, 90, 0, 3) == 27, "Badge.levelPips : n=0 (tous vides)")
  assert(Badge.levelPips(10, 110, 9, 3) == 27, "Badge.levelPips : n>max -> clampe (3 pleins)")

  -- rarity : hauteur dessinée > 0 ; rang 0..max.
  local hr = Badge.rarity(10, 130, 120, 3, 5)
  assert(hr and hr > 12, "Badge.rarity : hauteur = barre + pips (> hauteur de barre seule)")
  assert(Badge.rarity(10, 170, 120, 0, 5) == 12, "Badge.rarity : rang 0 -> pas de pips (hauteur barre)")
  Badge.rarity(10, 200, 100, 7, 5) -- rang > max -> clampe, no crash

  -- diamond exposé (primitive partagée) : ne crashe pas.
  Badge.diamond(40, 240, 4, Theme.c.gold, Theme.c.brass, Theme.c.brassS)

  -- ═══════════════════════ DIVIDERS (§2.9) ═══════════════════════
  assert(Dividers.brass(640, 300, 200) == 300, "Dividers.brass : renvoie y (chainage)")
  Dividers.brass(640, 320, 80, 8) -- gap explicite
  local hb = Dividers.blood(540, 340, 200)
  assert(hb == 4, "Dividers.blood : hauteur 4 (ourlet+sang+ourlet)")
  local ht = Dividers.text(640, 360, 240, "KNOWN EFFECT")
  assert(ht and ht > 0, "Dividers.text : hauteur du label > 0")
  Dividers.text(640, 390, 240, "THE OFFERING", 4) -- interlettrage explicite
  -- libellé avec caractère multi-octets (UTF-8) : pas de découpe par octet, pas de crash.
  Dividers.text(640, 420, 240, "ÉCHO · RUNE")

  -- ═══════════════════════ JAUGES (§2.8) ═══════════════════════
  -- health : segments DoT + bouclier + numérique ; renvoie h. Couvre les bornes (cur>max, cur=0, max=0).
  local segs = { { frac = 0.2, key = "bleed" }, { frac = 0.12, key = "poison" }, { frac = 0.08, key = "burn" } }
  assert(Gauge.health(100, 100, 200, 14, 60, 100, { segs = segs, shield = 25 }) == 14, "Gauge.health : renvoie h")
  Gauge.health(100, 130, 200, 14, 100, 100, {})                       -- pleine vie, sans segs/shield
  Gauge.health(100, 150, 200, 14, 0, 100, { segs = segs })           -- vide (front a 0)
  Gauge.health(100, 170, 200, 14, 150, 100, { shield = 40 })         -- cur>max -> clampe a 1
  Gauge.health(100, 190, 200, 14, 50, 0, {})                         -- max=0 -> pas de division par zero
  Gauge.health(100, 210, 200, 14, 50, 100, { segs = segs, showText = false }) -- sans numerique
  Gauge.health(100, 230, 4, 4, 2, 4, { segs = segs })                -- minuscule (iw/ih ~ 0) : borne, no crash
  -- segment a cle d'affliction INCONNUE -> repli couleur (defensif).
  Gauge.health(100, 250, 200, 14, 70, 100, { segs = { { frac = 0.3, key = "pas_une_affl" } } })

  -- cooldown : charge + pret ; renvoie h.
  assert(Gauge.cooldown(100, 280, 120, 8, 0.5, false) == 8, "Gauge.cooldown : renvoie h (en charge)")
  Gauge.cooldown(100, 300, 120, 8, 1.0, true)   -- pret (full + lueur)
  Gauge.cooldown(100, 320, 120, 8, -0.3, false) -- pct negatif -> clampe a 0
  Gauge.cooldown(100, 340, 2, 2, 0.5, false)    -- minuscule : borne

  -- lives : largeur > 0 ; n borné.
  local wlives = Gauge.lives(100, 360, 3, 5)
  assert(wlives and wlives > 0, "Gauge.lives : largeur positive")
  Gauge.lives(100, 380, 0, 5)  -- toutes vides
  Gauge.lives(100, 400, 9, 5)  -- n>max -> clampe (5 pleins)
  Gauge.lives(100, 420, 2, 3, 3, 6) -- scale/gap explicites

  -- descent : 10 segments ; renvoie h ; wins borné.
  assert(Gauge.descent(100, 440, 300, 8, 7, 10) == 8, "Gauge.descent : renvoie h")
  Gauge.descent(100, 460, 300, 8, 0, 10)   -- aucun gagne
  Gauge.descent(100, 480, 300, 8, 12, 10)  -- wins>total -> clampe (tous gagnes)
  Gauge.descent(100, 500, 300, 8, 5, 10, 4) -- gap explicite

  -- ═══════════════════════ CASES (§2.10) ═══════════════════════
  -- les 6 etats se dessinent sans crash, et draw renvoie la taille.
  for _, st in ipairs({ "empty", "selected", "neighbor", "drop", "locked", "hover" }) do
    local sz = Slot.draw(100, 100, 54, st)
    assert(sz == 54, "Slot.draw : renvoie size (" .. st .. ")")
  end
  -- etat inconnu -> repli "empty" (defensif).
  assert(Slot.draw(100, 200, 54, "etat_bidon") == 54, "Slot.draw : etat inconnu -> empty (no crash)")
  -- opts complets : pip de type + pips de niveau + marques d'affliction.
  Slot.draw(160, 100, 54, "selected", { typePip = "arcane", level = 3, affkeys = { "burn", "poison" } })
  Slot.draw(220, 100, 54, "neighbor", { typePip = "flesh", level = 1, affkeys = { "bleed" } })
  Slot.draw(280, 100, 54, "drop", { typePip = "bone" }) -- pip sans niveau ni affliction
  Slot.draw(340, 100, 54, "occupied") -- alias non listé -> repli empty (defensif), no crash
  -- pip de chaque famille (couvre les 5 formes de Draw.pip).
  for _, fam in ipairs({ "flesh", "order", "bone", "arcane", "abyss" }) do
    Slot.draw(100, 300, 54, "selected", { typePip = fam })
  end
  -- arete de synergie : active + inactive, renvoie true.
  assert(Slot.edge(100, 100, 154, 100, true), "Slot.edge : active renvoie true")
  Slot.edge(100, 100, 100, 154, false)        -- inactive (filet sourd)
  Slot.edge(100, 100, 154, 154, true, 4)      -- epaisseur explicite
end)

if ok then
  print("=> GAUGES OK : Badge (§2.6) + Gauge (§2.8) + Dividers (§2.9) + Slot (§2.10) — smoke headless + bornes.")
else
  print("=> GAUGES FAIL :")
  print(err)
  os.exit(1)
end
