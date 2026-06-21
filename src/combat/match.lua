-- src/combat/match.lua
-- RUNNER DE MATCH headless — couche SIM PURE (aucun love.graphics ; love.math via Arena uniquement).
-- Factorise la boucle « construit l'arène -> tick jusqu'à conclusion » dupliquée dans tools/sim.lua,
-- tests/golden.lua, tests/props.lua. Réutilisé par : le batch d'équilibrage (sim), le golden, le banc
-- d'essai (Proving Ground SIM ×N) et le pilote de run headless (rundriver). Un seul endroit où vit la
-- sémantique « un combat = N ticks d'arène + verdict ».
--
-- DÉCOUPLAGE event-log : match.lua ne require PAS tools/eventlog (src/ ne doit pas dépendre de tools/, et
-- on reste sous le firewall). L'appelant fournit `opts.attach(arena) -> handle`, appelé JUSTE après la
-- construction (comme le code d'origine, qui attache après Arena.new -> l'événement "spawned" n'est pas
-- capturé) ; le handle est renvoyé via res.log quand `opts.expose`.
--
-- VERDICT : si l'arène conclut (un camp à 0), `win = arena.win`, `decided = true`. Sinon (plafond de
-- ticks atteint sans conclusion — rare depuis la Fatigue), JUGE au temps-limite : gagnant = plus grande
-- fraction de PV restante ; `decided = false` (l'analyse distingue les vraies victoires des verdicts).

local Arena = require("src.combat.arena")

local Match = {}

-- Somme des fractions de PV (hp/maxHp) restantes par camp. Pure (lit l'arène, ne touche pas les compos).
function Match.hpFrac(arena)
  local l, r = 0, 0
  for _, u in ipairs(arena.units) do
    if u.maxHp and u.maxHp > 0 then
      local f = (u.alive and u.hp or 0) / u.maxHp
      if u.team == "left" then l = l + f else r = r + f end
    end
  end
  return l, r
end

-- Juge au temps-limite : gagnant = plus grande fraction de PV restante. Égalité -> false (right gagne),
-- miroir de l'asymétrie `win = (right==0 and left>0)` de l'arène (un nul n'est pas une victoire de left).
-- Partagé avec la scène combat (fin par plafond de ticks d'un match d'exhibition).
function Match.judge(arena)
  local l, r = Match.hpFrac(arena)
  return l > r
end

-- Joue un combat headless. SIM-pur.
--   left, right : compos (arrays de specs d'unités) ; seed : entier.
--   opts = { tickCap=8000, attach?(arena)->handle, expose?, fatigue?, hpMult?, judge=true, assertPure? }
-- Retour : { win, decided, ticks, hpFrac = { left, right } [, arena, log si expose] }.
function Match.run(left, right, seed, opts)
  opts = opts or {}
  local tickCap = opts.tickCap or 8000

  -- assertPure : capture d'invariants d'entrée pour PROUVER l'absence de mutation des compos (l'arène est
  -- censée traiter les specs en lecture seule -> compos réutilisables sur N matchs, cf. SIM ×N du lab).
  local n0L, n0R, h0
  if opts.assertPure then n0L, n0R = #left, #right; h0 = left[1] and left[1].hp end

  local arena = Arena.new({ left = left, right = right, autoReset = false, seed = seed,
    fatigue = opts.fatigue, hpMult = opts.hpMult }) -- hpMult : bouton global de PV (sinon constante d'arena)
  local log = opts.attach and opts.attach(arena) or nil

  local ticks = 0
  for i = 1, tickCap do
    arena:update(1.0, i * 1.0)
    ticks = i
    if arena.over then break end
  end

  if opts.assertPure then
    assert(#left == n0L and #right == n0R and (left[1] and left[1].hp) == h0,
      "runMatch a mute une compo d'entree (les specs doivent rester en lecture seule)")
  end

  local hl, hr = Match.hpFrac(arena)
  local win, decided
  if arena.over then
    win, decided = arena.win, true
  elseif opts.judge ~= false then
    win, decided = (hl > hr), false
  else
    win, decided = nil, false
  end

  local res = { win = win, decided = decided, ticks = ticks, hpFrac = { left = hl, right = hr } }
  if opts.expose then res.arena = arena; res.log = log end
  return res
end

return Match
