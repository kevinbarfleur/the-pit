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

echo "== garde data pure (whispers declaratif : ni function/RNG/love) =="
# Les MURMURES (src/data/whispers.lua) sont du DATA DÉCLARATIF PUR : toute la logique vit dans les ops
# (src/effects/whispers_ops.lua, sous SIM_DIRS -> couvert par le firewall RNG). Un fichier de tables
# littérales ne peut pas introduire de RNG global ni d'appel au framework. cf. docs/research/murmures-plan.md §6.
if [ -f src/data/whispers.lua ] && \
   grep -nE '\bfunction\b|math\.random|love\.' src/data/whispers.lua 2>/dev/null; then
  echo "FAIL: whispers.lua doit etre DECLARATIF PUR (aucune logique). Mettre l'op dans src/effects."
  exit 1
fi
echo "OK (whispers data pure)"

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

echo "== dot_family (lint famille DoT declarative : couverture + coherence op/famille) =="
luajit tests/dot_family.lua

echo "== i18n (multilangue : interpolation + fallback + couverture anglaise) =="
luajit tests/i18n.lua

echo "== tags (keywords mecaniques : derivation pure + couverture roster) =="
luajit tests/tags.lua

echo "== unit_resolver (source unique niveau/stats/effects) =="
luajit tests/unit_resolver.lua

echo "== effect_audit (facts/tags/contexte/level deltas) =="
luajit tests/effect_audit.lua

echo "== coherence (graphe d'intentions : synergies/positions/economie) =="
luajit tests/coherence.lua

echo "== commanders (tout le roster commande : aura resolue contre le moteur + i18n complete) =="
luajit tests/commanders.lua

echo "== run (economie roguelite : invariants + determinisme) =="
luajit tests/run.lua

echo "== oppgen (adversaire procedural scale : determinisme + validite + scaling + tier) =="
luajit tests/oppgen.lua

echo "== auras (adjacence build-resolue via le graphe du sigil) =="
luajit tests/auras.lua

echo "== duplicatas (3 copies -> niveau : fusion + scaling + cascade) =="
luajit tests/duplicates.lua

echo "== reliques (modele lisible : pool + ops + offre 1-parmi-3 + Grimoire collection) =="
luajit tests/relics.lua

echo "== snapshot (async : round-trip + serve version/tier + cold-start IA) =="
luajit tests/snapshot.lua

echo "== synergies (interactions inter-effets en combat : deroule + resultat) =="
luajit tests/synergies.lua

echo "== murmures (3e couche cachee : resolution + bornes + determinisme + 2-canaux + snapshot) =="
luajit tests/murmures.lua

echo "== chronicle (journal de combat : agregation lignes vivantes + entrees + filtrage) =="
luajit tests/chronicle.lua

echo "== chronicle-ui (panneau + overlay carrousel : draw + navigation headless) =="
luajit tests/chronicle_ui.lua

echo "== arena-anim (B.1b : machine a etats critter en combat — priorite/latch pilotee par le bus) =="
luajit tests/arena_anim.lua

echo "== designsystem-ui (storybook in-engine : scene + sidebar + page scrollable + tokens/atomes) =="
luajit tests/designsystem.lua

echo "== reliquary (bande gravee : bake + memoisation + headless-safe + inset) =="
luajit tests/reliquary.lua

echo "== gauges (atomes de jeu propres : jauges/slots/badges/dividers) =="
luajit tests/gauges.lua

echo "== molecules (cartes relique / bandeaux / tooltip propres) =="
luajit tests/molecules.lua

echo "== payoff (renforcements forts mais bornes : spread + boucliers + caps) =="
luajit tests/payoff.lua

echo "== biome (decors en couches : 4 biomes no-crash + update/draw + fallback + determinisme + wrap) =="
luajit tests/biome.lua

echo "== props (invariants + fuzz) =="
luajit tests/props.lua

echo "== gen (generateur de creatures : determinisme + validation + smoke rendu) =="
luajit tests/gen.lua

echo "== primgen (bestiaire v7 : 41 familles / 93 archetypes non-vides + determinisme) =="
luajit tests/primgen.lua

echo "== forge (refonte : assemblage de parts authored, atlas + recolor + couverture) =="
luajit tests/forge.lua

echo "== relic-icons (icones de reliques : 16x16 + palette + contour + focus + bake) =="
luajit tests/relics_icons.lua

echo "== golden (regression event-log) =="
luajit tests/golden.lua

echo "== lab (banc d'essai : catalogue compos + pont auras + runner partage + cout) =="
luajit tests/lab.lua

echo "== bands (harnais d'equilibrage de masse : bandes + courbe de cout + injection relique/commandant) =="
luajit tests/bands.lua

echo "== scenarios (moteur d'equilibrage : common + 6 modes invest/policy/godroll/commander/counter/economy + determinisme) =="
luajit tests/scenarios.lua

echo "== ui (fondation visuelle : Frame bevel/gilded/etats + Chip + Keywords afflictions + Theme.state) =="
luajit tests/ui.lua

echo "== viewport (responsive : safe-area 16:9 + fond cover) =="
luajit tests/viewport.lua

if command -v luacheck >/dev/null 2>&1; then
  echo "== luacheck =="
  luacheck src main.lua conf.lua --codes
else
  echo "== luacheck absent (optionnel) : 'luarocks install luacheck' pour l'activer =="
fi
