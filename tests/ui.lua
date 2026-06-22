-- tests/ui.lua
-- Tests de la FONDATION UI (Phase 1) : Frame (encadré runique réutilisable) + Chip (pastille keyword) +
-- Keywords (registre des afflictions) + Theme.state (vocabulaire d'état). Couche RENDER -> tournée sous le
-- mock LÖVE (love.graphics/love.image stubés) : on vérifie la LOGIQUE pure (registre, op->clé, applied,
-- largeurs, vocabulaire d'état) et que le rendu ne CRASHE pas (smoke sur tous les niveaux/états).
--   Lancement : luajit tests/ui.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Theme = require("src.ui.theme")
local Frame = require("src.ui.frame")
local Chip = require("src.ui.chip")
local Keywords = require("src.ui.keywords")

local ok, err = pcall(function()
  -- ── Theme.state : vocabulaire d'état complet + repli sur idle ──
  for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }) do
    local st = Theme.stateOf(s)
    assert(st and st.fill and st.text, "etat complet : " .. s)
  end
  assert(Theme.stateOf("inconnu") == Theme.state.idle, "etat inconnu -> idle")
  assert(Theme.state.hover.glow and Theme.state.hover.glow > 0, "hover a une lueur")
  assert(Theme.state.pressed.inset, "pressed est enfonce")
  assert(Theme.state.disabled.flat, "disabled est a plat")
  assert(Theme.state.danger.gild and Theme.state.selected.gild, "danger/selected sont gildes")

  -- ── Keywords : registre des afflictions ──
  assert(#Keywords.order == 5, "5 afflictions au registre")
  for _, k in ipairs(Keywords.order) do
    local a = Keywords.get(k)
    assert(a and a.color, "descripteur + couleur : " .. k)
    assert(Keywords.name(k) ~= "" and Keywords.name(k) ~= a.name, "nom i18n resolu : " .. k)
    assert(Keywords.blurb(k) ~= "", "phrase i18n : " .. k)
  end
  assert(Keywords.name("burn") == "BURN", "i18n burn")

  -- ── op -> affliction + applied(unit) (lit les effects, ordre canonique, dedup) ──
  assert(Keywords.opAffliction("poison") == "poison", "op poison")
  assert(Keywords.opAffliction("aura_grant_bleed") == "bleed", "op aura -> bleed")
  assert(Keywords.opAffliction("bonus_first") == nil, "op non-affliction -> nil")
  assert(Keywords.opAffliction("op_inconnue_d_un_autre_chantier") == nil, "op inconnue -> nil (defensif)")

  local u = { effects = {
    { trigger = "on_hit", op = "burn", params = { dps = 6 } },     -- volontairement avant poison...
    { trigger = "on_hit", op = "poison", params = { dps = 2 } },   -- ...pour verifier le tri canonique
    { trigger = "on_hit", op = "poison", params = { dps = 1 } },   -- doublon -> dedup
    { trigger = "on_attack", op = "bonus_first", params = { value = 8 } }, -- ignore (pas une affliction)
  } }
  local ap = Keywords.applied(u)
  assert(#ap == 2, "2 afflictions distinctes (poison+burn)")
  assert(ap[1] == "poison" and ap[2] == "burn", "ordre canonique (poison avant burn), dedup")
  assert(#Keywords.applied({}) == 0, "unite sans effets -> aucune affliction")
  assert(#Keywords.applied(nil) == 0, "nil -> aucune affliction (pas de crash)")

  -- ── Icône bakée (mock : image stub mais dimensions reelles de la grille) ──
  local ic = Keywords.icon("burn")
  assert(ic and ic.w > 0 and ic.h > 0, "icone burn bakee avec dimensions")
  assert(Keywords.icon("burn") == ic, "bake memoise (meme objet)")
  assert(Keywords.icon("pas_une_affliction") == nil, "cle inconnue -> nil")

  -- ── Frame : smoke des 3 niveaux + retour de la zone interieure ──
  local font = love.graphics.getFont()
  for _, lvl in ipairs({ "plain", "bevel", "gilded" }) do
    local ix, iy, iw, ih = Frame.draw(100, 100, 200, 60, { level = lvl, font = font })
    assert(iw > 0 and ih > 0, "zone interieure positive : " .. lvl)
    assert(ix >= 100 and iy >= 100, "zone interieure dans le cadre : " .. lvl)
  end
  -- Tous les etats ne crashent pas, label compris.
  for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }) do
    Frame.button(0, 0, 120, 28, "TEST", { state = s, font = font })
  end
  -- Accent override (rareté) + fill=false (cadre sur contenu) + cadre dégénéré : robustes.
  Frame.draw(10, 10, 64, 64, { level = "gilded", accent = Theme.hex(0xccaa44), fill = false, font = font })
  Frame.draw(0, 0, 3, 3, { font = font })

  -- ── Chip : largeur coherente + smoke ──
  local wWithVal = Chip.width({ key = "burn", value = 6, font = font })
  local wNoVal = Chip.width({ key = "burn", font = font })
  assert(wWithVal > wNoVal, "la valeur ajoute de la largeur")
  local wNoIcon = Chip.width({ key = "burn", icon = false, font = font })
  assert(wNoIcon < wNoVal, "masquer l'icone reduit la largeur")
  Chip.draw(10, 10, { key = "poison", value = "2dps", font = font })
  local total = Chip.row(0, 0,
    { { key = "poison" }, { key = "bleed" }, { label = "CARRY", color = Theme.c.gold, icon = false } },
    { font = font })
  assert(total > 0, "rangee de chips : largeur totale > 0")
end)

if ok then
  print("=> UI OK : Frame (bevel/gilded/etats) + Chip + Keywords (afflictions) + Theme.state.")
else
  print("=> UI FAIL :")
  print(err)
  os.exit(1)
end
