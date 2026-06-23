-- tests/relics.lua
-- RELIQUES (modele LISIBLE, chantier 2026-06 ; cf. docs/research/relics-design.md) + GRIMOIRE (collection).
-- Verifie : (1) le grant ne stocke que l'id (plus de candidats/identification) + pas de doublon ; (2) les ops
-- transforment la compo au build (more_dmg / flat_hp / affliction_inc additif / dmg_reduce) ; (3) l'offre
-- 1-parmi-3 est SEEDEE (rejouable) ; (4) le Grimoire collectionne (learn/isKnown, meta cross-run).
-- Lancement : luajit tests/relics.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local RunState = require("src.run.state")
local Relics = require("src.data.relics")
local Grimoire = require("src.core.grimoire")

local ok, err = pcall(function()
  Grimoire.wipe()

  -- 1) GRANT LISIBLE : on ne stocke que l'id (aucun candidat/identification) ; pas de doublon.
  local a = RunState.new(123)
  assert(a:grantRelic("bloodstone"), "octroi de bloodstone")
  assert(a.relics[1].id == "bloodstone", "stocke l'id")
  assert(a.relics[1].candidates == nil and a.relics[1].identified == nil, "plus de candidats/identification")
  assert(not a:grantRelic("bloodstone"), "pas de doublon")

  -- 2) OPS au build.
  --   more_dmg (bloodstone +20%) : 10->12, 13->16.
  local comp = { { id = "bandit", hp = 46, dmg = 10, cd = 36 }, { id = "witch", hp = 36, dmg = 13, cd = 72 } }
  a:applyRelics(comp)
  assert(comp[1].dmg == 11 and comp[2].dmg == 15, "bloodstone: +14% dmg (calibre)")

  --   flat_hp (carapace +15).
  local h = RunState.new(3); h:grantRelic("carapace")
  local ch = { { id = "bandit", hp = 46, dmg = 7, cd = 36 } }
  h:applyRelics(ch)
  assert(ch[1].hp == 54, "carapace: +8 max HP (calibre)")

  --   affliction_inc (kings_bowl) : poisonInc ADDITIF sur chaque spec (cumule avec une aura).
  local p = RunState.new(1); p:grantRelic("kings_bowl")
  local cp = { { id = "witch", hp = 36, dmg = 8, cd = 72, poisonInc = 0.10 }, { id = "bandit", hp = 46, dmg = 7, cd = 36 } }
  p:applyRelics(cp)
  assert(math.abs(cp[1].poisonInc - 0.30) < 1e-9, "kings_bowl: +0.20 poisonInc (additif a l'aura 0.10)")
  assert(math.abs(cp[2].poisonInc - 0.20) < 1e-9, "kings_bowl: +0.20 poisonInc (defaut 0)")

  --   dmg_reduce (aegis) : pose dmgReduce (lu par Arena:damage cause=attack).
  local d = RunState.new(2); d:grantRelic("aegis")
  local cd = { { id = "bandit", hp = 46, dmg = 7, cd = 36 } }
  d:applyRelics(cd)
  assert(math.abs(cd[1].dmgReduce - 0.15) < 1e-9, "aegis: 0.15 dmgReduce")

  --   PALIERS (vague 2). famines_math : conditionnel a la taille d'equipe.
  local fm = RunState.new(4); fm:grantRelic("famines_math")
  local few = { { id = "a", hp = 100, dmg = 10, cd = 36 }, { id = "b", hp = 50, dmg = 20, cd = 36 } } -- 2 unites (<=3)
  fm:applyRelics(few)
  assert(few[1].dmg == 13 and few[1].hp == 120, "famines_math: <=3 unites -> +30% dmg / +20% hp")
  local fm2 = RunState.new(5); fm2:grantRelic("famines_math")
  local many = {}
  for i = 1, 4 do many[i] = { id = "u" .. i, hp = 100, dmg = 10, cd = 36 } end -- 4 unites (>3)
  fm2:applyRelics(many)
  assert(many[1].dmg == 10 and many[1].hp == 100, "famines_math: >3 unites -> inerte")

  --   hollow_choir / feeding_frenzy : ajoutent leur effet (grant_team pierceHeal / on_death frenzy) a la compo.
  local hc = RunState.new(6); hc:grantRelic("hollow_choir")
  local chc = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; hc:applyRelics(chc)
  local hasPierce = false
  for _, e in ipairs(chc[1].effects or {}) do if e.op == "grant_team" and e.params and e.params.pierceHeal then hasPierce = true end end
  assert(hasPierce, "hollow_choir: ajoute grant_team{pierceHeal}")
  local ff = RunState.new(7); ff:grantRelic("feeding_frenzy")
  local cff = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; ff:applyRelics(cff)
  local hasFrenzy = false
  for _, e in ipairs(cff[1].effects or {}) do if e.op == "frenzy_gain" then hasFrenzy = true end end
  assert(hasFrenzy, "feeding_frenzy: ajoute on_death frenzy_gain")

  --   DEFENSIVES / cadence (vague 3). whetstone : pose haste ; second_breath : pose le flag de survie.
  local ws = RunState.new(8); ws:grantRelic("whetstone")
  local cws = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; ws:applyRelics(cws)
  assert(math.abs(cws[1].haste - 0.15) < 1e-9, "whetstone: +0.15 haste")
  local sb = RunState.new(9); sb:grantRelic("second_breath")
  local csb = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; sb:applyRelics(csb)
  assert(csb[1].secondBreath == true, "second_breath: pose le flag de survie")
  --   sacred_shield : ajoute grant_team{invulnT} ; thornguard : ajoute on_attacked thorns.
  local ss = RunState.new(10); ss:grantRelic("sacred_shield")
  local css = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; ss:applyRelics(css)
  local hasInvuln = false
  for _, e in ipairs(css[1].effects or {}) do if e.op == "grant_team" and e.params and e.params.invulnT then hasInvuln = true end end
  assert(hasInvuln, "sacred_shield: ajoute grant_team{invulnT}")
  local tg = RunState.new(11); tg:grantRelic("thornguard")
  local ctg = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; tg:applyRelics(ctg)
  local hasThorns = false
  for _, e in ipairs(ctg[1].effects or {}) do if e.op == "thorns" then hasThorns = true end end
  assert(hasThorns, "thornguard: ajoute on_attacked thorns")

  --   TRANSFORMATIVES (vague 4) : posent un grant_team{flag} a combat_start.
  local function addsGrantFlag(relic, flag)
    local r = RunState.new(20); r:grantRelic(relic)
    local cc = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; r:applyRelics(cc)
    for _, e in ipairs(cc[1].effects or {}) do
      if e.op == "grant_team" and e.params and e.params[flag] ~= nil then return true end
    end
    return false
  end
  assert(addsGrantFlag("forked_tongue", "shockChain"), "forked_tongue: grant_team{shockChain}")
  assert(addsGrantFlag("everburn", "burnNoDecay"), "everburn: grant_team{burnNoDecay}")
  assert(addsGrantFlag("open_wounds", "bleedNoExpire"), "open_wounds: grant_team{bleedNoExpire}")
  assert(addsGrantFlag("plague_communion", "plagueAmp"), "plague_communion: grant_team{plagueAmp}")

  -- 2b) RELIQUES DE BOUTIQUE (Lot 6, §3.4) : champ `runOp` (PAS `op`) appliqué au GRANT sur le RUN, jamais
  -- sur la compo de combat. Existence + presence dans R.order + dispatch (XP/tier+/odds-shift) + innocuite de R.apply.
  do
    -- Existence des 3 reliques avec leur runOp et leur tier, et PAS de champ `op` (sinon R.apply agirait).
    local shopRelics = {
      { id = "carrion_ledger",  runOp = "shop_xp",        tier = 3 },
      { id = "black_summons",   runOp = "shop_tier_up",   tier = 4 },
      { id = "beggars_lantern", runOp = "shop_tier_down", tier = 2 },
    }
    for _, want in ipairs(shopRelics) do
      local rel = Relics[want.id]
      assert(rel, "relique de boutique " .. want.id .. " existe")
      assert(rel.runOp == want.runOp, want.id .. " : runOp = " .. want.runOp)
      assert(rel.op == nil, want.id .. " : aucun champ op (R.apply doit l'ignorer)")
      assert(rel.tier == want.tier, want.id .. " : tier = " .. want.tier)
      -- presente dans R.order (sinon ni offerte ni couverte par l'i18n)
      local inOrder = false
      for _, oid in ipairs(Relics.order) do if oid == want.id then inOrder = true; break end end
      assert(inOrder, want.id .. " : presente dans R.order")
    end

    -- shop_xp : pousse l'XP/le tier via la cascade addShopXp. amount=6, seuils T1=2/T2=5 -> 6 XP franchit T1
    -- (reste 4), pas T2 (4 < 5) : on monte au tier 2 avec 4 d'XP restante. (Verifie aussi qu'il MONTE bien le tier.)
    do
      local rx = RunState.new(101)
      assert(rx.shopTier == 1 and rx.shopXp == 0, "frais : tier 1, 0 XP")
      local xp0 = rx.shopXp
      assert(rx:grantRelic("carrion_ledger"), "octroi de carrion_ledger")
      assert(rx.shopTier == 2, "carrion_ledger : +6 XP -> franchit T1 (seuil 2) -> tier 2")
      assert(rx.shopXp == 4, "carrion_ledger : reste 6-2=4 d'XP (n'atteint pas le seuil T2=5)")
      assert(rx.shopXp > xp0 or rx.shopTier > 1, "carrion_ledger : l'XP/le tier de boutique a bien progresse")
    end

    -- shop_tier_up : +1 tier immediatement, et CLAMP au tier max si deja proche.
    do
      local rt = RunState.new(102)
      local t0 = rt.shopTier
      assert(rt:grantRelic("black_summons"), "octroi de black_summons")
      assert(rt.shopTier == t0 + 1, "black_summons : +1 tier de boutique")
      -- clamp : depuis le tier max, +1 ne depasse pas MAX_TIER.
      local rc = RunState.new(103)
      rc.shopTier = RunState.MAX_TIER
      assert(rc:grantRelic("black_summons"), "octroi au tier max")
      assert(rc.shopTier == RunState.MAX_TIER, "black_summons : clampe a MAX_TIER")
    end

    -- shop_tier_down : pose shopOddsShift = -1 (decalage persistant des cotes), sans toucher au tier reel.
    do
      local rd = RunState.new(104)
      assert(rd.shopOddsShift == 0, "shopOddsShift demarre a 0")
      local tier0 = rd.shopTier
      assert(rd:grantRelic("beggars_lantern"), "octroi de beggars_lantern")
      assert(rd.shopOddsShift == -1, "beggars_lantern : shopOddsShift = -1")
      assert(rd.shopTier == tier0, "beggars_lantern : le tier REEL est inchange (seul le decalage de cotes bouge)")
    end

    -- R.apply / applyRelics avec une relique runOp dans la compo : AUCUN crash, AUCUNE stat de combat modifiee.
    do
      local ra = RunState.new(105)
      ra:grantRelic("carrion_ledger"); ra:grantRelic("beggars_lantern") -- 2 runOp possedees
      local comp = { { id = "bandit", hp = 46, dmg = 10, cd = 36 } }
      ra:applyRelics(comp) -- ne doit rien faire pour ces reliques (pas de op) et ne pas planter
      assert(comp[1].hp == 46 and comp[1].dmg == 10 and comp[1].cd == 36, "runOp : R.apply n'altere AUCUNE stat de combat")
      assert(comp[1].effects == nil, "runOp : R.apply n'ajoute AUCUN effet de combat")
      -- R.apply directe sur une relique runOp (params present) : pas de nil-deref.
      Relics.apply(comp, Relics["carrion_ledger"])
      assert(comp[1].hp == 46 and comp[1].dmg == 10, "R.apply(runOp) directe : innocuite confirmee")
    end
  end

  -- 3) OFFRE 1-parmi-3 SEEDEE (meme seed -> meme offre, rejouable).
  local x = RunState.new(777):rollRelicChoices(3)
  local y = RunState.new(777):rollRelicChoices(3)
  assert(#x == 3 and #y == 3, "3 choix offerts")
  for i = 1, 3 do assert(x[i] == y[i], "offre SEEDEE deterministe (rejouable)") end

  -- 3b) OFFRE TIÉRÉE par avancée de run (PRD §5.3 : universel tot -> build-definer tard). Lot 4.
  do
    local function tierOf(id) return Relics[id].tier or 1 end
    -- Early (0 win) : le plafond est tier 2 -> AUCUN transformatif (tier 4) ne sort tant qu'on a des candidats.
    local e = RunState.new(2024); e.wins = 0
    assert(e:maxRelicTier() == 2, "early : plafond tier 2")
    local ce = e:rollRelicChoices(3)
    for _, id in ipairs(ce) do assert(tierOf(id) <= 2, "early : offre limitee aux reliques tier <=2 (" .. id .. ")") end
    -- Late (5 wins) : le plafond monte a 4 -> les build-definers (plague_communion & co) deviennent offrables.
    local l = RunState.new(2024); l.wins = 5
    assert(l:maxRelicTier() == 4, "late : plafond tier 4")
    local cl = l:rollRelicChoices(3)
    for _, id in ipairs(cl) do assert(tierOf(id) <= 4, "late : offre dans le plafond tier 4 (" .. id .. ")") end
    -- FALLBACK : si moins de 3 candidats sous le plafond (on possede presque tout le tier <=2), on elargit a TOUT.
    -- (10 reliques tier<=2 existent : on en possede 8 -> 2 candidats sous plafond < 3 -> fallback force.)
    local f = RunState.new(99); f.wins = 0
    f.relics = { { id = "bloodstone" }, { id = "carapace" }, { id = "aegis" }, { id = "whetstone" },
      { id = "kings_bowl" }, { id = "ember_heart" }, { id = "weeping_nail" }, { id = "beggars_lantern" } }
    local cf = f:rollRelicChoices(3)
    assert(#cf == 3, "fallback : l'offre reste a 3 choix meme a court de candidats tiérés")
    local sawAbove = false
    for _, id in ipairs(cf) do if tierOf(id) > 2 then sawAbove = true end end
    assert(sawAbove, "fallback : a defaut, on elargit a toutes les non possedees (un tier >2 apparait)")
  end

  -- 4) GRIMOIRE = collection (learn/isKnown ; meta cross-run, idempotent).
  assert(not Grimoire.isKnown("bloodstone"), "inconnu au depart")
  assert(Grimoire.learn("bloodstone"), "apprend (nouvelle)")
  assert(Grimoire.isKnown("bloodstone"), "le Grimoire collectionne bloodstone")
  assert(not Grimoire.learn("bloodstone"), "deja connu -> pas re-appris")

  Grimoire.wipe()
  print("  reliques : grant lisible / ops stats+amplis+paliers+defensives+transformatives(chain/burn/bleed/plague) / offre seedee / Grimoire OK")
end)

if ok then
  print("=> RELIQUES OK : modele lisible + Grimoire (collection).")
else
  print("=> RELIQUES FAIL :")
  print(err)
  os.exit(1)
end
