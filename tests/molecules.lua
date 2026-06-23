-- tests/molecules.lua
-- LES TROIS MOLÉCULES du design system (§V) : carte de relique (§2.13), bandeau de destin (§2.19),
-- infobulle (§2.14). Smoke HEADLESS sous le mock LÖVE : chaque module se require, chaque fonction se dessine
-- dans TOUTES ses variantes d'état SANS crash (bake Forge no-op gracieux), avec des assertions saines sur les
-- contrats de retour. RENDER pur -> golden neutre (on ne touche aucune couche SIM). Calqué sur reliquary.lua.

love = require("tests.mock_love") -- SET le global love (les bakes Forge utilisent love.image / love.graphics)

local RelicCard = require("src.ui.relic_card")
local Banner = require("src.ui.banner")
local Tooltip = require("src.ui.tooltip")
local Forge = require("src.ui.forge")

local function count(tbl)
  local n = 0
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

-- ════════════════════════════ 1) RELIC CARD (§2.13) ════════════════════════════
-- Les TROIS états (identified / cryptic / selected) se dessinent sans crash et retournent une zone intérieure
-- strictement positive et bornée par la carte.
do
  local ok, err = pcall(function()
    local ix, iy, iw, ih = RelicCard.draw(40, 40, 248, 180, {
      state = "identified", name = "Bloodstone", fam = "flesh", status = "INKED",
      effect = "Your units strike for +15% more.", flavor = "It drinks first.",
      t = 0.5, mouse = { mx = 90, my = 80 },
    })
    assert(type(ix) == "number" and type(iw) == "number", "draw retourne (ix,iy,iw,ih)")
    assert(ix > 40 and iy > 40, "zone intérieure strictement dans la carte (sous le biseau)")
    assert(iw > 0 and ih > 0 and iw < 248 and ih < 180, "zone intérieure bornée et positive")
  end)
  assert(ok, "RelicCard.draw (identified) ne doit pas crasher : " .. tostring(err))

  ok, err = pcall(function()
    RelicCard.draw(300, 40, 248, 180, {
      state = "cryptic", name = "Hidden Thing", fam = "arcane", affKey = "rot",
      effect = "Its purpose hides beneath the surface.", flavor = "?", t = 1.2,
    })
  end)
  assert(ok, "RelicCard.draw (cryptic) ne doit pas crasher : " .. tostring(err))

  ok, err = pcall(function()
    -- selected = identifiée + lueur élevée : la zone intérieure est PLUS petite (biseau gildé +1).
    local _, _, iwSel = RelicCard.draw(560, 40, 212, 200, {
      state = "selected", name = "The Kings' Bowl", fam = "abyss", affKey = "poison",
      effect = "Poison deals 20% more damage.", flavor = "A bowl of endless hunger.",
      t = 2.0, mouse = { mx = 620, my = 120 },
    })
    assert(type(iwSel) == "number", "selected retourne aussi une zone intérieure")
  end)
  assert(ok, "RelicCard.draw (selected) ne doit pas crasher : " .. tostring(err))

  -- effet vide / champs minimaux : pas de crash (overlays robustes aux nil).
  ok, err = pcall(function()
    RelicCard.draw(0, 0, 200, 160, { state = "identified", name = "Bare", fam = "bone" })
  end)
  assert(ok, "RelicCard.draw (champs minimaux) ne doit pas crasher : " .. tostring(err))

  -- mémoïsation : un 2e draw à même id NE crée PAS d'entrée de cache supplémentaire.
  local before = count(RelicCard._cache)
  RelicCard.draw(40, 40, 248, 180, { id = "rc:test", state = "identified", name = "A", fam = "flesh" })
  local mid = count(RelicCard._cache)
  RelicCard.draw(40, 40, 248, 180, { id = "rc:test", state = "identified", name = "A", fam = "flesh" })
  assert(count(RelicCard._cache) == mid, "même id -> pas de nouvelle entrée de cache (mémoïsé)")
  assert(mid > before, "un nouvel id crée bien une entrée")
end

