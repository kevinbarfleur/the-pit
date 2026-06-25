-- tools/scenarios/argn.lua
-- Petit helper : lit le 2e argument CLI (le N/M d'un mode), `luajit tools/sim.lua <mode> <N>`.
-- arg[1] = mode, arg[2] = N. Renvoie une fonction (default) -> N (tonumber(arg[2]) ou default).
-- Centralisé pour que tous les modes parsent le N de façon identique (un seul point de vérité).
return function(default)
  return tonumber(arg and arg[2]) or default
end
