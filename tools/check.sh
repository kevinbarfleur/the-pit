#!/bin/sh
# tools/check.sh — vérification locale rapide (aucune dépendance requise).
#   1) garde déterminisme : aucun RNG global (math.random) dans la couche SIM
#   2) test headless (vraie logique, mock LÖVE)
#   3) luacheck si installé (optionnel ; sinon ignoré)
# Lancer depuis n'importe où : sh tools/check.sh
set -e
cd "$(dirname "$0")/.."

echo "== garde determinisme (RNG global interdit dans la SIM) =="
SIM_DIRS=""
for d in src/combat src/board src/effects src/run; do
  [ -d "$d" ] && SIM_DIRS="$SIM_DIRS $d"
done
if [ -n "$SIM_DIRS" ] && grep -rnE 'math\.random' $SIM_DIRS 2>/dev/null; then
  echo "FAIL: 'math.random' (RNG global) detecte dans la couche SIM. Utiliser self.rng:random()."
  exit 1
fi
echo "OK (RNG seede uniquement)"

echo "== garde firewall SIM/RENDER (love.graphics interdit dans la SIM) =="
# point d'accès membre (love.graphics.xxx) = vrai appel ; un commentaire 'love.graphics' n'a pas le point.
if [ -n "$SIM_DIRS" ] && grep -rnE 'love\.(graphics|window|mouse|keyboard)\.' $SIM_DIRS 2>/dev/null; then
  echo "FAIL: appel love.graphics/window/mouse/keyboard dans la couche SIM. Deplacer vers src/render."
  exit 1
fi
echo "OK (SIM sans rendu)"

echo "== garde dependances (le coeur de combat ne depend pas de la couche render/lab) =="
# src/combat (dont match.lua) doit rester SIM-pur : jamais require une scene, l'UI, le render ou le lab
# (qui construit des Build). Sinon on recree un couplage render -> dette. Le pont vit dans src/lab.
if grep -rnE "require\(['\"]src\.(scenes|lab|ui|render|fx)" src/combat 2>/dev/null; then
  echo "FAIL: src/combat require un module render/lab. Le coeur de combat doit rester SIM-pur."
  exit 1
fi
echo "OK (combat decouple du render/lab)"

echo "== headless (smoke + determinisme + e2e souris) =="
luajit tests/headless.lua

echo "== stats (couche de modificateurs : formule + determinisme + clamp) =="
luajit tests/stats.lua

echo "== i18n (multilangue : interpolation + fallback + couverture anglaise) =="
luajit tests/i18n.lua

echo "== run (economie roguelite : invariants + determinisme) =="
luajit tests/run.lua

echo "== auras (adjacence build-resolue via le graphe du sigil) =="
luajit tests/auras.lua

echo "== duplicatas (3 copies -> niveau : fusion + scaling + cascade) =="
luajit tests/duplicates.lua

echo "== reliques (cryptiques 1-parmi-3 + Grimoire persistant + meta-progression) =="
luajit tests/relics.lua

echo "== snapshot (async : round-trip + serve version/tier + cold-start IA) =="
luajit tests/snapshot.lua

echo "== synergies (interactions inter-effets en combat : deroule + resultat) =="
luajit tests/synergies.lua

echo "== payoff (renforcements forts mais bornes : spread + boucliers + caps) =="
luajit tests/payoff.lua

echo "== props (invariants + fuzz) =="
luajit tests/props.lua

echo "== gen (generateur de creatures : determinisme + validation + smoke rendu) =="
luajit tests/gen.lua

echo "== golden (regression event-log) =="
luajit tests/golden.lua

echo "== lab (banc d'essai : catalogue compos + pont auras + runner partage + cout) =="
luajit tests/lab.lua

if command -v luacheck >/dev/null 2>&1; then
  echo "== luacheck =="
  luacheck src main.lua conf.lua --codes
else
  echo "== luacheck absent (optionnel) : 'luarocks install luacheck' pour l'activer =="
fi