-- ════════════════════════════ 2) BANNER (§2.19) ════════════════════════════
-- VICTORY / DEFEAT / ASCENSION se dessinent sans crash et retournent un centre (cx,cy) cohérent.
do
  for _, kind in ipairs({ "victory", "defeat", "ascension" }) do
    local ok, err = pcall(function()
      local cx, cy = Banner.draw(200, 220, 880, kind, kind:upper(), {
        subtitle = "THE PIT YIELDS", score = "5 wins / 1 loss", hint = "[SPACE] CONTINUE", t = 0.4,
      })
      assert(type(cx) == "number" and type(cy) == "number", "draw retourne (cx,cy)")
      assert(cx > 200 and cx < 200 + 880, "centre x dans le bandeau")
      assert(cy > 220, "centre y sous le coin haut")
    end)
    assert(ok, "Banner.draw (" .. kind .. ") ne doit pas crasher : " .. tostring(err))
  end

  -- arguments minimaux (kind/word seulement) : pas de crash.
  local ok, err = pcall(function() Banner.draw(0, 0, 640, "victory", "WIN") end)
  assert(ok, "Banner.draw (minimal) ne doit pas crasher : " .. tostring(err))

  -- kind inconnu -> retombe sur victory (pas de crash, pas de nil).
  ok, err = pcall(function() Banner.draw(0, 0, 640, "weird", "???", { t = 1 }) end)
  assert(ok, "Banner.draw (kind inconnu) doit retomber sur victory sans crash : " .. tostring(err))
end

-- ════════════════════════════ 3) TOOLTIP (§2.14) ════════════════════════════
-- Panneau complet (nom + chip + stats + passif + chip affliction + prose) et variantes ; la HAUTEUR retournée
-- doit GRANDIR avec le contenu (mesure avant bake), et le rect rester cohérent.
do
  local ok, err = pcall(function()
    local x, y, w, h = Tooltip.draw(400, 200, {
      name = "Ash-Maw", fam = "flesh",
      stats = { { label = "HP", value = 70 }, { label = "DMG", value = 6 }, { label = "CD", value = "6s" } },
      passive = "IGNITION", affKey = "burn",
      prose = "Each hit ignites the struck foe, stacking burn over time.", t = 0.5,
    })
    assert(x == 400 and y == 200, "draw retourne le coin fourni")
    assert(type(w) == "number" and type(h) == "number" and w > 0 and h > 0, "rect réel positif")
    return h
  end)
  assert(ok, "Tooltip.draw (complet) ne doit pas crasher : " .. tostring(err))

  -- la hauteur d'un tooltip RICHE > celle d'un tooltip nu (la mesure suit le contenu).
  local _, _, _, hRich = Tooltip.draw(0, 0, {
    name = "Rich", fam = "abyss",
    stats = { { label = "HP", value = 30 }, { label = "DMG", value = 9 }, { label = "CD", value = "5s" } },
    passive = "WEAKEN", affKey = "poison", prose = "A long descriptive passage that wraps across several lines of prose.",
  })
  local _, _, _, hBare = Tooltip.draw(0, 0, { name = "Bare" })
  assert(hRich > hBare, "un tooltip riche est plus haut qu'un tooltip nu (hauteur mesurée)")

  -- variantes : flèche droite, sans stats, minimal.
  ok, err = pcall(function()
    Tooltip.draw(400, 200, { name = "Husk", arrow = "right", prose = "A quiet thing.", t = 1.0 })
    Tooltip.draw(400, 200, { name = "Stub", arrow = "none" })
    Tooltip.draw(0, 0, { name = "X" })
  end)
  assert(ok, "Tooltip.draw (variantes) ne doit pas crasher : " .. tostring(err))
end

-- ════════════════════════════ 4) HEADLESS-SAFE (firewall de bake) ════════════════════════════
-- Sous le mock, Forge.real() est faux -> aucun bake GPU réel ; les widgets existent quand même (no-op propre).
assert(Forge.real() == false, "sous le mock LÖVE, le bake Forge no-op (real() = false)")

print("=> MOLECULES OK : relic_card (3 etats) + banner (3 verdicts) + tooltip (mesure + variantes), headless-safe.")
