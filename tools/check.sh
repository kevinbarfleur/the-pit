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

echo "== synergies (interactions inter-effets en combat : deroule + resultat) =="
luajit tests/synergies.lua

echo "== props (invariants + fuzz) =="
luajit tests/props.lua

echo "== gen (generateur de creatures : determinisme + validation + smoke rendu) =="
luajit tests/gen.lua

echo "== golden (regression event-log) =="
luajit tests/golden.lua

if command -v luacheck >/dev/null 2>&1; then
  echo "== luacheck =="
  luacheck src main.lua conf.lua --codes
else
  echo "== luacheck absent (optionnel) : 'luarocks install luacheck' pour l'activer =="
fi
