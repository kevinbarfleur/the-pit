-- .luacheckrc — config luacheck (OUTIL DE DEV, pas une dépendance runtime du jeu).
--   Lancer : luacheck src main.lua conf.lua   (ou via tools/check.sh)
-- But principal : interdire les globals accidentels (code 111) = règle anti-spaghetti n°1.

std = "luajit"

-- `love` est fourni par le moteur ; le mock de test (tests/mock_love.lua) le réassigne aussi.
-- En `globals` (settable) car le mock l'écrit ; partout ailleurs il est juste lu.
globals = { "love" }

-- Bruit acceptable dans un projet LÖVE :
ignore = {
  "212", -- argument inutilisé (callbacks : dt, istouch, presses, dx, dy...)
  "213", -- variable de boucle inutilisée
  "542", -- bloc if vide (placeholders d'équilibrage)
}

-- Tout AUTRE global défini accidentellement -> code 111 (la règle anti-spaghetti n°1).
-- L'interdiction de love.graphics dans la couche SIM est gérée par tools/check.sh (grep-guard).
