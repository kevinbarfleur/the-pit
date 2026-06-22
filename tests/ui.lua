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
local Forge = require("src.ui.forge")
local Frameforge = require("src.scenes.frameforge")

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

  -- ── Forge : kit « nightmare forge » (port de forge-px.js) ──────────────────────────────────────
  -- Sous le mock LÖVE : real()==false -> aucun bake (image/imageData nil), mais le tampon + tous les draw
  -- fns tournent sans crash (set/blend/add no-op si FFI absent ; harmless si présent). On vérifie la
  -- LOGIQUE pure (palettes, mesure de texte, état d'easing, widget construit) + smoke de chaque draw.
  assert(Forge.PX == 2, "PX = 2 par defaut (densite creatures : 1 art-px = 2 px ecran)")
  assert(type(Forge.ACCENTS.gold) == "table" and Forge.ACCENTS.violet, "palettes d'accent presentes")
  -- frameWeather : grit cisele seede, ne crashe pas (no-op headless ; bit-faithful sinon).
  do
    local wv = Forge.newWidget(40, 20)
    Forge.render(wv, function(b, W, H, t)
      Forge.frame(b, 0, 0, W - 1, H - 1, { t = 3, accent = true })
      Forge.frameWeather(b, 0, 0, W - 1, H - 1, 3, 7, nil, false)
    end, 1.0)
  end
  Forge.setAccent("violet"); Forge.setAccent("inconnu"); Forge.setAccent("gold") -- accent inconnu = no-op
  assert(Forge.FAM.flesh and Forge.AFFL.bleed and Forge.LIQ.mana, "palettes FAM/AFFL/LIQ portees")
  -- easing : converge vers la cible d'interaction (framerate-dependent elerp, comme le JS).
  local est = { hover = true, glow = 0, press = 0, eyeOpen = 0 }
  for _ = 1, 80 do Forge.easeBtn(est) end
  assert(est.glow > 0.5 and est.eyeOpen > 0.9, "easeBtn converge (glow+eyeOpen montent au survol)")
  -- widget : Image+ImageData alloues UNE FOIS (cache de taille) ; sous mock -> pas d'image (no bake).
  local w = Forge.newWidget(60, 13)
  assert(w.aw == 60 and w.ah == 13 and w.buf, "widget construit (dims + tampon)")
  assert((not Forge.real()) == (w.image == nil), "headless: pas de bake ; reel: image bakee")
  -- genEyes : deterministe (meme seed -> meme nuee), evite le label, borne 2..7.
  local eyes = Forge.genEyes(60, 11, 11, "DESCEND", 9)
  assert(#eyes >= 2 and #eyes <= 7, "genEyes : nuee bornee 2..7")
  -- render : chaque draw fn s'execute (ecrit le tampon) sans crash, sous mock comme reel.
  Forge.render(w, function(b, W, H, t) Forge.drawButton(b, W, H, 0, 1, 0.55, 11, "DESCEND", false, eyes, { 30, 5 }, 9, t) end, 1.2)
  local probes = {
    { 30, 30, function(b, W, H, t) Forge.drawOrb(b, W, H, 0.6, Forge.LIQ.blood, 101, t) end },
    { 60, 16, function(b, W, H, t) Forge.drawGauge(b, W, H, 0.16, { { frac = 0, color = Forge.AFFL.bleed.c, bmp = Forge.AFFL.bleed.bmp } }, t) end },
    { 56, 34, function(b, W, H, t) Forge.drawPanel(b, W, H, t, "GRIMOIRE") end },
    { 52, 30, function(b, W, H, t) Forge.drawTooltip(b, W, H, t, { { txt = "ASH-MAW", gold = true } }) end },
    { 46, 56, function(b, W, H, t) Forge.drawRelicCard(b, W, H, "selected", { name = "X", fam = "flesh", effect = "e", flavor = "f" }, t) end },
    { 72, 22, function(b, W, H, t) Forge.drawBanner(b, W, H, "VICTORY", "win", t) end },
    { 80, 6, function(b, W, H, t) Forge.drawDivider(b, W, H, t) end },
    { 14, 14, function(b, W, H, t) Forge.drawGem(b, W, H, true, t) end },
    { 18, 18, function(b, W, H, t) Forge.drawEyeRing(b, W, H, 0.9, 0.7, t, 3) end },
    { 12, 12, function(b, W, H, t) Forge.drawTypePip(b, W, H, "arcane", t) end },
    { 13, 8, function(b, W, H, t) Forge.drawLevelPips(b, W, H, 3, t) end },
    { 34, 11, function(b, W, H, t) Forge.drawEcoBtn(b, W, H, 0, 0.5, 1, "REROLL", 2, false, t) end },
    { 12, 12, function(b, W, H, t) Forge.drawIconBtn(b, W, H, 0, 0.5, 1, "sigil", t) end },
  }
  for _, p in ipairs(probes) do Forge.render(Forge.newWidget(p[1], p[2]), p[3], 1.3) end

  -- ── Frameforge : la scène-showcase construit + update + draw headless sans crash ──
  local hostStub = { name = "menu", menu = {} }
  local scene = Frameforge.new({}, 320, 180, hostStub)
  assert(#scene.cells > 0, "frameforge : cellules construites")
  local view = { ox = 0, oy = 0, scale = 4 }
  scene:update(1.0)
  scene:drawBack(view)
  scene:drawWorld()
  scene:drawOverlay(view)
  scene:mousemoved(24, 54)          -- survol (coords virtuelles) -> entre dans des cellules live
  scene:mousepressed(24, 54, 1)     -- clic
  scene:update(1.0)                 -- anime l'easing
  scene:drawOverlay(view)
  scene:mousereleased(24, 54, 1)
  scene:keypressed("tab")           -- cycle d'accent (no crash)

  -- ── TUNER : PX + tailles ; cycle de paramètre + ajustement -> change la valeur ET re-bake (no crash). ──
  assert(#scene.tuned > 0, "tuner : des boutons-heros tunables existent")
  assert(scene.tune.px == 2 and scene.tune.bw == 108 and scene.tune.bh == 30 and scene.tune.fontSz == 8
    and scene.tune.pad == 5 and scene.tune.eyeR == 8, "defauts small-first dense (PX2 108x30 font8 pad5 eye8)")
  -- param 1 = PX (densite ecran). L'ajuster change le PX d'affichage des boutons-heros (cell.px).
  assert(scene.tuneSel == 1, "param 1 = PX par defaut")
  scene:adjustTune(1)               -- PX 2 -> 3
  assert(scene.tune.px == 3, "adjustTune PX +1")
  for _, c in ipairs(scene.tuned) do assert(c.px == 3, "re-bake propage cell.px = PX tune") end
  scene:adjustTune(-1)              -- PX 3 -> 2
  assert(scene.tune.px == 2, "adjustTune PX -1")
  scene:keypressed("t")             -- selectionne BTN-W
  assert(scene.tuneSel == 2, "[t] cycle le parametre (-> BTN-W)")
  local before = scene.tune.bw
  scene:keypressed("up")            -- BTN-W +step (4)
  assert(scene.tune.bw == before + 4, "[up] ajuste BTN-W de step")
  scene:keypressed("down")
  assert(scene.tune.bw == before, "[down] revient")
  -- clamp aux bornes : on pousse fort dans les deux sens (max 160 / min 48 pour BTN-W).
  for _ = 1, 80 do scene:adjustTune(1) end
  assert(scene.tune.bw <= 160, "tune borne au max")
  for _ = 1, 80 do scene:adjustTune(-1) end
  assert(scene.tune.bw >= 48, "tune borne au min")
  scene:drawOverlay(view)           -- redessine page 1 avec le tuner apres re-bakes

  scene:keypressed("space")         -- page 2
  assert(scene.page == 2, "frameforge : [space] passe page 2")
  scene:drawOverlay(view)           -- dessine la page 2 (cadres/cartes/atomes) sans crash
  scene:mousemoved(40, 120); scene:mousepressed(40, 120, 1); scene:mousereleased(40, 120, 1)
  scene:keypressed("m")             -- retour menu (host stub)
  assert(hostStub.name == "menu", "frameforge : [m] revient au menu")

  -- ── Forge.genEyes : NUÉE éparpillée (plusieurs yeux), keep-out du label, rayons variés bornés. ──
  local fW, fH, fpad, fEye = 120, 30, 5, 8
  local eA = Forge.genEyes(fW, fH, 7, "DESCEND", 8, { frameTh = 2, pad = fpad, eyeR = fEye })
  assert(#eA >= 2, "genEyes : une NUEE (>=2 yeux) sur un bouton large")
  -- zone de keep-out du label (mêmes bornes que genEyes) : aucun œil ne doit la chevaucher.
  local mW = require("src.ui.forge").measure("DESCEND", 8)
  local lkx0 = math.floor(fW / 2 - mW / 2) - fpad
  local lkx1 = math.floor(fW / 2 + mW / 2) + fpad
  local lky0 = math.floor(fH / 2 - 1) - 1 -- approx (la hauteur du masque ~ font) ; on garde une marge
  local lky1 = math.floor(fH / 2 + 1) + 1
  for _, e in ipairs(eA) do
    assert(e.r >= 3 and e.r <= fEye + 1, "rayon varie autour de eyeR, borne")
    -- jamais sur le texte : l'œil (ex±r, ey±r) ne recouvre pas la boite du label (avec marge).
    local overX = (e.ex + e.r > lkx0 and e.ex - e.r < lkx1)
    local overY = (e.ey + e.r > lky0 and e.ey - e.r < lky1)
    assert(not (overX and overY), "aucun oeil ne chevauche le label (keep-out)")
  end
  -- déterminisme : même seed -> même nuée.
  local eA2 = Forge.genEyes(fW, fH, 7, "DESCEND", 8, { frameTh = 2, pad = fpad, eyeR = fEye })
  assert(#eA2 == #eA, "genEyes deterministe (meme seed -> meme nombre d'yeux)")
  local eB = Forge.genEyes(76, 24, 7, "DESCEND", 8, 2) -- ancienne signature (frameTh=number)
  assert(type(eB) == "table", "genEyes retro-compat (frameTh nombre)")
end)

if ok then
  print("=> UI OK : Frame + Chip + Keywords + Theme.state + Forge (nightmare-forge kit) + Frameforge showcase.")
else
  print("=> UI FAIL :")
  print(err)
  os.exit(1)
end
