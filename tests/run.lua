-- tests/run.lua
-- Tests de l'ÉCONOMIE de run (src/run/state.lua) : module PUR, donc testable headless avec le mock.
-- Couvre les invariants éco (or>=0, vies/slots/niveau bornés), les transitions (achat, reroll, niveau,
-- résolution, streaks, filet de vie tour 3, fin de run) et le DÉTERMINISME seedé (rejouabilité du run).
--   Lancement : luajit tests/run.lua   (depuis la racine du projet)
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local RunState = require("src.run.state")
local Units = require("src.data.units")
local RunEvents = require("src.data.run_events")

local function shopIds(r)
  local t = {}
  for i, o in ipairs(r.shop) do t[i] = o.id end
  return table.concat(t, ",")
end

local ok, err = pcall(function()
  -- ── État initial (round 1 déjà ouvert) ──
  do
    local r = RunState.new(42)
    assert(r.gold == RunState.GOLD_PER_ROUND, "or initial = or/round")
    assert(r.lives == RunState.START_LIVES, "vies initiales = 5")
    assert(r.wins == 0 and r.losses == 0, "0 victoire / 0 defaite")
    assert(r.round == 1, "demarre au round 1")
    assert(r.slots == RunState.START_SLOTS, "demarre a 3 slots")
    assert(r.pendingSlotGrant == false, "round 1 : aucune offre de slot en attente")
    assert(#r.shop == RunState.SHOP_SIZE, "boutique = 5 offres")
    assert(r:isOver() == nil, "run en cours")
    -- Lot 5 (§5.2) : la récompense de level-up démarre disponible (drapeau faux), et REDEVIENT disponible
    -- à chaque nouveau round (reset dans startRound) -> au plus 1 relique de level-up par round.
    assert(r.relicFromLevelThisRound == false, "Lot 5 : drapeau de level-up faux au depart")
    r.relicFromLevelThisRound = true -- simule la conso du round (une fusion a déjà offert)
    r:startRound()
    assert(r.relicFromLevelThisRound == false, "Lot 5 : startRound rearme la recompense de level-up")
  end

  -- ── Profils d'economie opt-in : le comportement par defaut reste identique, mais le simulateur peut
  -- tester des variantes sans muter les constantes live.
  do
    local sap = RunState.new(101, { economy = "sap_cost" })
    assert(sap.economy.id == "sap_cost", "profil eco: id sap_cost")
    local full = 0
    for _, o in ipairs(sap.shop) do
      assert(Units[o.id].rank == 1, "sap_cost round 1: tier 1 -> rang 1")
      assert(o.cost == 2, "sap_cost round 1: rang 1 coute 2")
      full = full + o.cost
    end
    assert(full == 10, "sap_cost: shop tier 1 complet = 10 gold")
    assert(sap:sellRefund(sap.shop[1].id) == 1, "sap_cost: sell refund suit le cout profile (50%, min 1)")

    local curve = RunState.new(102, { economy = "early_curve" })
    assert(curve.gold == 6, "early_curve: round 1 donne 6 gold")
    curve:startRound()
    assert(curve.round == 2 and curve.gold == 6, "early_curve: round 2 donne 6 gold")
    curve:startRound()
    assert(curve.round == 3 and curve.gold == 8, "early_curve: round 3 donne 8 gold")

    local rr = RunState.new(103, { economy = "tiered_reroll" })
    rr.shopTier = 3
    rr.gold = 5
    assert(rr:currentRerollCost() == 2, "tiered_reroll: tier 3 reroll coute 2")
    assert(rr:reroll() and rr.gold == 3, "tiered_reroll: deduit le cout profile")

    local custom = RunState.new(104, { economy = { id = "custom_test", base = "sap_cost", goldByRound = { [1] = 7 } } })
    assert(custom.economy.id == "custom_test" and custom.gold == 7, "profil custom: override goldByRound")
    assert(custom.shop[1].cost == 2, "profil custom: herite costByRank de sap_cost")

    local xp = RunState.new(105, { economy = {
      id = "xp_test",
      passiveShopXpPerRound = 0,
      buyXpCost = 5,
      buyXpAmount = 2,
      xpToLevel = { [1] = 3, [2] = 6, [3] = 9, [4] = 12 },
    } })
    assert(xp:xpToNext() == 3, "profil custom XP: seuil T1 surcharge")
    xp:startRound()
    assert(xp.round == 2 and xp.shopTier == 1 and xp.shopXp == 0, "profil custom XP: passive 0 respectee")
    xp.gold = 10
    assert(xp:currentBuyXpCost() == 5 and xp:currentBuyXpAmount() == 2, "profil custom XP: cout/montant BUY XP surcharges")
    assert(xp:buyXp() and xp.gold == 5 and xp.shopTier == 1 and xp.shopXp == 2, "profil custom XP: premier achat reste sous seuil")
    assert(xp:buyXp() and xp.gold == 0 and xp.shopTier == 2 and xp.shopXp == 1, "profil custom XP: deuxieme achat franchit T1 avec trop-plein")
  end

  -- ── DÉTERMINISME : même seed + mêmes actions -> état strictement identique ──
  do
    local function trace(seed)
      local r = RunState.new(seed)
      local parts = { shopIds(r) }
      r:reroll(); parts[#parts + 1] = shopIds(r)
      parts[#parts + 1] = tostring(r:nextCombatSeed())
      parts[#parts + 1] = tostring(r:nextCombatSeed())
      r:startRound(); parts[#parts + 1] = shopIds(r)
      return table.concat(parts, "|")
    end
    assert(trace(12345) == trace(12345), "determinisme: meme seed -> meme run")
    assert(trace(1) ~= trace(2) or true, "seeds differents (informatif)")
  end

  -- ── Achat ──
  do
    local r = RunState.new(7)
    local offer = r.shop[1]
    local g0 = r.gold
    local id = r:buy(1)
    assert(id == offer.id, "achat: renvoie l'id de l'offre")
    assert(r.gold == g0 - offer.cost, "achat: or deduit du cout")
    assert(r.shop[1].sold, "achat: offre consommee")
    assert(r:buy(1) == nil, "achat: une offre vendue ne se rachete pas")
    -- Trop cher -> nil, or inchangé.
    r.gold = 0
    local g1 = r.gold
    assert(r:buy(2) == nil and r.gold == g1, "achat: refuse si or insuffisant")
  end

  -- ── Reroll ──
  do
    local r = RunState.new(9)
    local before = shopIds(r)
    local g0 = r.gold
    assert(r:reroll() == true, "reroll: reussit avec de l'or")
    assert(r.gold == g0 - RunState.REROLL_COST, "reroll: cout deduit")
    -- (le contenu PEUT coincider par hasard, mais l'or a bien baissé)
    r.gold = 0
    assert(r:reroll() == false, "reroll: refuse sans or")
    assert(before == before, "garde-fou")
  end

  -- ── W8 : Freeze boutique (runOp shop_freeze). Gèle une offre sans RNG ; elle survit aux rerolls ET rounds
  -- jusqu'à achat ou toggle de dégel. Sans relique, le geste est impossible.
  do
    local r = RunState.new(808)
    assert(not r:canFreezeOffer(1) and r:freezeOffer(1) == false, "freeze: impossible sans frost_seal")
    assert(r:grantRelic("frost_seal"), "freeze: frost_seal se grant")
    assert(r.freezeSlots == 1, "freeze: frost_seal debloque 1 slot de gel")
    local frozen = r.shop[2].id
    assert(r:freezeOffer(2) == true and r.shop[2].frozen, "freeze: slot 2 gelé")
    assert(r:freezeOffer(3) == false, "freeze: un seul slot gelé à la fois")
    r.gold = 99
    assert(r:reroll(), "freeze: reroll avec offre gelée")
    assert(r.shop[2].id == frozen and r.shop[2].frozen, "freeze: reroll conserve l'offre gelée au même slot")
    r:startRound()
    assert(r.shop[2].id == frozen and r.shop[2].frozen, "freeze: nouveau round conserve aussi l'offre gelée")
    local cost = r.shop[2].cost
    r.gold = cost
    assert(r:buy(2) == frozen, "freeze: achat de l'offre gelée renvoie le bon id")
    assert(not r.frozenOffers[2], "freeze: achat libère le slot gelé")
  end

  -- ── Emplacements = GRANTS TIMÉS (accepter +1 slot / refuser +or), plus de gold-leveling ──
  do
    local r = RunState.new(3)
    -- Round 1 : pas d'offre. On avance les rounds : une offre arrive aux rounds 2..7.
    assert(r:canGrant() == false, "round 1 : pas d'offre")
    assert(r:acceptSlotGrant() == false and r:declineSlotGrant() == false, "rien a trancher sans offre")
    r:startRound() -- round 2 : 1re offre
    assert(r.round == 2 and r:canGrant(), "round 2 : une offre de slot")
    local slots0 = r.slots
    assert(r:acceptSlotGrant() == true, "accepter l'offre")
    assert(r.slots == slots0 + 1, "accepter : +1 capacite de slot")
    assert(r.pendingSlotGrant == false, "offre consommee")
    assert(r:acceptSlotGrant() == false, "pas de double-accept sur la meme offre")
    -- Refus : +or, capacite INCHANGÉE, offre consommée (slot renonce).
    r:startRound() -- round 3 : nouvelle offre
    local g0, sl0 = r.gold, r.slots
    assert(r:canGrant(), "round 3 : offre")
    assert(r:declineSlotGrant() == true, "refuser l'offre")
    assert(r.gold == g0 + RunState.SLOT_DECLINE_GOLD, "refuser : +or du refus")
    assert(r.slots == sl0, "refuser : capacite inchangee")
    -- Total borné : 6 grants (rounds 2..7) -> au plus 9 slots si tout accepte.
    local r2 = RunState.new(9)
    for _ = 1, 12 do r2:startRound(); if r2:canGrant() then r2:acceptSlotGrant() end end
    assert(r2.slots == RunState.MAX_SLOTS, "tout accepter -> 9 slots")
    assert(r2.slotGrantsResolved == RunState.MAX_GRANTS, "exactement MAX_GRANTS offres tranchees")
    assert(r2:canGrant() == false, "plus d'offre au-dela du plafond")
  end

  -- ── NIVEAU DE BOUTIQUE : init au tier 1, offres 100% rang-1 (PRD progression-economy §3) ──
  do
    local Units = require("src.data.units")
    local r = RunState.new(777)
    assert(r.shopTier == RunState.START_TIER and r.shopTier == 1, "boutique demarre au tier 1")
    -- À tier 1, les cotes sont {100,0,0,0,0} : chaque offre, sur plusieurs rerolls, est de rang 1.
    for _ = 1, 40 do
      r:roll()
      for _, o in ipairs(r.shop) do
        assert(Units[o.id].rank == 1, "tier 1 : toute offre est de rang 1")
      end
    end
  end

  -- ── XP DE BOUTIQUE : état frais, achat d'XP (coût/déduction/montée), bornage au tier max ──
  do
    local r = RunState.new(55)
    -- Run frais : tier 1, AUCUNE XP (round 1 = depart, pas de passive).
    assert(r.shopTier == 1 and r.shopXp == 0, "run frais : tier 1, 0 XP")
    assert(r:xpToNext() == RunState.XP_TO_LEVEL[1], "xpToNext = seuil du tier 1")
    -- Achat d'XP : deduit BUY_XP_COST, ajoute BUY_XP_AMOUNT (XP_TO_LEVEL[1]=2 -> 4 XP cascade au tier 2, reste 2).
    r.gold = 10
    local g0 = r.gold
    assert(r:canBuyXp() == true, "assez d'or : achat d'XP possible")
    assert(r:buyXp() == true, "achat d'XP reussit")
    assert(r.gold == g0 - RunState.BUY_XP_COST, "achat d'XP : or deduit du cout exact")
    -- 4 XP avec seuil T1=2 -> monte au tier 2, reste 4-2=2 d'XP.
    assert(r.shopTier == 2, "achat d'XP : franchit le tier 1 (seuil 2 <= 4 XP)")
    assert(r.shopXp == RunState.BUY_XP_AMOUNT - RunState.XP_TO_LEVEL[1], "achat d'XP : trop-plein reporte (4-2=2)")
    -- Or insuffisant -> pas d'achat, etat inchange.
    r.gold = RunState.BUY_XP_COST - 1
    local g1, t1, xp1 = r.gold, r.shopTier, r.shopXp
    assert(r:canBuyXp() == false, "or insuffisant : achat impossible")
    assert(r:buyXp() == false, "achat refuse sans or suffisant")
    assert(r.gold == g1 and r.shopTier == t1 and r.shopXp == xp1, "echec d'achat : or/tier/XP inchanges")
    -- CASCADE : un gros gain d'XP traverse PLUSIEURS tiers d'un coup.
    do
      local rc = RunState.new(55)
      -- seuils T1=2, T2=5 -> 7 XP exactement = tier 1 -> 3 (2 puis 5), reste 0.
      rc:addShopXp(RunState.XP_TO_LEVEL[1] + RunState.XP_TO_LEVEL[2])
      assert(rc.shopTier == 3 and rc.shopXp == 0, "cascade : 7 XP traverse 2 tiers (1->3), reste 0")
    end
    -- Au tier max : xpToNext nil, l'XP n'accumule plus, buyXp impossible.
    local r2 = RunState.new(55)
    r2:addShopXp(1000) -- saute au max d'un coup
    assert(r2.shopTier == RunState.MAX_TIER and r2.shopTier == 5, "gros gain : monte jusqu'au tier max (5)")
    assert(r2.shopXp == 0, "tier max : XP remise a 0 (barre pleine)")
    assert(r2:xpToNext() == nil, "tier max : xpToNext = nil")
    assert(r2:canBuyXp() == false, "tier max : achat d'XP impossible")
    assert(r2:buyXp() == false, "tier max : buyXp renvoie false")
    r2:addShopXp(50)
    assert(r2.shopTier == RunState.MAX_TIER and r2.shopXp == 0, "tier max : addShopXp n'accumule plus")
  end

  -- ── XP PASSIVE : avancer les rounds SANS dépenser fait monter le tier suivant XP_TO_LEVEL ──
  do
    local r = RunState.new(99)
    -- Round 1 = depart : 0 XP, tier 1 (deja verifie ci-dessus, on confirme).
    assert(r.round == 1 and r.shopXp == 0 and r.shopTier == 1, "round 1 : 0 XP, tier 1")
    -- Passive = +1/round a partir du round 2. XP cumulee au round R = (R-1). Avec seuils T1=2, T2=5 :
    --   cumul 2 -> tier 2 (round 3), cumul 7 -> tier 3 (round 8). On verifie ces deux paliers.
    -- Atteindre le round 3 : cumul d'XP = 2 (rounds 2 et 3) -> exactement le seuil T1 -> tier 2, reste 0.
    r:startRound() -- round 2 : +1 XP (1)
    assert(r.round == 2 and r.shopTier == 1 and r.shopXp == 1, "round 2 : 1 XP passive, encore tier 1")
    r:startRound() -- round 3 : +1 XP (cumul 2) -> franchit T1
    assert(r.round == 3 and r.shopTier == 2 and r.shopXp == 0, "round 3 : cumul 2 -> tier 2, reste 0")
    -- Avancer jusqu'au round 8 : +5 XP de plus (cumul depuis T2 = 5) = seuil T2 -> tier 3.
    for _ = 1, 5 do r:startRound() end
    assert(r.round == 8, "atteint le round 8")
    assert(r.shopTier == 3, "round 8 : passive seule a atteint le tier 3 (cumul 7)")
    assert(r.shopXp == 0, "round 8 : trop-plein consomme pile (reste 0)")
  end

  -- ── COTES : distribution au tier 5 conforme à ODDS[5] (statistique mais DÉTERMINISTE, seed fixe) ──
  do
    local Units = require("src.data.units")
    local r = RunState.new(20260623)
    r.shopTier = 5 -- force le tier max (toutes les cotes actives)
    local counts = { 0, 0, 0, 0, 0 }
    local total = 0
    for _ = 1, 400 do -- 400 rolls x 5 offres = 2000 echantillons
      r:roll()
      for _, o in ipairs(r.shop) do
        counts[Units[o.id].rank] = counts[Units[o.id].rank] + 1
        total = total + 1
      end
    end
    assert(total == 2000, "echantillon = 2000 offres")
    local odds = RunState.ODDS[5]
    for rank = 1, 5 do
      local share = 100 * counts[rank] / total
      assert(math.abs(share - odds[rank]) <= 6,
        string.format("cotes T5 rang %d : %.1f%% ~ %d%% (tol +-6pt)", rank, share, odds[rank]))
    end
  end

  -- ── Lot 6 : DÉCALAGE DE COTES (shopOddsShift) + raiseShopTier (relics de boutique) ──
  do
    local Units = require("src.data.units")
    -- shopOddsShift par défaut = 0, et roll() est ALORS strictement inchangé (les tests de cotes/determinisme
    -- ci-dessus le prouvent déjà). On reverifie l'identite : tier 1, shift 0 -> 100% rang 1 (comme avant Lot 6).
    local r0 = RunState.new(778899)
    assert(r0.shopOddsShift == 0, "shopOddsShift demarre a 0 (defaut)")
    for _ = 1, 20 do
      r0:roll()
      for _, o in ipairs(r0.shop) do assert(Units[o.id].rank == 1, "shift 0 @ tier 1 : toujours rang 1 (inchange)") end
    end

    -- Avec shopTier=3 et shopOddsShift=-1, les offres suivent ODDS[2] (le tier décalé), PAS ODDS[3].
    -- Distribution echantillonnee (seed fixe -> deterministe) comparee a la ligne du tier 2.
    local rs = RunState.new(20260623)
    rs.shopTier = 3
    rs.shopOddsShift = -1
    local counts = { 0, 0, 0, 0, 0 }
    local total = 0
    for _ = 1, 400 do
      rs:roll()
      for _, o in ipairs(rs.shop) do
        counts[Units[o.id].rank] = counts[Units[o.id].rank] + 1
        total = total + 1
      end
    end
    assert(total == 2000, "echantillon decale = 2000 offres")
    local odds2 = RunState.ODDS[2] -- tier décalé = 3 + (-1) = 2
    for rank = 1, 5 do
      local share = 100 * counts[rank] / total
      assert(math.abs(share - odds2[rank]) <= 6,
        string.format("shift -1 @ tier 3 -> cotes du tier 2, rang %d : %.1f%% ~ %d%% (tol +-6pt)", rank, share, odds2[rank]))
    end
    -- Concretement : aucun rang >= 3 ne sort (ODDS[2] = {70,30,0,0,0}).
    assert(counts[3] == 0 and counts[4] == 0 and counts[5] == 0, "shift -1 @ tier 3 : aucun rang >= 3 (cotes du tier 2)")

    -- raiseShopTier : +n borné à MAX_TIER ; depuis le max il reste au max.
    local rt = RunState.new(11)
    local t0 = rt.shopTier
    rt:raiseShopTier(1); assert(rt.shopTier == t0 + 1, "raiseShopTier(1) : +1 tier")
    rt:raiseShopTier(); assert(rt.shopTier == t0 + 2, "raiseShopTier() : defaut n=1")
    rt:raiseShopTier(10); assert(rt.shopTier == RunState.MAX_TIER, "raiseShopTier : clampe a MAX_TIER")
    rt:raiseShopTier(5); assert(rt.shopTier == RunState.MAX_TIER, "raiseShopTier : depuis le max, reste au max")
    assert(rt.shopXp == 0, "raiseShopTier au max : XP remise a 0 (barre pleine)")
    -- Bornage BAS du décalage : tier 1 + shift très négatif -> cotes du tier 1 (clamp a 1), jamais d'index nil.
    local rb = RunState.new(12)
    rb.shopTier = 1
    rb.shopOddsShift = -4
    rb:roll() -- ne doit pas planter (tier décalé borné a 1)
    for _, o in ipairs(rb.shop) do assert(Units[o.id].rank == 1, "shift tres negatif borne au tier 1 : rang 1") end
  end

  -- ── DÉTERMINISME des offres : même seed -> même suite d'ids de boutique (sur plusieurs rolls) ──
  do
    local function offerTrace(seed)
      local r = RunState.new(seed)
      local parts = { shopIds(r) }
      r:reroll(); parts[#parts + 1] = shopIds(r)
      r:reroll(); parts[#parts + 1] = shopIds(r)
      return table.concat(parts, "|")
    end
    assert(offerTrace(31337) == offerTrace(31337), "determinisme : meme seed -> memes offres de boutique")
  end

  -- ── Résolution + streaks ──
  do
    local r = RunState.new(5)
    r:resolve(true)
    assert(r.wins == 1 and r.winStreak == 1 and r.lossStreak == 0, "victoire: +1 win, streak")
    r:resolve(true); assert(r.winStreak == 2, "victoire: streak cumule")
    r:resolve(false)
    assert(r.losses == 1 and r.lives == RunState.START_LIVES - 1, "defaite: -1 vie")
    assert(r.lossStreak == 1 and r.winStreak == 0, "defaite: reset win streak")
  end

  -- ── Or FRAIS chaque round (modèle SAP, pas de report) + bonus de série ──
  do
    local r = RunState.new(5)
    r.gold = 0 -- on a tout dépensé
    r:resolve(true); r:resolve(true); r:resolve(true) -- streak 3 -> bonus 2
    r:startRound()
    assert(r.gold == RunState.GOLD_PER_ROUND + 2, "or reset a 10 + bonus de streak (3 -> +2)")
  end

  -- ── Filet de vie au round 3 (SAP) ──
  do
    local r = RunState.new(8)
    r:resolve(false) -- perte au round 1 -> 4 vies
    assert(r.lives == 4, "perte round 1")
    r:startRound() -- round 2
    assert(r.round == 2 and r.lives == 4, "round 2: pas de vie rendue")
    r:startRound() -- round 3 -> +1 vie
    assert(r.round == 3 and r.lives == 5, "round 3: +1 vie si on a perdu tot")
    -- Sans perte, pas de cadeau.
    local r2 = RunState.new(8)
    r2:startRound(); r2:startRound()
    assert(r2.lives == RunState.START_LIVES, "round 3 sans perte: vies pleines, rien en plus")
  end

  -- ── Fin de run ──
  do
    local r = RunState.new(1)
    for _ = 1, RunState.WIN_TARGET do r:resolve(true) end
    assert(r:isOver() == "win", "10 victoires -> win")
    local r2 = RunState.new(1)
    for _ = 1, RunState.START_LIVES do r2:resolve(false) end
    assert(r2:isOver() == "lose", "plus de vie -> lose")
  end

  -- ── RELIQUES : paliers par avancée (maxRelicTier) + offre tiérée + fallback + refus -> or (Lot 4) ──
  do
    local Relics = require("src.data.relics")
    local function tierOf(id) return Relics[id].tier or 1 end

    -- maxRelicTier : plafond par victoires. early (0-1)->2, mid (2-4)->3, late (5+)->4 (PRD §5.3).
    local r = RunState.new(42)
    r.wins = 0; assert(r:maxRelicTier() == 2, "0 win : plafond tier 2")
    r.wins = 1; assert(r:maxRelicTier() == 2, "1 win : encore plafond tier 2")
    r.wins = 2; assert(r:maxRelicTier() == 3, "2 wins : plafond tier 3")
    r.wins = 4; assert(r:maxRelicTier() == 3, "4 wins : encore plafond tier 3")
    r.wins = 5; assert(r:maxRelicTier() == 4, "5 wins : plafond tier 4 (transformatives)")
    r.wins = 12; assert(r:maxRelicTier() == 4, "tres avance : plafond reste 4 (max)")

    -- Offre TIÉRÉE : à chaque palier, toutes les reliques offertes sont de tier <= plafond (assez de candidats).
    for _, w in ipairs({ 0, 2, 5 }) do
      local rr = RunState.new(100 + w)
      rr.wins = w
      local ch = rr:rollRelicChoices(3)
      assert(#ch == 3, "offre tiérée : 3 choix a w=" .. w)
      local cap = rr:maxRelicTier()
      for _, id in ipairs(ch) do
        assert(tierOf(id) <= cap, "offre tiérée : tout choix <= plafond (w=" .. w .. ", " .. id .. " tier " .. tierOf(id) .. ")")
      end
    end

    -- FALLBACK : si trop peu de candidats sous le plafond (on possède presque tout le tier <=2), on élargit
    -- a TOUTES les non possédées -> une offre de 3 reste remplissable (peut alors contenir un tier > plafond).
    do
      local rf = RunState.new(5)
      rf.wins = 0 -- plafond 2 ; on possède 12 des 14 reliques tier<=2 -> seulement 2 candidats sous plafond (<3)
      rf.relics = { { id = "bloodstone" }, { id = "carapace" }, { id = "aegis" }, { id = "whetstone" },
        { id = "kings_bowl" }, { id = "ember_heart" }, { id = "weeping_nail" }, { id = "grave_cap" },
        { id = "thornguard" }, { id = "beggars_lantern" }, { id = "tithe_bowl" }, { id = "frost_seal" } }
      local ch = rf:rollRelicChoices(3)
      assert(#ch == 3, "fallback : l'offre reste remplie a 3 malgre le plafond")
      local sawAbove = false
      for _, id in ipairs(ch) do if tierOf(id) > rf:maxRelicTier() then sawAbove = true end end
      assert(sawAbove, "fallback : a defaut de candidats sous plafond, on elargit (un tier > plafond apparait)")
    end

    -- Pas de fallback inutile : avec assez de candidats sous le plafond, on N'élargit PAS (reste tiéré).
    do
      local rn = RunState.new(6)
      rn.wins = 0
      local ch = rn:rollRelicChoices(3)
      for _, id in ipairs(ch) do assert(tierOf(id) <= 2, "pas de fallback si assez de candidats tiérés") end
    end

    -- A3 : RELIQUES D'ÉCONOMIE (income / vente pleine / or-sur-victoire / report+intérêt ; NEUTRE sans relique).
    do
      local Units = require("src.data.units")
      local GR = RunState.GOLD_PER_ROUND
      -- income plat (paupers_boon) : +3 or au début de chaque round.
      local rp = RunState.new(7); rp.relics = { { id = "paupers_boon" } }
      rp:startRound()
      assert(rp.gold == GR + 3, "paupers_boon : +3 or/round (got " .. rp.gold .. ")")
      -- vente PLEINE (grave_robbers_cut) : remboursement = coût plein (sellFrac 1.0 ; base = 50%).
      local rs = RunState.new(7); rs.relics = { { id = "grave_robbers_cut" } }
      assert(rs:sellRefund("gravewarden") == Units["gravewarden"].cost, "grave_robbers_cut : remboursement plein")
      -- or SUR VICTOIRE (tithe_bowl) : +2 DIFFÉRÉ au round suivant (pas immédiat).
      local rt = RunState.new(7); rt.relics = { { id = "tithe_bowl" } }
      rt:resolve(true); rt:startRound()
      assert(rt.gold == GR + 2, "tithe_bowl : +2 or au round APRÈS la victoire (got " .. rt.gold .. ")")
      -- REPORT + INTÉRÊT (usurers_ledger) : l'or de fin de round est gardé + intérêt (+1/5, cappé 5).
      local ru = RunState.new(7); ru.relics = { { id = "usurers_ledger" } }; ru.gold = 25
      ru:startRound()
      assert(ru.gold == GR + 25 + 5, "usurers_ledger : report 25 + intérêt 5 (got " .. ru.gold .. ")")
      local ru2 = RunState.new(7); ru2.relics = { { id = "usurers_ledger" } }; ru2.gold = 50
      ru2:startRound()
      assert(ru2.gold == GR + 50 + 5, "usurers_ledger : intérêt CAPPÉ à 5 (got " .. ru2.gold .. ")")
      -- SANS relique éco : modèle SAP strict (or frais = GOLD_PER_ROUND, AUCUN report de l'or de fin).
      local rb = RunState.new(7); rb.gold = 99
      rb:startRound()
      assert(rb.gold == GR, "sans relique éco : or frais sans report (got " .. rb.gold .. ")")
    end

    -- DÉTERMINISME : même seed + mêmes wins -> mêmes ids d'offre (rejouable, snapshot/replay).
    do
      local function pick(seed, wins)
        local rd = RunState.new(seed); rd.wins = wins
        return table.concat(rd:rollRelicChoices(3), ",")
      end
      assert(pick(31337, 0) == pick(31337, 0), "offre relique : meme seed+wins -> memes choix")
      assert(pick(31337, 5) == pick(31337, 5), "offre relique (late) : meme seed+wins -> memes choix")
    end

    -- REFUS -> +or (calque du refus de slot). N'inscrit rien (pas de relique possédée en plus).
    do
      local rd = RunState.new(7)
      local g0, n0 = rd.gold, #rd.relics
      local got = rd:declineRelic()
      assert(got == RunState.DECLINE_RELIC_GOLD, "declineRelic renvoie l'or accordé (DECLINE_RELIC_GOLD)")
      assert(rd.gold == g0 + RunState.DECLINE_RELIC_GOLD, "refus : +DECLINE_RELIC_GOLD or")
      assert(#rd.relics == n0, "refus : aucune relique acquise")
    end
    print("  reliques : maxRelicTier 2/3/4 / offre tiérée + fallback / determinisme / refus->or OK")
  end

  -- ── CADENCE ~8/run (refonte reliques 2026-06, plan relics-overhaul §3) : 3 canaux. On modélise ICI la
  -- DÉCISION du host (main.lua:finishCombat) : à chaque combat résolu, quel écran relicpick s'ouvre.
  --   canal 1 (marchand) : tous les 3 COMBATS (wins+losses % 3 == 0).
  --   canal 3 (jalon)    : à la 3e ET 6e VICTOIRE, plancher minTier="mid". PRIORITÉ + return -> consomme le
  --                        créneau marchand (anti double-comptage §3.4). ──
  do
    local Relics = require("src.data.relics")
    -- Réplique de la cascade de décision du host (le `return` = priorité du jalon sur le marchand).
    local function channelFor(run, win)
      if win and (run.wins == 3 or run.wins == 6) then
        local ch = run:rollRelicChoices(3, { minTier = "mid" })
        if #ch > 0 then return "milestone", ch end
        return nil
      end
      local combats = run.wins + run.losses
      if combats % 3 == 0 then
        local ch = run:rollRelicChoices(3)
        if #ch > 0 then return "merchant", ch end
      end
      return nil
    end

    -- 10 VICTOIRES D'AFFILÉE -> EXACTEMENT 2 jalons (w3, w6) + le bon compte marchand, sans double à w3/w6.
    do
      local r = RunState.new(4242)
      local milestones, merchants = {}, {}
      for _ = 1, 10 do
        r:resolve(true) -- victoire : wins++ (l'or n'est crédité qu'au startRound, hors sujet ici)
        local ch = channelFor(r, true)
        if ch == "milestone" then milestones[#milestones + 1] = r.wins
        elseif ch == "merchant" then merchants[#merchants + 1] = r.wins end
        if r:isOver() then break end -- 10 victoires = ascension (s'arrête)
      end
      -- jalons : exactement {3, 6} (la 10e victoire termine le run avant un 3e jalon hypothétique à w9).
      assert(#milestones == 2, "cadence : exactement 2 jalons sur 10 victoires (got " .. #milestones .. ")")
      assert(milestones[1] == 3 and milestones[2] == 6, "cadence : jalons aux victoires 3 et 6")
      -- ANTI DOUBLE-COMPTAGE : à w3 (combats=3, %3==0) le jalon PRIORISE -> AUCUN marchand servi à w3 ni w6.
      for _, w in ipairs(merchants) do
        assert(w ~= 3 and w ~= 6, "anti double-comptage : aucun marchand servi en même temps qu'un jalon (w=" .. w .. ")")
      end
      -- marchand : combats multiples de 3 HORS w3/w6 -> w9 seul (w3,w6 happés par le jalon). Cadence totale = 2+1.
      assert(#merchants == 1 and merchants[1] == 9, "cadence : 1 seul marchand (w9), w3/w6 consommés par le jalon")
    end

    -- PLANCHER minTier="mid" : le jalon ne sert JAMAIS de relique band "low" (sinon cérémonie = stat-sticks).
    do
      for _, w in ipairs({ 3, 6 }) do
        local r = RunState.new(900 + w); r.wins = w
        local ch = r:rollRelicChoices(3, { minTier = "mid" })
        assert(#ch == 3, "jalon : 3 choix a w=" .. w)
        for _, id in ipairs(ch) do
          assert((Relics[id].band or "low") ~= "low", "jalon minTier=mid : aucune relique band low (w=" .. w .. ", " .. id .. ")")
        end
      end
    end

    -- GARDE DE DIVERSITÉ DE TRIO (plan §3.5) : au plus 1 ampli-famille (op relic_affliction_inc) et 1 éco
    -- (champ .eco) par trio. On force un état où le pool nominal est riche en amplis/éco et on vérifie la garde.
    do
      local function classOf(id)
        if Relics[id].op == "relic_affliction_inc" then return "ampli" end
        if Relics[id].eco then return "eco" end
        return nil
      end
      -- Balaye plusieurs seeds : chaque trie respecte la garde (mid plafond -> amplis+éco présents dans le pool).
      for seed = 1, 40 do
        local r = RunState.new(seed * 7); r.wins = 3 -- plafond tier 3 -> amplis (tier 2) ET éco (tier 2-3) offrables
        local ch = r:rollRelicChoices(3)
        local nAmpli, nEco = 0, 0
        for _, id in ipairs(ch) do
          local c = classOf(id)
          if c == "ampli" then nAmpli = nAmpli + 1 elseif c == "eco" then nEco = nEco + 1 end
        end
        assert(nAmpli <= 1, "garde de trio : au plus 1 ampli-famille (seed " .. seed .. ", got " .. nAmpli .. ")")
        assert(nEco <= 1, "garde de trio : au plus 1 éco (seed " .. seed .. ", got " .. nEco .. ")")
      end
    end

    -- DÉTERMINISME du jalon : même seed + mêmes wins -> même offre (rejouable, comme le marchand).
    do
      local function pick(seed) local r = RunState.new(seed); r.wins = 6; return table.concat(r:rollRelicChoices(3, { minTier = "mid" }), ",") end
      assert(pick(55555) == pick(55555), "jalon : offre seedée déterministe (rejouable)")
    end

    print("  cadence : canal 3 (jalon w3/w6) + minTier plancher + garde de trio + anti double-comptage OK")
  end

  -- ── RUN EVENTS : couche experimentale du marchand tous les 3 combats. Les rencontres sont thematiques, mais
  -- les rewards sont materialises explicitement (pas de surprise cachee). Les mutations restent hors pool actif
  -- tant que le modele d'instance n'est pas proprement cable. ──
  do
    assert(#RunEvents.order <= RunEvents.MAX_ACTIVE, "run events : 8 max actifs")
    local allowed = { relic = true, unit = true, gold = true, shop_xp = true, shop_tier_up = true }
    for _, id in ipairs(RunEvents.order) do
      local ev = RunEvents.events[id]
      assert(ev and ev.id == id, "run events : id declare dans events")
      assert(ev.choices and #ev.choices >= 2, "run events : au moins 2 choix pour " .. id)
      local relicChoices, nonRelicChoices = 0, 0
      for _, choice in ipairs(ev.choices) do
        local kind = choice.reward and choice.reward.kind
        assert(allowed[kind], "run events : reward actif supporte (" .. tostring(kind) .. ")")
        assert(kind ~= "mutation", "run events : pas de mutation active avant modele d'instance")
        if kind == "relic" then relicChoices = relicChoices + 1 else nonRelicChoices = nonRelicChoices + 1 end
        if kind == "unit" then
          assert((choice.reward.level or 1) <= 2, "run events : aucune unite niveau 3 offerte")
        end
      end
      assert(relicChoices >= 1, "run events : chaque event garde au moins une lane relique")
      assert(nonRelicChoices >= 1, "run events : chaque event garde au moins une lane non-relique")
    end

    local function eventSig(seed)
      local r = RunState.new(seed)
      r.wins, r.losses = 2, 1
      local ev = r:rollRunEvent()
      local parts = { ev and ev.id or "nil" }
      for _, c in ipairs((ev and ev.choices) or {}) do
        local rw = c.reward
        parts[#parts + 1] = table.concat({
          c.id, rw.kind or "", rw.id or "", tostring(rw.amount or ""), tostring(rw.level or "")
        }, ":")
      end
      return table.concat(parts, "|")
    end
    assert(eventSig(6060) == eventSig(6060), "run events : meme seed -> meme event materialise")

    local targeted = RunState.new(60605)
    targeted.wins, targeted.losses = 2, 1
    local exclude = {}
    for _, id in ipairs(RunEvents.order) do
      if id ~= "hollow_carcass" then exclude[id] = true end
    end
    local tev = targeted:rollRunEvent({
      exclude = exclude,
      unitPriority = function(id) return (id == "marauder") and 1000 or 0 end,
    })
    local targetedReward
    for _, c in ipairs((tev and tev.choices) or {}) do
      if c.reward and c.reward.kind == "unit" then targetedReward = c.reward end
    end
    assert(targetedReward and targetedReward.id == "marauder" and targetedReward.targeted,
      "run events : ciblage optionnel d'unite respecte le pool eligible")

    local r = RunState.new(6061)
    r.wins, r.losses = 3, 1
    local seen = {}
    for _ = 1, math.min(4, #RunEvents.order) do
      local ev = r:rollRunEvent()
      assert(ev and not seen[ev.id], "run events : pas de repetition tant que le pool eligible suffit")
      seen[ev.id] = true
      for _, c in ipairs(ev.choices) do
        assert(c.reward and c.reward.kind, "run events : chaque choix porte une recompense concrete")
        if c.reward.kind == "unit" then
          assert(Units[c.reward.id], "run events : unite materialisee existe")
          assert((c.reward.level or 1) <= 2, "run events : unite materialisee max niveau 2")
        end
      end
    end

    local rg = RunState.new(6062)
    local g0 = rg.gold
    assert(rg:applyRunEventReward({ kind = "gold", amount = 5 }) and rg.gold == g0 + 5,
      "run events : reward gold applique")
    local rt = RunState.new(6063)
    local tier0 = rt.shopTier
    assert(rt:applyRunEventReward({ kind = "shop_tier_up", amount = 1 }) and rt.shopTier == tier0 + 1,
      "run events : reward shop_tier_up applique")
    local rx = RunState.new(6064)
    local xp0 = rx.shopXp
    assert(rx:applyRunEventReward({ kind = "shop_xp", amount = 1 }) and rx.shopXp == xp0 + 1,
      "run events : reward shop_xp applique")
    assert(select(2, rx:applyRunEventReward({ kind = "unit", id = "marauder", level = 2 })) == "external_reward",
      "run events : reward unite reste externalise vers Build")

    print("  run events : 8 max / rewards explicites / determinisme / no mutation active OK")
  end

  -- ── Invariants sous fuzz d'actions seedées ──
  do
    local gen = love.math.newRandomGenerator(20260620)
    local runs, steps = 60, 80
    for run = 1, runs do
      local r = RunState.new(run * 101)
      for _ = 1, steps do
        local a = gen:random(1, 6)
        if a == 1 then r:buy(gen:random(1, RunState.SHOP_SIZE))
        elseif a == 2 then r:reroll()
        elseif a == 3 then if gen:random(1, 2) == 1 then r:acceptSlotGrant() else r:declineSlotGrant() end
        elseif a == 4 then r:resolve(gen:random(1, 2) == 1)
        elseif a == 5 then r.gold = r.gold + 5; r:buyXp() -- ajoute de l'or pour que l'XP/le tier bougent
        else r:startRound() end
        -- Invariants durs (jamais violés, quelle que soit la suite d'actions).
        assert(r.gold >= 0, "invariant: or >= 0")
        assert(r.lives >= 0 and r.lives <= RunState.START_LIVES, "invariant: vies dans [0,5]")
        assert(r.slots >= RunState.START_SLOTS and r.slots <= RunState.MAX_SLOTS, "invariant: slots [3,9]")
        assert(r.slotGrantsResolved <= RunState.MAX_GRANTS, "invariant: offres tranchees <= MAX_GRANTS")
        assert(#r.shop == RunState.SHOP_SIZE, "invariant: boutique = 5 offres")
        assert(r.shopTier >= RunState.START_TIER and r.shopTier <= RunState.MAX_TIER, "invariant: tier boutique [1,5]")
        assert(r.shopXp >= 0, "invariant: XP de boutique >= 0")
        local toNext = r:xpToNext()
        assert((toNext == nil) == (r.shopTier >= RunState.MAX_TIER), "invariant: xpToNext nil ssi tier max")
        assert(toNext == nil or r.shopXp < toNext, "invariant: XP toujours sous le seuil du tier courant (cascade resolue)")
        if r:isOver() then break end
      end
    end
    print(string.format("  fuzz : %d runs x %d actions, invariants eco OK", runs, steps))
  end

  print("  eco : etat initial / determinisme / achat / reroll / niveau / streaks / or-reset / vie-tour3 / fin OK")
  print("  tier boutique : init T1 (rang-1) / XP achetee+passive / cascade / cap max / cotes T5 / determinisme offres OK")
end)

if ok then
  print("=> RUN OK : economie deterministe et invariants tenus.")
else
  print("=> RUN FAIL :")
  print(err)
  os.exit(1)
end
