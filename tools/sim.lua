-- tools/sim.lua
-- BATCH SIM d'équilibrage : joue N matchups (deux builds aléatoires symétriques, auras des deux
-- côtés) et agrège des statistiques exploitables :
--   · win-rate par unité (créditée si elle est dans la compo gagnante — méthode Ludus)
--   · dégâts infligés par unité (source) et par cause (attack/poison/burn/bleed/rot/thorns…)
--   · part des dégâts portée par les ALTÉRATIONS vs la frappe directe (santé du système d'effets)
--   · TTK : moyenne ET distribution (p10/p50/p90 — révèle les combats dégénérés)
--   · LIFT de co-occurrence (détecteur de COMBOS) : paires qui gagnent bien plus que la moyenne
--     des win-rates solo de leurs membres = synergie voulue… ou CASSÉE (à inspecter)
--   · DRAPEAUX d'équilibrage : unités hors bande [0.45, 0.55] (liste actionnable pour la passe P5)
--   · SANTÉ MÉTA : écart-type et entropie normalisée du vecteur de win-rate (haut = équilibré)
-- Écrit runs/report.json (diff-able). Déterministe : même N -> même rapport.
--
--   Lancement : luajit tools/sim.lua [N]      (N defaut 400)
--
-- ── MOTEUR DE SCÉNARIOS (Phase C.0) — DRIVER UNIFIÉ : `luajit tools/sim.lua <mode> [N]`. Si arg[1] est un
-- MODE connu, on DÉLÈGUE au scénario dédié (tools/scenarios/<mode>) et on s'arrête AVANT le code P0 ci-dessous.
-- Sinon (arg[1] absent ou numérique), comportement HISTORIQUE = P0 méta (builds aléatoires symétriques) intact
-- -> runs/report.json + golden de méta inchangés. Les modes sont SIM-purs, seedés, déterministes, diff-ables. ──
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local MODES = {
  invest = true, policy = true, godroll = true, commander = true,
  counter = true, economy = true, tank = true, pacing = true, sweep = true,
  coherence = true, mechanics = true, bossrush = true, bossrush_run = true,
}
local mode = arg and arg[1]
if mode and MODES[mode] then
  require("tools.scenarios." .. mode) -- chaque scénario s'exécute à l'import (lit arg[2] = N via tools.scenarios.argn)
  return
end

local Palette = require("src.core.palette")
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Match = require("src.combat.match")
local Build = require("src.scenes.build")
local EventLog = require("tools.eventlog")

local N = tonumber(arg and arg[1]) or 400
local BASE_SEED = 700000
local TICK_CAP = 8000
local HPM = tonumber(os.getenv("PIT_HP_MULT")) -- bouton global de PV : sweep `PIT_HP_MULT=N` (sinon constante Arena.HP_MULT)
local gen = love.math.newRandomGenerator(13579) -- generateur de scenarios seede -> rapport reproductible

-- Causes de dégâts qui sont des ALTÉRATIONS (DoT/statuts) — par opposition à la frappe directe.
-- (le choc a désormais sa cause propre : la DÉCHARGE du condensateur émet une instance cause="shock").
local STATUS_CAUSES = { poison = true, burn = true, bleed = true, rot = true, shock = true }

-- ── Build aléatoire valide (forme, slots débloqués, unités posées) ──
local function randomBuild()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape(Shapes.order[gen:random(1, #Shapes.order)]); b:computeLayout()
  b.board:unlock(gen:random(3, 9))
  for _ = 1, gen:random(2, 9) do
    local slot = gen:random(1, 9)
    if b.board.slots[slot] and b.board.slots[slot].unlocked then
      b:placeId(slot, Units.order[gen:random(1, #Units.order)])
    end
  end
  return b
end

local function buildSide(side)
  local b = randomBuild()
  local comp = b:buildComp(side)
  if #comp == 0 then -- garantit au moins une unité
    b:placeId(5, Units.order[gen:random(1, #Units.order)])
    comp = b:buildComp(side)
  end
  return comp
end

-- ── Agrégats ──
local stat = {} -- [id] = { appear, wins, dmg }
local function S(id) local s = stat[id]; if not s then s = { appear = 0, wins = 0, dmg = 0 }; stat[id] = s end; return s end
local causeDmg = {}
-- MURMURES (3e couche cachée — canal DEV) : on agrège leur FRÉQUENCE par key (combien de fois chaque
-- murmure se résout) + le set des PORTEURS. Le but est de PROUVER que c'est du SPICE : ils se déclenchent
-- (système vivant), mais leurs porteurs ne deviennent pas des outliers de win% (>2σ). cf. murmures-plan.md §6.
local murmurCount = {} -- [key] = nb d'émissions ; murmurCarrier[id] = true (porteur d'au moins un murmure)
local murmurCarrier = {}
local ttkSum, decided = 0, 0
local ttks = {}     -- échantillons de TTK -> percentiles (pas seulement la moyenne)
local pairData = {} -- [key] = {a,b,appear,wins} : co-occurrence de paires DISTINCTES -> lift (combos)

-- Clé canonique d'une paire non-ordonnée (a<b) ; \0 ne peut apparaître dans un id (anti-collision).
local function pkey(a, b) if a > b then a, b = b, a end return a, b, a .. "\0" .. b end
local function addPairs(ids, won)
  local seen, distinct = {}, {}
  for _, id in ipairs(ids) do if not seen[id] then seen[id] = true; distinct[#distinct + 1] = id end end
  for i = 1, #distinct do
    for j = i + 1, #distinct do
      local a, b, k = pkey(distinct[i], distinct[j])
      local pd = pairData[k]
      if not pd then pd = { a = a, b = b, appear = 0, wins = 0 }; pairData[k] = pd end
      pd.appear = pd.appear + 1
      if won then pd.wins = pd.wins + 1 end
    end
  end
end

-- ════════ C6 — VÉRIF de COMBO COMMANDANT (priorité #1, commanders-plan §6.3) ════════
-- Couronne d'Échos (cmd, multicast role:front) × echo_crown (relique, multicast role:front) × hookjaw (unité,
-- multicast role:front) = 3 sources de +1 sur le MÊME carry avant. Le cap MULTICAST_MAX=3 doit TENIR (1+1+1=3,
-- pas 4+). On résout le build (board hookjaw au front + commandant Couronne + relique echo_crown) et on vérifie
-- que le sous-coup au front est borné à 3 ET que le combat conclut SANS one-shot dégénéré.
do
  local Relics = require("src.data.relics")
  local Arena = require("src.combat.arena")
  local b = Build.new(Palette, 320, 180, { goto = function() end, run = { relics = { { id = "echo_crown" } }, commanderUnlocked = true, slots = 9,
    applyRelics = function(self, comp) for _, r in ipairs(self.relics) do Relics.apply(comp, Relics[r.id]) end end } })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  b:placeId(3, "hookjaw")  -- col 2 (front) -> role:front ; porte lui-même un aura_stat multicast role:front
  b:placeId(6, "marauder"); b:placeId(9, "marauder") -- de la chair pour que le combat dure
  b.commanderSlot = { id = "maggot_king", level = 1, char = nil } -- LA COURONNE D'ÉCHOS au piédestal
  local comp = b:buildComp(-1)
  b.host.run:applyRelics(comp) -- echo_crown : +1 multicast au front (post-buildComp, comme en jeu)
  -- somme des sources de multicast sur le front : hookjaw(1) + Couronne(1) + echo_crown(1) = 3 (cap atteint).
  local front
  for _, s in ipairs(comp) do if (s.multicast or 0) > 0 and not s.isCommander then if not front or (s.depth or 0) < (front.depth or 0) then front = s end end end
  assert(front, "C6 combo: une unité avant porte du multicast")
  assert(front.multicast == 3, "C6 combo: 3 sources -> multicast 3 sur le front (obtenu " .. tostring(front.multicast) .. ")")
  -- combat : le carry au cap MULTICAST_MAX=3 ne doit PAS one-shot (chaque sous-coup borné HIT_DMG_CAP_MULT).
  local foe = {}
  for i = 1, 3 do foe[i] = { id = "templar", hp = 200, dmg = 8, cd = 60, depth = i - 1, row = 0, x = 200, y = 96, facing = -1 } end
  local arena = Arena.new({ left = comp, right = foe, autoReset = false, seed = 999 })
  local n, oneShot = 0, false
  local firstHp = {}
  for _, u in ipairs(arena.units) do if u.team == "right" then firstHp[u] = u.hp end end
  for i = 1, 8000 do
    arena:update(1.0, i); n = i
    if arena.over then break end
  end
  assert(arena.over, "C6 combo: le combat conclut (pas de boucle infinie sous le cap multicast)")
  print(string.format("  [C6] Couronne×echo_crown×hookjaw : multicast front = %d (cap %d) ; combat conclu en %d ticks, win=%s",
    front.multicast, Arena.MULTICAST_MAX, n, tostring(arena.win)))
end

for run = 1, N do
  local left = buildSide(-1)
  local right = buildSide(1)
  local res = Match.run(left, right, BASE_SEED + run, {
    tickCap = TICK_CAP, hpMult = HPM,
    attach = function(a) return EventLog.attach(a) end,
    expose = true,
  })
  local arena, log, ticks = res.arena, res.log, res.ticks

  local leftIds, rightIds = {}, {}
  for _, u in ipairs(left) do leftIds[#leftIds + 1] = u.id; S(u.id).appear = S(u.id).appear + 1 end
  for _, u in ipairs(right) do rightIds[#rightIds + 1] = u.id; S(u.id).appear = S(u.id).appear + 1 end

  if arena.over then
    decided = decided + 1
    ttkSum = ttkSum + ticks
    ttks[#ttks + 1] = ticks
    local winners = arena.win and leftIds or rightIds
    for _, id in ipairs(winners) do S(id).wins = S(id).wins + 1 end
    addPairs(leftIds, arena.win)        -- crédite la victoire au côté gagnant
    addPairs(rightIds, not arena.win)
  end

  for _, r in ipairs(log.records) do
    if r.ev == "damage" and r.hp and r.hp > 0 then
      if r.src then S(r.src).dmg = S(r.src).dmg + r.hp end
      causeDmg[r.cause or "?"] = (causeDmg[r.cause or "?"] or 0) + r.hp
    elseif r.ev == "murmur" then -- canal dev : un murmure s'est résolu (frequence + porteur)
      murmurCount[r.key or "?"] = (murmurCount[r.key or "?"] or 0) + 1
      if r.src then murmurCarrier[r.src] = true end
    end
  end
end

-- ── Santé méta : écart-type + entropie normalisée du vecteur de win-rate ──
local winrates, totalDmg = {}, 0
for _, id in ipairs(Units.order) do
  local s = stat[id]
  if s and s.appear > 0 then winrates[#winrates + 1] = s.wins / s.appear end
  if s then totalDmg = totalDmg + s.dmg end
end
local mean = 0
for _, w in ipairs(winrates) do mean = mean + w end
mean = (#winrates > 0) and (mean / #winrates) or 0
local var = 0
for _, w in ipairs(winrates) do var = var + (w - mean) ^ 2 end
local stddev = (#winrates > 0) and math.sqrt(var / #winrates) or 0
-- entropie normalisée de la distribution des win-rates (1 = parfaitement uniforme = sain)
local sumw = 0
for _, w in ipairs(winrates) do sumw = sumw + w end
local entropy = 0
if sumw > 0 and #winrates > 1 then
  for _, w in ipairs(winrates) do
    local p = w / sumw
    if p > 0 then entropy = entropy - p * math.log(p) end
  end
  entropy = entropy / math.log(#winrates)
end
local avgTTK = (decided > 0) and (ttkSum / decided) or 0

-- ── Distribution des TTK (percentiles) : révèle les combats dégénérés (trop courts = burst / trop
-- longs = sustain non concluant). Médiane + queues p10/p90. ──
table.sort(ttks)
local function pct(q)
  if #ttks == 0 then return 0 end
  return ttks[math.min(#ttks, math.max(1, math.floor((#ttks - 1) * q + 0.5) + 1))]
end
local ttkP10, ttkP50, ttkP90 = pct(0.10), pct(0.50), pct(0.90)

-- ── Part des dégâts par ALTÉRATION vs frappe directe (santé du système d'effets : trop bas = effets
-- décoratifs ; trop haut = la frappe ne compte plus). ──
local statusDmg = 0
for cause, d in pairs(causeDmg) do if STATUS_CAUSES[cause] then statusDmg = statusDmg + d end end
local statusShare = (totalDmg > 0) and (statusDmg / totalDmg) or 0

-- ── LIFT de co-occurrence (DÉTECTEUR DE COMBOS) : pour chaque paire vue ensemble >= seuil, on compare
-- son win-rate joint à la MOYENNE des win-rates solo de ses deux membres. lift >> 1 = la paire
-- sur-performe ce que ses unités font seules => synergie (voulue ou CASSÉE) ; lift << 1 = anti-synergie.
-- La normalisation par la moyenne solo neutralise « portée par une unité forte ». Signal à confirmer
-- à grand N (peu d'échantillons par paire = bruyant). ──
-- Seuil d'échantillon : BAS pour un grand pool (sur ~47 unités une paire ne co-occurre que ~N/90 fois ;
-- un seuil en N/25 désactiverait le détecteur). On vise ~25-130 co-occurrences -> lift = signal à confirmer.
local PAIR_MIN = math.max(20, math.floor(N / 150))
local function wrOf(id) local s = stat[id]; return (s and s.appear > 0) and s.wins / s.appear or 0 end
local pairRows = {}
for _, pd in pairs(pairData) do
  if pd.appear >= PAIR_MIN then
    local pwr = pd.wins / pd.appear
    local exp = (wrOf(pd.a) + wrOf(pd.b)) / 2
    pairRows[#pairRows + 1] = { a = pd.a, b = pd.b, appear = pd.appear, pwr = pwr,
      lift = (exp > 0) and (pwr / exp) or 0 }
  end
end
table.sort(pairRows, function(x, y)
  if x.lift ~= y.lift then return x.lift > y.lift end
  if x.a ~= y.a then return x.a < y.a end
  return x.b < y.b
end)

-- ── Rapport console (trié par win-rate décroissant) ──
local rows = {}
for _, id in ipairs(Units.order) do
  local s = stat[id] or { appear = 0, wins = 0, dmg = 0 }
  rows[#rows + 1] = { id = id, appear = s.appear, wins = s.wins,
    wr = (s.appear > 0) and (s.wins / s.appear) or 0,
    dmg = s.dmg, share = (totalDmg > 0) and (s.dmg / totalDmg) or 0 }
end
table.sort(rows, function(a, b) if a.wr ~= b.wr then return a.wr > b.wr end return a.id < b.id end)

-- ── Drapeaux d'équilibrage (actionnable pour la passe P5) : unités OUTLIERS du champ. ATTENTION : le
-- win% ici = « présence sur le côté gagnant », crédité à TOUTES les unités du vainqueur -> son centre
-- naturel est la MOYENNE du champ (tirée vers le haut car les grosses compos gagnent plus), PAS 0.50.
-- On flague donc l'écart à la moyenne (en σ), pas une bande absolue qui flaguerait tout le monde. ──
local BAND = math.max(0.08, 1.5 * stddev)
local FLOOR, CEIL = mean - BAND, mean + BAND
local FLAG_MIN_APPEAR = math.max(20, math.floor(N / 10))
local flags = {}
for _, r in ipairs(rows) do
  if r.appear >= FLAG_MIN_APPEAR and (r.wr < FLOOR or r.wr > CEIL) then
    flags[#flags + 1] = { id = r.id, wr = r.wr, kind = (r.wr < FLOOR) and "FAIBLE" or "FORTE",
      dev = (stddev > 0) and (r.wr - mean) / stddev or 0 }
  end
end

print(string.format("== BATCH SIM : %d combats (%d decides), TTK moyen %.0f ticks ==", N, decided, avgTTK))
print(string.format("%-12s %7s %7s %9s %9s", "unite", "appar.", "win%", "degats", "part%"))
for _, r in ipairs(rows) do
  print(string.format("%-12s %7d %6.1f%% %9d %8.1f%%", r.id, r.appear, r.wr * 100, r.dmg, r.share * 100))
end

print("degats par cause :")
local causeKeys = {}
for k in pairs(causeDmg) do causeKeys[#causeKeys + 1] = k end
table.sort(causeKeys)
for _, k in ipairs(causeKeys) do
  print(string.format("  %-8s %9d (%.1f%%)", k, causeDmg[k], totalDmg > 0 and causeDmg[k] / totalDmg * 100 or 0))
end
print(string.format("  -> alterations (DoT) = %.1f%% des degats | frappe directe = %.1f%%",
  statusShare * 100, (1 - statusShare) * 100))

print(string.format("TTK : p10 %.0f | mediane %.0f | p90 %.0f ticks (combats decides)", ttkP10, ttkP50, ttkP90))

-- combos : top (synergies) + bottom (anti-synergies), seuil d'echantillon PAIR_MIN
print(string.format("combos (lift, appar.>=%d) — top synergies :", PAIR_MIN))
local shown = 0
for _, p in ipairs(pairRows) do
  if shown >= 8 then break end
  print(string.format("  %-12s + %-12s  lift %.2f  (win %.1f%% sur %d)", p.a, p.b, p.lift, p.pwr * 100, p.appear))
  shown = shown + 1
end
if #pairRows == 0 then
  print(string.format("  (aucune paire >= %d co-occurrences — pool large : augmenter N pour nourrir le detecteur)", PAIR_MIN))
end
if #pairRows > 8 then
  print("  … anti-synergies (lift le plus bas) :")
  for i = #pairRows, math.max(1, #pairRows - 3), -1 do
    local p = pairRows[i]
    print(string.format("  %-12s + %-12s  lift %.2f  (win %.1f%% sur %d)", p.a, p.b, p.lift, p.pwr * 100, p.appear))
  end
end

if #flags > 0 then
  print(string.format("DRAPEAUX (outliers du champ : moyenne %.3f +- %.3f) :", mean, BAND))
  for _, f in ipairs(flags) do
    print(string.format("  [%-6s] %-12s win %.1f%% (%+.1f sigma)", f.kind, f.id, f.wr * 100, f.dev))
  end
else
  print(string.format("DRAPEAUX : aucun (toutes les unites dans moyenne %.3f +- %.3f).", mean, BAND))
end

print(string.format("sante meta : ecart-type win-rate = %.3f (bas = equilibre) | entropie = %.3f (haut = sain)",
  stddev, entropy))

-- ── MURMURES : VERDICT de SPICE (le murmure est-il bien marginal, jamais build-defining ?). On vérifie
-- (a) que le système est VIVANT (au moins un murmure émis sur le batch), et (b) qu'aucun PORTEUR de murmure
-- n'est un outlier de win% au-delà de ±2σ du champ. Un murmure qui ferait basculer le win% de son porteur
-- se verrait ICI (déviation σ élevée) — exactement le détecteur d'« easter egg cassé ». cf. plan §6. ──
local murmurKeys = {}
for k in pairs(murmurCount) do murmurKeys[#murmurKeys + 1] = k end
table.sort(murmurKeys)
local totalMurmurs = 0
for _, k in ipairs(murmurKeys) do totalMurmurs = totalMurmurs + murmurCount[k] end
local devOf = {} -- [id] = déviation σ du win% (réutilise mean/stddev du champ)
for _, r in ipairs(rows) do devOf[r.id] = (stddev > 0) and (r.wr - mean) / stddev or 0 end
local murmurOutliers = {}
local carrierIds = {} -- ids des PORTEURS effectivement résolus dans le batch
for id in pairs(murmurCarrier) do carrierIds[#carrierIds + 1] = id end
table.sort(carrierIds)
for _, id in ipairs(carrierIds) do
  local d = devOf[id] or 0
  if math.abs(d) > 2.0 and (stat[id] and stat[id].appear or 0) >= FLAG_MIN_APPEAR then
    murmurOutliers[#murmurOutliers + 1] = { id = id, dev = d }
  end
end
print(string.format("murmures (3e couche cachee) : %d emissions sur %d combats (%d keys distinctes) :",
  totalMurmurs, N, #murmurKeys))
for _, k in ipairs(murmurKeys) do
  print(string.format("  %-26s x%-5d", k, murmurCount[k]))
end
if #murmurKeys == 0 then
  print("  (aucun murmure emis — augmenter N ou verifier les porteurs dans Units.order)")
end
if #murmurOutliers == 0 then
  print("  -> SPICE OK : aucun porteur de murmure n'est outlier de win% (>2 sigma) => marginal, jamais build-defining.")
else
  print("  -> ATTENTION : porteur(s) de murmure outlier(s) de win% (>2 sigma) — a inspecter (spice trop fort ?) :")
  for _, o in ipairs(murmurOutliers) do print(string.format("     %-12s (%+.1f sigma)", o.id, o.dev)) end
end

-- ── report.json (clés triées -> diff-able) ──
local function num(v) if v == math.floor(v) then return string.format("%d", v) else return string.format("%.4f", v) end end
local parts = {}
parts[#parts + 1] = string.format('"n":%d,"decided":%d,"avg_ttk":%s', N, decided, num(avgTTK))
parts[#parts + 1] = string.format('"ttk_p10":%s,"ttk_p50":%s,"ttk_p90":%s', num(ttkP10), num(ttkP50), num(ttkP90))
parts[#parts + 1] = string.format('"meta_stddev":%s,"meta_entropy":%s,"field_mean":%s', num(stddev), num(entropy), num(mean))
parts[#parts + 1] = string.format('"status_dmg_share":%s', num(statusShare))
local unitParts = {}
for _, r in ipairs(rows) do
  unitParts[#unitParts + 1] = string.format(
    '"%s":{"appear":%d,"wins":%d,"winrate":%s,"dmg":%d,"dmg_share":%s}',
    r.id, r.appear, r.wins, num(r.wr), r.dmg, num(r.share))
end
table.sort(unitParts)
parts[#parts + 1] = '"units":{' .. table.concat(unitParts, ",") .. "}"
local causeParts = {}
for _, k in ipairs(causeKeys) do causeParts[#causeParts + 1] = string.format('"%s":%d', k, causeDmg[k]) end
parts[#parts + 1] = '"cause_dmg":{' .. table.concat(causeParts, ",") .. "}"
-- combos : on sérialise les paires au-dessus du seuil (déjà triées par lift décroissant)
local comboParts = {}
for _, p in ipairs(pairRows) do
  comboParts[#comboParts + 1] = string.format('{"a":"%s","b":"%s","appear":%d,"winrate":%s,"lift":%s}',
    p.a, p.b, p.appear, num(p.pwr), num(p.lift))
end
parts[#parts + 1] = '"combos":[' .. table.concat(comboParts, ",") .. "]"
local flagParts = {}
for _, f in ipairs(flags) do
  flagParts[#flagParts + 1] = string.format('{"id":"%s","winrate":%s,"kind":"%s","sigma":%s}',
    f.id, num(f.wr), f.kind, num(f.dev))
end
parts[#parts + 1] = string.format('"flag_band":{"mean":%s,"band":%s},', num(mean), num(BAND))
  .. '"flags":[' .. table.concat(flagParts, ",") .. "]"
-- MURMURES (canal dev) : fréquence par key + porteurs outliers (vide = spice sain).
local murmurParts = {}
for _, k in ipairs(murmurKeys) do murmurParts[#murmurParts + 1] = string.format('"%s":%d', k, murmurCount[k]) end
local moParts = {}
for _, o in ipairs(murmurOutliers) do moParts[#moParts + 1] = string.format('{"id":"%s","sigma":%s}', o.id, num(o.dev)) end
parts[#parts + 1] = '"murmurs":{"emissions":' .. totalMurmurs
  .. ',"by_key":{' .. table.concat(murmurParts, ",") .. "}"
  .. ',"outliers":[' .. table.concat(moParts, ",") .. "]}"
local json = "{" .. table.concat(parts, ",") .. "}\n"

os.execute("mkdir -p runs")
local f = io.open("runs/report.json", "w")
if f then f:write(json); f:close(); print("=> ecrit runs/report.json") else print("(!) impossible d'ecrire runs/report.json") end

-- ── GOLDEN DE MÉTA (Phase C.0) : le P0 contribue son RÉSUMÉ compact (santé globale) au runs/report-ref.json
-- agrégé multi-modes -> un diff patch-sur-patch montre la dérive de la méta (entropie qui chute = méta qui se
-- referme ; nouveaux drapeaux). N'altère PAS runs/report.json (le rapport détaillé P0 historique reste intact). ──
do
  local Common = require("tools.scenarios.common")
  Common.updateRef("meta", {
    n = N, meta_stddev = stddev, meta_entropy = entropy, field_mean = mean,
    avg_ttk = avgTTK, ttk_p10 = ttkP10, ttk_p50 = ttkP50, ttk_p90 = ttkP90,
    status_dmg_share = statusShare, flag_count = #flags,
  })
  print("=> contribue le resume meta a runs/report-ref.json")
end
