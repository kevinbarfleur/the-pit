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
      { id = "frost_seal",      runOp = "shop_freeze",    tier = 2 },
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
    -- shop_freeze : débloque 1 verrou de boutique, hors combat.
    do
      local rf = RunState.new(106)
      assert(rf.freezeSlots == 0, "frost_seal : aucun slot de gel au depart")
      assert(rf:grantRelic("frost_seal"), "frost_seal : grant OK")
      assert(rf.freezeSlots == 1, "frost_seal : debloque 1 slot de gel")
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

  -- 2c) OP relic_aura_stat (refonte 2026-06, plan relics-overhaul §2.0 / V1) : BAKE direct d'un champ
  -- combat-time sur les specs (post-buildComp). Teste-le avec des reliques SYNTHETIQUES (gated : aucune
  -- relique du pool ne l'utilise au moment du test V1) -> on appelle Relics.apply directement.
  do
    -- target=team : chaque spec recoit +value sur le champ MOTEUR. atkInc = identite, ADDITIF a un atkInc existant.
    local rTeam = { id = "_syn_banner", op = "relic_aura_stat", params = { stat = "atkInc", target = "team", value = 0.10 } }
    local ct = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, atkInc = 0.20 },
                 { id = "b", hp = 50, dmg = 10, cd = 36, depth = 1, row = 1, slot = 2 } }
    Relics.apply(ct, rTeam)
    assert(math.abs(ct[1].atkInc - 0.30) < 1e-9, "relic_aura_stat team : atkInc ADDITIF (0.20+0.10)")
    assert(math.abs(ct[2].atkInc - 0.10) < 1e-9, "relic_aura_stat team : atkInc pose sur tous (defaut 0)")

    -- stat=lifesteal -> champ MOTEUR `lifestealAura` (le nom que makeUnit lit, arena.lua:151), PAS `lifesteal`.
    local rLife = { id = "_syn_lantern", op = "relic_aura_stat", params = { stat = "lifesteal", target = "team", value = 0.05 } }
    local cl = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 } }
    Relics.apply(cl, rLife)
    assert(math.abs(cl[1].lifestealAura - 0.05) < 1e-9, "relic_aura_stat lifesteal -> lifestealAura (champ lu par makeUnit)")
    assert(cl[1].lifesteal == nil, "relic_aura_stat lifesteal : NE pose PAS un champ lifesteal inerte")

    -- target=role:front : UNE seule unite (depth min ; tie-break row asc puis slot asc IDENTIQUE a chooseTarget).
    -- multicast = ENTIER, additif (cumulera avec hookjaw a la LECTURE, borne MULTICAST_MAX par l'arene).
    local rEcho = { id = "_syn_crown", op = "relic_aura_stat", params = { stat = "multicast", target = "role:front", value = 1 } }
    local cf = { { id = "back", hp = 50, dmg = 10, cd = 36, depth = 1, row = 0, slot = 1 },
                 { id = "frontHi", hp = 50, dmg = 10, cd = 36, depth = 0, row = 1, slot = 5 },   -- front, row 1
                 { id = "frontLo", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 9 } }   -- front, row 0 -> GAGNE (tie-break)
    Relics.apply(cf, rEcho)
    assert(cf[3].multicast == 1, "relic_aura_stat role:front : bake sur l'unite avant (tie-break row asc)")
    assert(cf[1].multicast == nil and cf[2].multicast == nil, "relic_aura_stat role:front : AUCUNE autre unite touchee")

    -- comp VIDE / champ non-mappe : aucun crash, aucune mutation parasite (robustesse).
    local rNop = { id = "_syn_nop", op = "relic_aura_stat", params = { stat = "unknownStat", target = "team", value = 9 } }
    local ce = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 } }
    Relics.apply(ce, rNop) -- stat non mappe -> bakeStat no-op
    assert(ce[1].hp == 50 and ce[1].dmg == 10, "relic_aura_stat stat inconnu : innocuite (rien bake)")
    Relics.apply({}, rTeam) -- comp vide -> pas de nil-deref
  end

  -- 2d) NOUVELLES reliques (refonte 2026-06, plan relics-overhaul §2 / V2-V3) : chaque relique pose le bon
  -- effet/champ sur la compo au build. On verifie aussi le PALIER (band) -> couleur de carte.
  do
    -- BLOOD BANNER (relic_aura_stat atkInc team) : +0.10 atkInc sur chaque unite.
    local bb = RunState.new(200); bb:grantRelic("blood_banner")
    local cbb = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 },
                  { id = "b", hp = 50, dmg = 10, cd = 36, depth = 1, row = 1, slot = 2 } }
    bb:applyRelics(cbb)
    assert(math.abs(cbb[1].atkInc - 0.10) < 1e-9 and math.abs(cbb[2].atkInc - 0.10) < 1e-9, "blood_banner: +0.10 atkInc team")
    assert(Relics.blood_banner.band == "mid", "blood_banner: band mid")

    -- ECHO CROWN (relic_aura_stat multicast role:front) : +1 multicast sur LA seule unite avant.
    local ec = RunState.new(201); ec:grantRelic("echo_crown")
    local cec = { { id = "back", hp = 50, dmg = 10, cd = 36, depth = 1, row = 0, slot = 1 },
                  { id = "front", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 5 } }
    ec:applyRelics(cec)
    assert(cec[2].multicast == 1 and cec[1].multicast == nil, "echo_crown: +1 multicast sur role:front uniquement")
    assert(Relics.echo_crown.band == "high", "echo_crown: band high")

    -- TIDE-CALLER (relic_aura_stat dmgReduce team) + BAIT-LANTERN (relic_aura_stat lifesteal -> lifestealAura).
    local tc = RunState.new(202); tc:grantRelic("tide_caller"); tc:grantRelic("bait_lantern")
    local ctc = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 } }
    tc:applyRelics(ctc)
    assert(math.abs(ctc[1].dmgReduce - 0.04) < 1e-9, "tide_caller: 0.04 dmgReduce team (tuné §4 #5)")
    assert(math.abs(ctc[1].lifestealAura - 0.05) < 1e-9, "bait_lantern: 0.05 lifestealAura (champ lu par makeUnit)")

    -- relic_add_effect (op on_hit/on_kill/on_attack lu en combat) : l'effet est INJECTE dans spec.effects.
    local function injects(relic, trig, op)
      local r = RunState.new(210); r:grantRelic(relic)
      local cc = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 } }
      r:applyRelics(cc)
      for _, e in ipairs(cc[1].effects or {}) do if e.trigger == trig and e.op == op then return true end end
      return false
    end
    assert(injects("seers_mark", "on_hit", "grant_vuln"), "seers_mark: on_hit grant_vuln")
    assert(injects("carrion_feast", "on_kill", "heal_on_kill"), "carrion_feast: on_kill heal_on_kill")
    assert(injects("second_plague", "on_hit", "grant_affliction_if_absent"), "second_plague: on_hit grant_affliction_if_absent")
    assert(injects("gravediggers_due", "on_attack", "execute"), "gravediggers_due: on_attack execute")
    assert(injects("splitting_maw", "on_hit", "cleave"), "splitting_maw: on_hit cleave")
    -- paliers des nouvelles MOYEN/HAUT (band -> couleur).
    for _, id in ipairs({ "seers_mark", "carrion_feast", "second_plague", "tide_caller", "bait_lantern" }) do
      assert(Relics[id].band == "mid", id .. ": band mid")
    end
    for _, id in ipairs({ "gravediggers_due", "splitting_maw" }) do
      assert(Relics[id].band == "high", id .. ": band high")
    end
  end

  -- 2d-bis) W1 — AXE TYPE-IDENTITÉ (plan big-update §AXE 2) : reliques gating PAR TYPE + rainbow team payoff.
  -- Le gating de type n'existait pas ; ces reliques le posent. On utilise de VRAIES unités (Units[id].type lu).
  do
    -- PACK BLOOD (relic_aura_stat atkInc type:flesh) : +0.08 atkInc sur les SEULES unités flesh.
    -- marauder/bandit = flesh (buffés) ; templar = order (intact).
    local pb = RunState.new(300); pb:grantRelic("pack_blood")
    local cpb = { { id = "marauder", hp = 60, dmg = 9, cd = 60, depth = 0, row = 0, slot = 1 },
                  { id = "bandit",   hp = 46, dmg = 7, cd = 36, depth = 0, row = 1, slot = 2 },
                  { id = "templar",  hp = 95, dmg = 12, cd = 82, depth = 1, row = 0, slot = 5 } }
    pb:applyRelics(cpb)
    assert(math.abs(cpb[1].atkInc - 0.08) < 1e-9 and math.abs(cpb[2].atkInc - 0.08) < 1e-9, "pack_blood: +0.08 atkInc sur flesh (marauder+bandit)")
    assert((cpb[3].atkInc or 0) == 0, "pack_blood: n'atteint PAS templar (order)")
    assert(Relics.pack_blood.band == "mid", "pack_blood: band mid")

    -- BILE ORB (relic_aura_stat poisonInc type:abyss) : +0.12 poisonInc sur les SEULES unités abyss.
    local bo = RunState.new(301); bo:grantRelic("bile_orb")
    local cbo = { { id = "demon", hp = 64, dmg = 9, cd = 56, poisonInc = 0.10, slot = 1 }, -- abyss (additif à 0.10)
                  { id = "witch", hp = 36, dmg = 13, cd = 72, slot = 2 } }                 -- arcane (intact)
    bo:applyRelics(cbo)
    assert(math.abs(cbo[1].poisonInc - 0.22) < 1e-9, "bile_orb: +0.12 poisonInc additif sur demon (abyss) -> 0.22")
    assert((cbo[2].poisonInc or 0) == 0, "bile_orb: n'atteint PAS witch (arcane)")
    assert(Relics.bile_orb.band == "mid", "bile_orb: band mid")

    -- PRISMATIC WRAITH (relic_rainbow) : +3 dmg / +5 hp par TYPE DISTINCT, sur CHAQUE unité (payoff team).
    -- Board : marauder(flesh) + skeleton(bone) + witch(arcane) + demon(abyss) = 4 types -> +12 dmg / +20 hp.
    local pw = RunState.new(302); pw:grantRelic("prismatic_wraith")
    local cpw = { { id = "marauder", hp = 60, dmg = 9, cd = 60, slot = 1 },
                  { id = "skeleton", hp = 40, dmg = 6, cd = 44, slot = 2 },
                  { id = "witch",    hp = 36, dmg = 13, cd = 72, slot = 3 },
                  { id = "demon",    hp = 64, dmg = 9, cd = 56, slot = 4 } }
    pw:applyRelics(cpw)
    assert(cpw[1].dmg == 9 + 12 and cpw[1].hp == 60 + 20, "prismatic_wraith: marauder +12 dmg / +20 hp (4 types)")
    assert(cpw[4].dmg == 9 + 12 and cpw[4].hp == 64 + 20, "prismatic_wraith: demon +12 dmg / +20 hp (team-wide)")
    assert(Relics.prismatic_wraith.band == "high", "prismatic_wraith: band high")

    -- borné : un board MONO-type -> count=1 -> +3 dmg / +5 hp seulement (le rainbow récompense le MÉLANGE).
    local pw2 = RunState.new(303); pw2:grantRelic("prismatic_wraith")
    local cmono = { { id = "marauder", hp = 60, dmg = 9, cd = 60, slot = 1 },
                    { id = "bandit",   hp = 46, dmg = 7, cd = 36, slot = 2 } } -- 2× flesh -> 1 type
    pw2:applyRelics(cmono)
    assert(cmono[1].dmg == 9 + 3 and cmono[1].hp == 60 + 5, "prismatic_wraith mono-type: count=1 -> +3 dmg / +5 hp")
  end

  -- 2d-ter) W3 — AXE MIMÉTISME/AMPLIFICATION (plan big-update §AXE 4) : les MÉTA-MULTIPLICATEURS (op
  -- relic_amplify_auras). APRÈS buildComp (auras bakées en champs sur les specs), ils MULTIPLIENT les sorties
  -- d'aura par (1+frac). CAPS PRÉSERVÉS : on amplifie la valeur BRUTE ; le clamp reste à la LECTURE en combat.
  do
    local Arena = require("src.combat.arena")
    -- PIERRE-DU-ZÉNITH (relic_amplify_auras frac=0.15 team) : MULTIPLIE les auras CONTINUES + amplis d'école.
    -- specs avec auras déjà bakées (atkInc 0.20, haste 0.10, poisonInc 0.30) -> ×1.15.
    local zs = RunState.new(400); zs:grantRelic("zenith_stone")
    local czs = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, atkInc = 0.20, haste = 0.10, poisonInc = 0.30 },
                  { id = "b", hp = 50, dmg = 10, cd = 36, depth = 1, row = 1, slot = 2 } } -- sans aura -> inerte (golden-safe)
    zs:applyRelics(czs)
    assert(math.abs(czs[1].atkInc - 0.23) < 1e-9, "zenith_stone: atkInc 0.20 ×1.15 = 0.23")
    assert(math.abs(czs[1].haste - 0.115) < 1e-9, "zenith_stone: haste 0.10 ×1.15 = 0.115")
    assert(math.abs(czs[1].poisonInc - 0.345) < 1e-9, "zenith_stone: poisonInc 0.30 ×1.15 = 0.345 (ampli d'école)")
    assert((czs[2].atkInc or 0) == 0, "zenith_stone: une unité SANS aura n'est pas affectée (inerte, golden-safe)")
    assert(Relics.zenith_stone.band == "high", "zenith_stone: band high")
    -- multicast (bascule ENTIÈRE) N'est PAS amplifié (anti double-snowball).
    local zm = RunState.new(401); zm:grantRelic("zenith_stone")
    local czm = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, multicast = 2 } }
    zm:applyRelics(czm)
    assert(czm[1].multicast == 2, "zenith_stone: multicast (bascule entière) JAMAIS amplifié (reste 2)")

    -- DOUBLE-LANGUE / Onsetra (relic_amplify_auras frac=0.25 role:back) : amplifie SEULEMENT l'unité d'arrière.
    -- back = depth max ; tie-break row asc/slot asc (identique chooseTarget). front (depth 0) intact.
    local fe = RunState.new(402); fe:grantRelic("forked_echo")
    local cfe = { { id = "front", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, atkInc = 0.20 },
                  { id = "back",  hp = 50, dmg = 10, cd = 36, depth = 2, row = 0, slot = 5, atkInc = 0.20 } }
    fe:applyRelics(cfe)
    assert(math.abs(cfe[2].atkInc - 0.25) < 1e-9, "forked_echo: role:back atkInc 0.20 ×1.25 = 0.25")
    assert(math.abs(cfe[1].atkInc - 0.20) < 1e-9, "forked_echo: le FRONT reste brut (0.20, focalisé arrière)")
    assert(Relics.forked_echo.band == "high", "forked_echo: band high")

    -- CÂBLE-DE-LIAISON / Link-Cable (relic_amplify_auras frac=0.20 dotOnly) : amplifie SEULEMENT les amplis d'école
    -- (poison/burn/bleed/rot), pas les stats continues. atkInc intact, poisonInc ×1.20.
    local lc = RunState.new(403); lc:grantRelic("link_cable")
    local clc = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, atkInc = 0.20, poisonInc = 0.30, burnInc = 0.10 } }
    lc:applyRelics(clc)
    assert(math.abs(clc[1].poisonInc - 0.36) < 1e-9, "link_cable: poisonInc 0.30 ×1.20 = 0.36 (dotOnly)")
    assert(math.abs(clc[1].burnInc - 0.12) < 1e-9, "link_cable: burnInc 0.10 ×1.20 = 0.12 (dotOnly)")
    assert(math.abs(clc[1].atkInc - 0.20) < 1e-9, "link_cable: atkInc INTACT (dotOnly n'amplifie PAS les stats continues)")
    assert(Relics.link_cable.band == "high", "link_cable: band high")

    -- CAP PRÉSERVÉ (le point CRITIQUE) : un atkInc déjà ÉNORME (1.4) ×1.15 = 1.61 baké, MAIS l'arène clampe à
    -- ATK_INC_CAP=1.5 à la LECTURE -> l'ampli ne franchit JAMAIS le cap. On vérifie la valeur LUE en combat.
    local zc = RunState.new(404); zc:grantRelic("zenith_stone")
    local czc = { { id = "marauder", hp = 999, dmg = 10, cd = 60, depth = 0, row = 0, slot = 1, atkInc = 1.4, effects = {} } }
    zc:applyRelics(czc)
    assert(czc[1].atkInc > 1.5, "zenith_stone CAP: la valeur BRUTE bakée dépasse le cap (1.61), prouve l'ampli")
    local a = Arena.new({ left = { czc[1] },
      right = { { id = "skeleton", hp = 99999, dmg = 1, cd = 60, effects = {}, depth = 0, row = 0, x = 10, y = 0, facing = -1 } },
      autoReset = false, seed = 11 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local dealt = hp0 - tgt.hp
    -- dmg 10, atkInc clampé 1.5 -> 10×2.5 = 25 (le cap a MORDU malgré l'ampli ; sans cap ce serait 10×2.61=26).
    assert(dealt == 25, "zenith_stone CAP: atkInc clampé 1.5 à la lecture -> 25 (le cap CONTIENT l'ampli, obtenu " .. dealt .. ")")

    -- DÉTERMINISME : deux applications identiques -> sorties identiques.
    local function ampOnce()
      local r = RunState.new(405); r:grantRelic("zenith_stone")
      local c = { { id = "a", hp = 50, dmg = 10, cd = 36, slot = 1, atkInc = 0.33 } }
      r:applyRelics(c); return c[1].atkInc
    end
    assert(math.abs(ampOnce() - ampOnce()) < 1e-12, "relic_amplify_auras déterministe (même entrée -> même sortie)")
  end

  -- 2d-quater) W4 — AXE TANK / REMOVAL / EXÉCUTION (plan big-update §AXE 7) : les reliques de FINISH / %-PV (le
  -- counter du mur, SUMMARY §3). Toutes = relic_add_effect (effet lu en combat) : grant_team{teamExecute} ou
  -- on_attack percent_hp_strike. On vérifie l'INJECTION + le PALIER + (point critique) que le %-PV est CAPPÉ à la
  -- LECTURE en combat -> impossible de one-shot, quelle que soit la cible.
  do
    local Arena = require("src.combat.arena")
    -- FAUX-DU-MOISSONNEUR (relic_add_effect -> combat_start grant_team{teamExecute}) : injecte le drapeau d'équipe.
    local function injectsGrant(relic, key)
      local r = RunState.new(500); r:grantRelic(relic)
      local cc = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; r:applyRelics(cc)
      for _, e in ipairs(cc[1].effects or {}) do
        if e.op == "grant_team" and e.params and e.params[key] ~= nil then return true end
      end
      return false
    end
    assert(injectsGrant("reapers_scythe", "teamExecute"), "reapers_scythe: injecte grant_team{teamExecute}")
    assert(Relics.reapers_scythe.band == "high", "reapers_scythe: band high")

    -- MARTEAU-DE-SIÈGE (relic_add_effect -> on_attack percent_hp_strike) : injecte l'op de frappe %-PV.
    local function injectsAttack(relic, op)
      local r = RunState.new(501); r:grantRelic(relic)
      local cc = { { id = "a", hp = 50, dmg = 7, cd = 36 } }; r:applyRelics(cc)
      for _, e in ipairs(cc[1].effects or {}) do if e.trigger == "on_attack" and e.op == op then return true end end
      return false
    end
    assert(injectsAttack("siege_hammer", "percent_hp_strike"), "siege_hammer: injecte on_attack percent_hp_strike")
    assert(Relics.siege_hammer.band == "mid", "siege_hammer: band mid")

    -- CAP EN COMBAT (le point CRITIQUE, Q8) : siege_hammer pose percent_hp_strike frac=0.08/cap=10. Contre un mur
    -- ÉNORME (maxHp 40000), 8% = 3200, MAIS le cap (min(10, PCT_STRIKE_CAP)=10) borne la contribution à 10. Le mur
    -- N'EST PAS one-shot. On vérifie la valeur LUE en combat (relique appliquée à une vraie unité, hit() réel).
    local sh = RunState.new(502); sh:grantRelic("siege_hammer")
    local atkSpec = { id = "bandit", hp = 50, dmg = 5, cd = 36, depth = 0, row = 0, slot = 1, x = 10, y = 0, facing = 1 }
    sh:applyRelics({ atkSpec }) -- injecte percent_hp_strike dans atkSpec.effects
    local a = Arena.new({ left = { atkSpec },
      right = { { id = "gravewarden", hp = 40000, dmg = 1, cd = 60, effects = {}, depth = 0, row = 0, x = 20, y = 0, facing = -1 } },
      autoReset = false, seed = 13 })
    local atk, wall = a.units[1], a.units[2]
    local hp0 = wall.hp; a:hit(atk, wall); local dealt = hp0 - wall.hp
    -- dmg base 5 + bite clampé 10 = 15 (PAS 5 + 3200). Le cap a MORDU -> aucun one-shot possible via la relique.
    assert(dealt == 5 + 10, ("siege_hammer CAP: contribution %%PV CLAMPÉE au cap 10 -> 15 dégâts (obtenu %d, JAMAIS 3205)"):format(dealt))
    assert(wall.alive and wall.hp > 39000, "siege_hammer CAP: le MUR n'est PAS one-shot par la relique (plafond absolu tient)")

    -- DÉTERMINISME : deux frappes identiques (relique appliquée) -> même mordant.
    local function bite()
      local r = RunState.new(503); r:grantRelic("siege_hammer")
      local s = { id = "bandit", hp = 50, dmg = 5, cd = 36, depth = 0, row = 0, slot = 1, x = 10, y = 0, facing = 1 }
      r:applyRelics({ s })
      local b = Arena.new({ left = { s }, right = { { id = "skeleton", hp = 5000, dmg = 1, cd = 60, effects = {}, depth = 0, row = 0, x = 20, y = 0, facing = -1 } }, autoReset = false, seed = 13 })
      local h0 = b.units[2].hp; b:hit(b.units[1], b.units[2]); return h0 - b.units[2].hp
    end
    assert(bite() == bite(), "siege_hammer: déterministe (même frappe -> même mordant %PV)")
  end

  -- 2d-quinquies) W5 — AXE POSITION / POLARITÉ DIRECTIONNELLE : reliques directionnelles. Contrairement à une
  -- aura de rôle, chaque unité du board devient SOURCE et buffe l'allié immédiat dans la direction donnée.
  do
    local rs = RunState.new(600); rs:grantRelic("rear_standard")
    local c = {
      { id = "marauder", hp = 60, dmg = 9, cd = 60, slot = 4 }, -- col 0,row 1
      { id = "bandit", hp = 46, dmg = 7, cd = 36, slot = 5 },   -- col 1,row 1 -> buffe 4 derrière
      { id = "husk", hp = 58, dmg = 4, cd = 72, slot = 6 },     -- col 2,row 1 -> buffe 5 derrière
    }
    rs:applyRelics(c)
    assert(math.abs((c[1].atkInc or 0) - 0.10) < 1e-9, "rear_standard : slot 4 reçoit +0.10 du slot 5")
    assert(math.abs((c[2].atkInc or 0) - 0.10) < 1e-9, "rear_standard : slot 5 reçoit +0.10 du slot 6")
    assert((c[3].atkInc or 0) == 0, "rear_standard : slot 6 n'a personne devant pour le buffer derrière")
    assert(Relics.rear_standard.band == "mid", "rear_standard: band mid")

    local fl = RunState.new(601); fl:grantRelic("front_lance")
    local d = {
      { id = "marauder", hp = 60, dmg = 9, cd = 60, slot = 4 },
      { id = "bandit", hp = 46, dmg = 7, cd = 36, slot = 5 },
      { id = "husk", hp = 58, dmg = 4, cd = 72, slot = 6 },
    }
    fl:applyRelics(d)
    assert((d[1].dmgReduce or 0) == 0, "front_lance : slot 4 n'est pas ciblé par ahead")
    assert(math.abs((d[2].dmgReduce or 0) - 0.10) < 1e-9, "front_lance : slot 5 reçoit +0.10 du slot 4")
    assert(math.abs((d[3].dmgReduce or 0) - 0.10) < 1e-9, "front_lance : slot 6 reçoit +0.10 du slot 5")
    assert(Relics.front_lance.band == "mid", "front_lance: band mid")
  end

  -- 2e) SURVEILLANCE D'EMPILEMENT (plan relics-overhaul §4) : les empilements dangereux restent BORNÉS au
  -- BUILD (les caps moteur a la LECTURE sont testés ailleurs : tests/synergies KEYSTONES). Ici on verifie la
  -- COMPOSITION des champs bakés (somme team + relique), qui DOIT rester sous les caps moteur.
  do
    -- #1 echo_crown × hookjaw : 2 sources multicast role:front -> SOMME = 2 (<= MULTICAST_MAX=3). Le carry avant
    -- porte deja multicast 1 (aura hookjaw) ; echo_crown ajoute 1 -> 2. JAMAIS 4+ (pas de one-shot).
    do
      local cc = { { id = "carry", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 5, multicast = 1 } } -- aura hookjaw deja bakée
      Relics.apply(cc, Relics.echo_crown)
      assert(cc[1].multicast == 2, "stack #1 : echo_crown × hookjaw -> multicast SOMMÉ = 2 (<= MULTICAST_MAX 3)")
    end
    -- #2 blood_banner × empower-unite : SOMME d'atkInc cappée à ATK_INC_CAP=1.5 a la lecture. Au build, la somme
    -- peut depasser 1.5 (1.4 + 0.10) -> exactement 1.5 ici ; l'arene clampe min(1.5, atkInc) (testé en synergies).
    do
      local ce = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1, atkInc = 1.40 } }
      Relics.apply(ce, Relics.blood_banner)
      assert(math.abs(ce[1].atkInc - 1.50) < 1e-9, "stack #2 : blood_banner + empower-unite -> atkInc somme = 1.5 (au cap lecture)")
    end
    -- #5 tide_caller × aegis : dmgReduce CUMULÉ team (0.15 + 0.04 = 0.19) reste largement sous 0.60 (pas de cap
    -- cumulé requis ; si une sim future le faisait dériver, capper a 0.60 — plan §4 #5).
    do
      local cd = { { id = "a", hp = 50, dmg = 10, cd = 36, depth = 0, row = 0, slot = 1 } }
      Relics.apply(cd, Relics.aegis); Relics.apply(cd, Relics.tide_caller)
      assert(math.abs(cd[1].dmgReduce - 0.19) < 1e-9, "stack #5 : tide_caller + aegis -> dmgReduce cumulé = 0.19 (< 0.60)")
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
    -- (14 reliques tier<=2 existent : on en possede 12 -> 2 candidats sous plafond < 3 -> fallback force.)
    local f = RunState.new(99); f.wins = 0
    f.relics = { { id = "bloodstone" }, { id = "carapace" }, { id = "aegis" }, { id = "whetstone" },
      { id = "kings_bowl" }, { id = "ember_heart" }, { id = "weeping_nail" }, { id = "grave_cap" },
      { id = "thornguard" }, { id = "beggars_lantern" }, { id = "tithe_bowl" }, { id = "frost_seal" } }
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
  print("  reliques W3: méta-multiplicateurs (zenith team / forked_echo role:back / link_cable dotOnly) -> amplifient l'aura bakée, CAP préservé à la lecture OK")
  print("  reliques W4: removal/exécution (reapers_scythe teamExecute / siege_hammer percent_hp_strike) -> injectées, %PV CAPPÉ en combat (anti one-shot) OK")
end)

if ok then
  print("=> RELIQUES OK : modele lisible + Grimoire (collection).")
else
  print("=> RELIQUES FAIL :")
  print(err)
  os.exit(1)
end
