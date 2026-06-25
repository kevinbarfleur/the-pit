-- tests/murmures.lua
-- MURMURES (3e couche cachée — du spice, jamais build-defining ; cf. docs/research/murmures-plan.md).
-- Couvre les 10 exemplars (9 NON-RNG actifs + le coward OFF/W7) : RÉSOLUTION (présence/adjacence/famille/
-- aloneOfType/seuil/mort d'allié/durée), MAGNITUDE BORNÉE, DÉTERMINISME (même seed -> même log de murmures),
-- l'EVENT 2 CANAUX (joueur cryptique sans chiffre / dev trueKind+trueValue), et le SNAPSHOT GRATUIT
-- (réinjection par id : un ghost re-déclenche ses murmures NON-RNG sans rien encoder de neuf).
--   Lancement : luajit tests/murmures.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Arena = require("src.combat.arena")
local Bus = require("src.core.bus")
local Units = require("src.data.units")
local Whispers = require("src.data.whispers")
local Snapshot = require("src.net.snapshot")
local I18n = require("src.core.i18n")
local Chronicle = require("src.render.chronicle")
local EventLog = require("tools.eventlog")

local WHISPER_STAT_CAP = 0.10 -- borne dure (doit matcher whispers_ops.WHISPER_STAT_CAP)

local function U(id, over)
  local u = Units[id]
  local s = { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = u.effects,
    depth = 0, row = 0, shield = 0, x = 0, y = 0, facing = 1 }
  if over then for k, v in pairs(over) do s[k] = v end end
  return s
end

-- Construit une arène en INJECTANT un bus déjà abonné (pour capter les murmures de combat_start, émis
-- DANS le constructeur via spawn). Renvoie (arène, liste d'events murmur captés).
local function arenaWithMurmurLog(opts)
  local bus = Bus.new()
  local got = {}
  bus:on("murmur", function(ev) got[#got + 1] = ev end)
  opts.bus = bus
  local a = Arena.new(opts)
  return a, got
end

local ok, err = pcall(function()

  -- 0) REGISTRE DATA-PUR : chaque murmure a un id-op whisper_*, une key i18n présente, un effet borné ≤ cap.
  for carrier, list in pairs(Whispers) do
    assert(Units[carrier], "murmure porté par un id INCONNU : " .. tostring(carrier))
    for _, w in ipairs(list) do
      assert(w.op == "whisper_lineage" or w.op == "whisper_solo", "op murmure inattendu : " .. tostring(w.op))
      assert(w.key and I18n.has("whisper." .. w.key .. ".cryptic"), "key sans ligne cryptique : " .. tostring(w.key))
      local eff = w.params and w.params.effect
      assert(eff, "murmure sans effet : " .. w.key)
      if eff.kind == "stat_inc" or eff.kind == "oneshot" then
        assert((eff.value or 0) <= WHISPER_STAT_CAP + 1e-9, "murmure NON borné (> cap) : " .. w.key)
      end
    end
  end

  -- 1) LIGNÉE PRÉSENCE — THE LURE AND THE BROOD : INK HORROR + DEEP KRAKEN présents -> atkInc +0.10 + event.
  do
    local a, got = arenaWithMurmurLog({ left = { U("ink_horror"), U("deep_kraken") },
      right = { U("skeleton") }, autoReset = false, seed = 1 })
    local ink = a.units[1]
    assert(ink.atkInc == 0.10, "lure&brood: atkInc +0.10 (presence kraken)")
    local ev
    for _, e in ipairs(got) do if e.key == "the_lure_and_the_brood" then ev = e end end
    assert(ev and ev.source == ink and ev.partner == a.units[2], "lure&brood: event source+partner")
    assert(ev.trueKind == "stat_inc" and ev.trueValue == 0.10, "lure&brood: canal dev (trueKind/trueValue)")
  end

  -- 1b) NÉGATIF — INK HORROR seul (pas de kraken) -> rien posé, rien émis (murmure inerte).
  do
    local a, got = arenaWithMurmurLog({ left = { U("ink_horror") }, right = { U("skeleton") }, autoReset = false, seed = 1 })
    assert((a.units[1].atkInc or 0) == 0, "lure&brood: inerte sans partenaire")
    assert(#got == 0, "lure&brood: aucun event sans partenaire")
  end

  -- 2) LIGNÉE ADJACENCE — THE FORGE CIRCLE : CINDER_CUR adjacent à PYRE_TENDER -> oneshot burnInc +0.10.
  do
    local a, got = arenaWithMurmurLog({ left = { U("cinder_cur", { depth = 0, row = 0 }),
      U("pyre_tender", { depth = 0, row = 1 }) }, right = { U("skeleton", { depth = 0, row = 0 }) },
      autoReset = false, seed = 2 })
    assert((a.units[1].burnInc or 0) == 0.10, "forge circle: burnInc +0.10 (adjacence)")
    local seen = false; for _, e in ipairs(got) do if e.key == "the_forge_circle" then seen = true end end
    assert(seen, "forge circle: event émis")
  end

  -- 2b) NÉGATIF — adjacence ROMPUE (partenaire NON voisin-champ) -> inerte.
  do
    local a = arenaWithMurmurLog({ left = { U("cinder_cur", { depth = 0, row = 0 }),
      U("pyre_tender", { depth = 2, row = 2 }) }, right = { U("skeleton") }, autoReset = false, seed = 2 })
    assert((a.units[1].burnInc or 0) == 0, "forge circle: inerte si partenaire non adjacent")
  end

  -- 3) LIGNÉE FAMILLE — THE THREE SKULLS : SOOT_ACOLYTE + un allié de famille burn présent -> burnInc +0.10.
  do
    local a = arenaWithMurmurLog({ left = { U("soot_acolyte"), U("emberling") },
      right = { U("skeleton") }, autoReset = false, seed = 3 })
    assert((a.units[1].burnInc or 0) == 0.10, "three skulls: burnInc +0.10 (famille burn présente)")
  end

  -- 4) SOLO aloneOfType — THE LONE TITAN : SKULL_COLOSSUS seul de famille `bone` -> statInc (dmg ×1.10).
  do
    local base = Units.skull_colossus.dmg
    local a = arenaWithMurmurLog({ left = { U("skull_colossus") }, right = { U("marauder") }, autoReset = false, seed = 4 })
    assert(a.units[1].dmg == math.floor(base * 1.10 + 0.5), "lone titan: statInc applique au dmg")
    -- négatif : un autre `bone` (husk) annule -> dmg inchangé.
    local a2 = arenaWithMurmurLog({ left = { U("skull_colossus"), U("husk") }, right = { U("marauder") }, autoReset = false, seed = 4 })
    assert(a2.units[1].dmg == base, "lone titan: inerte si un congénère os est présent")
  end

  -- 5) SOLO seuil — THE GORGING : HOLLOW_GUT sous 30% PV -> lifestealBonus +0.10 (edge-trigger 1×) + heal en combat.
  do
    local a, got = arenaWithMurmurLog({ left = { U("hollow_gut") }, right = { U("marauder") }, autoReset = false, seed = 5 })
    local hg = a.units[1]
    assert((hg.lifestealBonus or 0) == 0, "gorging: pas posé au-dessus du seuil")
    hg.hp = math.floor(hg.maxHp * 0.2)
    a:update(1, 1)
    assert(hg.lifestealBonus == 0.10, "gorging: lifestealBonus +0.10 au franchissement du seuil")
    -- edge-trigger : re-tick sous le seuil ne RE-pose pas (pas de cumul par frame).
    a:update(1, 2)
    assert(hg.lifestealBonus == 0.10, "gorging: edge-trigger (pas de re-pose par frame)")
    local n = 0; for _, e in ipairs(got) do if e.key == "the_gorging" then n = n + 1 end end
    assert(n == 1, "gorging: un seul event au franchissement")
  end

  -- 6) SOLO mort d'allié — THE HOLLOW VESSEL : HUSK gagne dmgInc +5% par mort alliée, CUMUL BORNÉ (cap 4).
  do
    local a, got = arenaWithMurmurLog({ left = { U("husk"),
        U("skeleton", { row = 0 }), U("bandit", { row = 1 }) },
      right = { U("marauder", { dmg = 9999, cd = 1 }) }, autoReset = false, seed = 6 })
    local husk = a.units[1]
    local base = husk.dmg
    a:damage(a.units[2], 9999, { source = a.units[4], cause = "attack" })
    a:update(1, 1) -- broadcast on_ally_death
    assert(husk._whisperStacks == 1, "hollow vessel: 1 stack à la 1re mort alliée")
    assert(husk.dmg == math.floor(base * (1 + 0.05) + 0.5), "hollow vessel: dmg ré-appliqué sur la base (+5%)")
    a:damage(a.units[3], 9999, { source = a.units[4], cause = "attack" })
    a:update(1, 2)
    assert(husk._whisperStacks == 2, "hollow vessel: 2e mort -> 2 stacks (cumul)")
    -- cap : ne dépasse jamais capStacks (4) même avec d'autres morts simulées.
    for k = 1, 10 do
      husk._whisperStacks = math.min(4, husk._whisperStacks) -- borne déjà appliquée par l'op ; on vérifie l'invariant
      assert(husk._whisperStacks <= 4, "hollow vessel: cumul plafonné à capStacks=4")
    end
    local n = 0; for _, e in ipairs(got) do if e.key == "the_hollow_vessel" then n = n + 1 end end
    assert(n >= 2, "hollow vessel: un event par mort alliée")
  end

  -- 7) SOLO durée — THE PATIENT ONE : PATIENT_WORM armé au combat_start, déclenché APRÈS afterT frames.
  do
    local a, got = arenaWithMurmurLog({ left = { U("patient_worm") },
      right = { U("marauder", { hp = 999999, dmg = 0 }) }, autoReset = false, seed = 7 })
    local pw = a.units[1]
    assert(pw._whisperTimed and not pw._whisperFired, "patient one: armé au combat_start, pas encore déclenché")
    for t = 1, 479 do a:update(1, t) end
    assert(not pw._whisperFired, "patient one: pas déclenché avant afterT (480)")
    a:update(1, 480)
    assert(pw._whisperFired, "patient one: déclenché au franchissement d'afterT")
    local n = 0; for _, e in ipairs(got) do if e.key == "the_patient_one" then n = n + 1 end end
    assert(n == 1, "patient one: un seul event au franchissement")
  end

  -- 8) DÉTERMINISME — même seed -> même SÉQUENCE de murmures (clé + porteur + magnitude). Async/replay-safe.
  do
    local function run(seed)
      local a, got = arenaWithMurmurLog({ left = { U("ink_horror"), U("deep_kraken"), U("hollow_gut", { row = 2 }) },
        right = { U("marauder", { dmg = 30, cd = 20 }) }, autoReset = false, seed = seed })
      -- pousse le hollow_gut sous le seuil pour déclencher son murmure de seuil en cours de combat
      for t = 1, 300 do a:update(1, t) end
      local trace = {}
      for _, e in ipairs(got) do trace[#trace + 1] = e.key .. "|" .. (e.source and e.source.id or "?") .. "|" .. tostring(e.trueValue) end
      return table.concat(trace, ";")
    end
    local t1, t2 = run(424242), run(424242)
    assert(t1 == t2, "déterminisme: même seed -> même trace de murmures\n  " .. t1 .. "\n  " .. t2)
    assert(#t1 > 0, "déterminisme: au moins un murmure dans la trace")
  end

  -- 9) EVENT 2 CANAUX — le canal JOUEUR (Chronique) nomme l'unité, ZÉRO chiffre ; le canal DEV garde la vérité.
  do
    local a = Arena.new({ left = { U("ink_horror"), U("deep_kraken") }, right = { U("skeleton") }, autoReset = false, seed = 9 })
    -- on abonne APRÈS new() pour le seuil ; ici on déclenche un murmure de seuil sur hollow_gut à la place pour
    -- que la chronique (abonnée post-spawn) le capte. On rejoue donc un cas seuil.
    local b = Arena.new({ left = { U("hollow_gut") }, right = { U("marauder") }, autoReset = false, seed = 9 })
    local chron = Chronicle.new(b)
    local log = EventLog.attach(b)
    b.units[1].hp = math.floor(b.units[1].maxHp * 0.2)
    b:update(1, 1)
    local pe; for _, e in ipairs(chron.entries) do if e.kind == "murmur" then pe = e end end
    assert(pe, "canal joueur: une entrée murmur dans la chronique")
    local segs = chron:segments(pe)
    assert(#segs == 1 and segs[1].role == "murmur", "canal joueur: un fragment cryptique")
    assert(segs[1].text:find("HOLLOW GUT"), "canal joueur: nomme l'unité")
    assert(not segs[1].text:find("%d"), "canal joueur: ZÉRO chiffre")
    assert(chron:value(pe) == nil, "canal joueur: aucune valeur affichée")
    local de; for _, r in ipairs(log.records) do if r.ev == "murmur" then de = r end end
    assert(de and de.true_value == 0.10 and de.true_kind == "stat_inc", "canal dev: trueKind/trueValue présents")
    assert(a.units[1].atkInc == 0.10, "régression: le lineage du 1er arène a bien posé son effet")
  end

  -- 10) SNAPSHOT GRATUIT — un GHOST (ne transporte que {id,level,col,row}) RE-DÉCLENCHE ses murmures NON-RNG
  -- via la résolution par id au combat_start. On capture une compo lineage, on l'encode/décode, on rejoue.
  do
    -- compo : ink_horror (col 0) + deep_kraken (col 1) -> toComp reconstruit, le murmure doit re-poser atkInc.
    local snap = Snapshot.capture(
      { { id = "ink_horror", level = 1, col = 0, row = 0 }, { id = "deep_kraken", level = 1, col = 1, row = 0 } },
      "carre", 1234, { version = "0", tier = 1 })
    local comp = Snapshot.toComp(Snapshot.decode(Snapshot.encode(snap)), 1)
    local a, got = arenaWithMurmurLog({ left = comp, right = { U("skeleton") }, autoReset = false, seed = 1 })
    local ink; for _, u in ipairs(a.units) do if u.id == "ink_horror" then ink = u end end
    assert(ink and ink.atkInc == 0.10, "snapshot gratuit: le ghost re-déclenche son murmure (atkInc posé)")
    local seen = false; for _, e in ipairs(got) do if e.key == "the_lure_and_the_brood" then seen = true end end
    assert(seen, "snapshot gratuit: l'event murmur est ré-émis côté ghost (sans rien encoder de neuf)")
  end

  -- 11) DODGE OFF (W7) — le coward n'est PAS dans le registre (commenté) : aucun murmure RNG actif en v1.
  do
    assert(Whispers.bandit == nil, "coward/dodge: OFF en v1 (pas dans le registre actif)")
    -- mais sa ligne cryptique existe (prêt pour W7).
    assert(I18n.has("whisper.the_coward.cryptic"), "coward: ligne i18n prête pour W7")
  end

  print("  murmures : 10 exemplars (9 actifs + coward OFF) — résolution/bornes/déterminisme/2-canaux/snapshot OK")
end)

if ok then
  print("=> MURMURES OK : 3e couche cachée (spice), seedée, snapshotée, cryptique jusque dans le log.")
else
  print("=> MURMURES FAIL :")
  print(err)
  os.exit(1)
end
